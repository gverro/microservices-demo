#!/usr/bin/env bash
# One command to get the whole local platform: kind cluster, Traefik, Sealed Secrets, our frontend image,
# and Online Boutique in the dev and prod namespaces. Idempotent: safe to run many times.
# Usage: ./scripts/install.sh            (everything)
#        ./scripts/install.sh dev        (only the dev environment, platform included)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly EXPECTED_CONTEXT="kind-boutique"
readonly CLUSTER_NAME="boutique"

# Pinned versions (one place to bump them).
readonly TRAEFIK_CHART_VERSION="42.3.2"          # app v3.7.17
readonly SEALED_SECRETS_CHART_VERSION="2.22.0"   # app v0.41.2
readonly FRONTEND_IMAGE="ghcr.io/gverro/microservices-demo/frontend:v0.10.7-kt.1"  # must match frontend.image in deploy/values-common.yaml

# Backup of the Sealed Secrets private key, kept OUTSIDE Git. Restoring it lets a recreated cluster
# decrypt the SealedSecrets committed in deploy/secrets/. Create it with scripts/backup-sealing-key.sh.
readonly SEALING_KEY_BACKUP="${SEALING_KEY_BACKUP:-${HOME}/.config/kiratech-boutique/sealed-secrets-key.yaml}"

ENVIRONMENTS=(dev prod)
if [[ $# -gt 0 ]]; then
  ENVIRONMENTS=("$@")
fi

log() { printf '[install] %s\n' "$*"; }
die() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

for tool in docker kind kubectl helm kubeseal openssl; do
  command -v "${tool}" >/dev/null 2>&1 || die "'${tool}' not found in PATH"
done
for env in "${ENVIRONMENTS[@]}"; do
  [[ -f "${REPO_ROOT}/deploy/values-${env}.yaml" ]] || die "unknown environment '${env}' (no deploy/values-${env}.yaml)"
done
grep -q "image: ${FRONTEND_IMAGE}" "${REPO_ROOT}/deploy/values-common.yaml" \
  || die "FRONTEND_IMAGE (${FRONTEND_IMAGE}) differs from frontend.image in deploy/values-common.yaml"

# 1. Cluster (creates, restarts or leaves it as is).
"${REPO_ROOT}/scripts/cluster-up.sh"
context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || die "current context is '${context}', expected '${EXPECTED_CONTEXT}'"

# 2. Ingress controller.
log "installing Traefik ${TRAEFIK_CHART_VERSION}"
helm upgrade --install traefik traefik --repo https://traefik.github.io/charts --version "${TRAEFIK_CHART_VERSION}" \
  -n traefik --create-namespace -f "${REPO_ROOT}/deploy/platform/traefik-values.yaml" --wait --timeout 5m >/dev/null

# 3. Sealed Secrets: restore the private key first (if we have a backup and the cluster has none).
active_keys="$(kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o name)"
if [[ -z "${active_keys}" && -f "${SEALING_KEY_BACKUP}" ]]; then
  log "restoring the Sealed Secrets key from ${SEALING_KEY_BACKUP}"
  kubectl apply -f "${SEALING_KEY_BACKUP}" >/dev/null
fi
log "installing Sealed Secrets ${SEALED_SECRETS_CHART_VERSION}"
helm upgrade --install sealed-secrets sealed-secrets --repo https://bitnami.github.io/sealed-secrets \
  --version "${SEALED_SECRETS_CHART_VERSION}" -n kube-system --set-string fullnameOverride=sealed-secrets-controller \
  --set-string keyrenewperiod=0 \
  --wait --timeout 5m >/dev/null

# Make sure the controller answers before asking it anything (otherwise a network error would look like a bad key).
kubeseal_args=(--controller-name sealed-secrets-controller --controller-namespace kube-system)
for _ in $(seq 1 30); do
  kubeseal "${kubeseal_args[@]}" --fetch-cert >/dev/null 2>&1 && break
  sleep 2
done
kubeseal "${kubeseal_args[@]}" --fetch-cert >/dev/null || die "Sealed Secrets controller not reachable by kubeseal"

# Per environment: can THIS cluster decrypt the SealedSecret committed in Git? If not (new clone without our key
# backup, or a key that changed), seal a NEW random password for this cluster. Git then differs from the committed
# files: commit them (your fork) if Git must drive the cluster (GitOps), and back up the key. See docs/SECURITY.md.
resealed=()
for env in "${ENVIRONMENTS[@]}"; do
  sealed_file="${REPO_ROOT}/deploy/secrets/${env}/redis-auth.sealed.yaml"
  if [[ -s "${sealed_file}" ]] && kubeseal "${kubeseal_args[@]}" --validate <"${sealed_file}" >/dev/null 2>&1; then
    log "${env}: committed SealedSecret decrypts with this cluster's key"
  else
    log "WARNING: ${env}: committed SealedSecret cannot be decrypted here, sealing a NEW password for this cluster"
    "${REPO_ROOT}/scripts/seal-secrets.sh" "${env}"
    resealed+=("${env}")
  fi
done

# 4. Our frontend image. CI publishes it to GHCR; the node can pull it. Building and loading it here keeps
#    the install working offline (demo plan B) and before CI has published a new tag.
# The tag identifies the code: after changing src/frontend, bump the tag here and in deploy/values-common.yaml.
if ! docker image inspect "${FRONTEND_IMAGE}" >/dev/null 2>&1; then
  log "building ${FRONTEND_IMAGE}"
  docker build -t "${FRONTEND_IMAGE}" "${REPO_ROOT}/src/frontend"
fi
kind load docker-image "${FRONTEND_IMAGE}" --name "${CLUSTER_NAME}"

# 5. Environments.
for env in "${ENVIRONMENTS[@]}"; do
  log "== environment ${env}"
  kubectl create namespace "${env}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl apply -f "${REPO_ROOT}/deploy/secrets/${env}/"
  log "waiting for the controller to decrypt the Secret redis-auth"
  for _ in $(seq 1 30); do
    kubectl get secret redis-auth -n "${env}" >/dev/null 2>&1 && break
    sleep 2
  done
  kubectl get secret redis-auth -n "${env}" >/dev/null 2>&1 \
    || die "Secret redis-auth not created in '${env}': check 'kubectl describe sealedsecret redis-auth -n ${env}' (wrong sealing key?)"
  helm upgrade --install onlineboutique "${REPO_ROOT}/helm-chart" -n "${env}" \
    -f "${REPO_ROOT}/deploy/values-common.yaml" -f "${REPO_ROOT}/deploy/values-${env}.yaml" \
    --wait --timeout 10m >/dev/null
  host="$(kubectl get ingress frontend -n "${env}" -o jsonpath='{.spec.rules[0].host}')"
  log "${env} ready: http://${host}/"
done

if [[ ${#resealed[@]} -gt 0 ]]; then
  log "WARNING: new Redis passwords were sealed for: ${resealed[*]} (deploy/secrets/ modified locally)."
  log "WARNING: run scripts/backup-sealing-key.sh, and commit deploy/secrets/ if this cluster is driven from your Git."
fi

# Pods may be briefly Pending while a rollout settles: retry for up to ~30s before warning.
for _ in $(seq 1 10); do
  not_running="$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null)"
  [[ -z "${not_running}" ]] && break
  sleep 3
done
if [[ -n "${not_running}" ]]; then
  printf '%s\n' "${not_running}"
  log "WARNING: some pods are not Running (see above)"
else
  log "all pods Running"
fi
log "done"
