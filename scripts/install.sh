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
readonly FRONTEND_IMAGE="frontend:v0.10.7-kt.1"  # must match frontend.image in deploy/values-common.yaml

# Backup of the Sealed Secrets private key, kept OUTSIDE Git. Restoring it lets a recreated cluster
# decrypt the SealedSecrets committed in deploy/secrets/. Create it with scripts/backup-sealing-key.sh.
readonly SEALING_KEY_BACKUP="${SEALING_KEY_BACKUP:-${HOME}/.config/kiratech-boutique/sealed-secrets-key.yaml}"

ENVIRONMENTS=(dev prod)
if [[ $# -gt 0 ]]; then
  ENVIRONMENTS=("$@")
fi

log() { printf '[install] %s\n' "$*"; }
die() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

for tool in docker kind kubectl helm; do
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
  --wait --timeout 5m >/dev/null
if [[ -z "${active_keys}" && ! -f "${SEALING_KEY_BACKUP}" ]]; then
  # Fresh cluster and no backup (e.g. a new clone): the files in Git were sealed with a key we do not have.
  log "WARNING: no sealing key backup: generating NEW Redis passwords sealed for this cluster."
  log "WARNING: deploy/secrets/ is now modified locally; commit it if Git must match the cluster (GitOps),"
  log "WARNING: and run scripts/backup-sealing-key.sh to keep the new key. See docs/SECURITY.md."
  "${REPO_ROOT}/scripts/seal-secrets.sh" "${ENVIRONMENTS[@]}"
fi

# 4. Our frontend image: build only if missing, then load it into the kind node (kind skips it if already there).
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

not_running="$(kubectl get pods -A --field-selector=status.phase!=Running --no-headers 2>/dev/null)"
if [[ -n "${not_running}" ]]; then
  printf '%s\n' "${not_running}"
  log "WARNING: some pods are not Running (see above)"
else
  log "all pods Running"
fi
log "done"
