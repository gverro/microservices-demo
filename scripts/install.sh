#!/usr/bin/env bash
# One command to get the whole local platform: kind cluster, Traefik, Sealed Secrets, Argo CD, and the
# Argo CD Applications that deploy Online Boutique in dev and prod from Git (GitOps). Idempotent.
# This script installs the PLATFORM; the applications are deployed by Argo CD, never by this script.
# Usage: ./scripts/install.sh            (everything)
#        ./scripts/install.sh dev        (only the dev environment, platform included)
# Env:   GITOPS_REPO=https://github.com/<you>/microservices-demo.git   (fork that Argo CD follows)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly EXPECTED_CONTEXT="kind-boutique"
readonly CLUSTER_NAME="boutique"

# Pinned versions (one place to bump them).
readonly TRAEFIK_CHART_VERSION="42.3.2"          # app v3.7.17
readonly SEALED_SECRETS_CHART_VERSION="2.22.0"   # app v0.41.2
readonly ARGOCD_CHART_VERSION="10.18.0"          # app v3.6.1 (3.6 is the first line tested with Kubernetes 1.37)
readonly FRONTEND_IMAGE="ghcr.io/gverro/microservices-demo/frontend:v0.10.7-kt.1"  # must match frontend.image in deploy/values-common.yaml

# Backup of the Sealed Secrets private key, kept OUTSIDE Git. Restoring it lets a recreated cluster
# decrypt the SealedSecrets committed in deploy/secrets/. Create it with scripts/backup-sealing-key.sh.
readonly SEALING_KEY_BACKUP="${SEALING_KEY_BACKUP:-${HOME}/.config/kiratech-boutique/sealed-secrets-key.yaml}"

# Repository that Argo CD follows. The SealedSecrets it applies must be decryptable by THIS cluster:
# with a fresh clone (no key backup) reseal, commit to your fork and point GITOPS_REPO to it.
readonly DEFAULT_GITOPS_REPO="https://github.com/gverro/microservices-demo.git"
readonly GITOPS_REPO="${GITOPS_REPO:-${DEFAULT_GITOPS_REPO}}"

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
  [[ -f "${REPO_ROOT}/deploy/argocd/boutique-${env}.yaml" ]] || die "unknown environment '${env}' (no deploy/argocd/boutique-${env}.yaml)"
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

# 4. Our frontend image, published by CI to GHCR (public). Pre-loading it into the node avoids a pull during the
#    demo; if GHCR is unreachable (offline), build it from source with the same tag (plan B).
if ! docker image inspect "${FRONTEND_IMAGE}" >/dev/null 2>&1; then
  if ! docker pull "${FRONTEND_IMAGE}"; then
    log "WARNING: cannot pull ${FRONTEND_IMAGE}, building it locally"
    docker build -t "${FRONTEND_IMAGE}" "${REPO_ROOT}/src/frontend"
  fi
fi
kind load docker-image "${FRONTEND_IMAGE}" --name "${CLUSTER_NAME}"

# 5. Argo CD (the GitOps controller).
log "installing Argo CD (chart ${ARGOCD_CHART_VERSION})"
helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version "${ARGOCD_CHART_VERSION}" \
  -n argocd --create-namespace -f "${REPO_ROOT}/deploy/platform/argocd-values.yaml" --wait --timeout 10m >/dev/null

# 6. Environments: namespaces belong to the platform (the AppProject forbids cluster-scoped objects);
#    everything inside them comes from Git through the Applications.
[[ "${GITOPS_REPO}" == "${DEFAULT_GITOPS_REPO}" ]] || log "Argo CD will follow ${GITOPS_REPO}"
apply_from_git_repo() { sed "s|${DEFAULT_GITOPS_REPO}|${GITOPS_REPO}|g" "$1" | kubectl apply -f - >/dev/null; }
apply_from_git_repo "${REPO_ROOT}/deploy/argocd/project.yaml"
for env in "${ENVIRONMENTS[@]}"; do
  kubectl create namespace "${env}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  apply_from_git_repo "${REPO_ROOT}/deploy/argocd/boutique-${env}.yaml"
  app="boutique-${env}"
  # An environment without auto-sync (prod) is synced once when it has never been synced (first install).
  # Later promotions stay a human decision: this script never syncs it again.
  if [[ -z "$(kubectl get application "${app}" -n argocd -o jsonpath='{.spec.syncPolicy.automated}')" \
        && -z "$(kubectl get application "${app}" -n argocd -o jsonpath='{.status.operationState.phase}')" ]]; then
    log "${env}: first install, requesting the initial sync of ${app}"
    kubectl patch application "${app}" -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"install.sh"},"sync":{}}}' >/dev/null
  fi
  if [[ " ${resealed[*]} " == *" ${env} "* ]]; then
    log "WARNING: ${env}: not waiting for ${app}: Git still has a SealedSecret this cluster cannot decrypt (see below)"
    continue
  fi
  # Synced first: an Application with no resources yet already reports Healthy.
  log "${env}: waiting for ${app} to be Synced, then Healthy"
  kubectl wait application "${app}" -n argocd --for=jsonpath='{.status.sync.status}'=Synced --timeout=10m >/dev/null \
    || die "${app} not Synced: kubectl get application ${app} -n argocd -o jsonpath='{.status.conditions}'"
  kubectl wait application "${app}" -n argocd --for=jsonpath='{.status.health.status}'=Healthy --timeout=10m >/dev/null \
    || die "${app} not Healthy: kubectl get application ${app} -n argocd -o jsonpath='{.status.resources}'"
  host="$(kubectl get ingress frontend -n "${env}" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  log "${env}: ${app} Synced/Healthy, http://${host:-<no ingress>}/"
done
log "Argo CD UI: http://argocd.localhost/ (user admin, password: scripts/argocd-password.sh)"

if [[ ${#resealed[@]} -gt 0 ]]; then
  log "WARNING: new Redis passwords were sealed for: ${resealed[*]} (deploy/secrets/ modified locally)."
  log "WARNING: Argo CD applies deploy/secrets/ from ${GITOPS_REPO}: commit and push them there, then run"
  log "WARNING: scripts/backup-sealing-key.sh. Until then the Secret redis-auth cannot be created (cart unavailable)."
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
