#!/usr/bin/env bash
# Create (or restart) the local kind cluster used by the challenge. Idempotent: safe to run many times.
# Handles three states: cluster missing -> create; node container stopped (e.g. after `wsl --shutdown`) -> start;
# cluster running -> nothing to do. Always re-exports the kubeconfig and waits for readiness.
# Usage: ./scripts/cluster-up.sh
set -euo pipefail

readonly CLUSTER_NAME="boutique"
readonly CONTEXT="kind-${CLUSTER_NAME}"
readonly NODE_CONTAINER="${CLUSTER_NAME}-control-plane"
readonly EXPECTED_KIND_VERSION="v0.33.0"   # the node image digest in kind/cluster.yaml comes from this release
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly KIND_CONFIG="${REPO_ROOT}/kind/cluster.yaml"

log() { printf '[cluster-up] %s\n' "$*"; }
die() { printf '[cluster-up] ERROR: %s\n' "$*" >&2; exit 1; }

for tool in docker kind kubectl; do
  command -v "${tool}" >/dev/null 2>&1 || die "'${tool}' not found in PATH"
done
docker info >/dev/null 2>&1 || die "Docker daemon not reachable"

kind_version="$(kind version)"
if [[ "${kind_version}" != *"${EXPECTED_KIND_VERSION}"* ]]; then
  log "WARNING: expected kind ${EXPECTED_KIND_VERSION}, found: ${kind_version}"
fi

# Capture the list first: piping into `grep -q` under pipefail can fail with SIGPIPE.
clusters="$(kind get clusters 2>/dev/null)"
if grep -qx "${CLUSTER_NAME}" <<<"${clusters}"; then
  running="$(docker inspect -f '{{.State.Running}}' "${NODE_CONTAINER}")"
  if [[ "${running}" == "true" ]]; then
    log "cluster '${CLUSTER_NAME}' already running, skipping creation"
  else
    log "cluster '${CLUSTER_NAME}' exists but node is stopped, starting ${NODE_CONTAINER}"
    docker start "${NODE_CONTAINER}" >/dev/null
  fi
  # Port mappings are fixed at creation: an old cluster without them cannot serve the Ingress.
  if ! docker port "${NODE_CONTAINER}" 80/tcp >/dev/null 2>&1; then
    die "cluster '${CLUSTER_NAME}' was created without the port 80/443 mappings of ${KIND_CONFIG}; recreate it with: kind delete cluster --name ${CLUSTER_NAME} && $0"
  fi
else
  log "creating cluster '${CLUSTER_NAME}' from ${KIND_CONFIG}"
  kind create cluster --config "${KIND_CONFIG}" --wait 120s
fi

# Re-export the kubeconfig: it may be missing or stale after a restart.
kind export kubeconfig --name "${CLUSTER_NAME}" >/dev/null 2>&1
kubectl config use-context "${CONTEXT}" >/dev/null
log "current context: $(kubectl config current-context)"

log "waiting for API server, node and system pods to be Ready"
for _ in $(seq 1 60); do
  kubectl get --raw='/readyz' >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=180s

kubectl get nodes -o wide
log "done"
