#!/usr/bin/env bash
# Create the local kind cluster used by the challenge. Idempotent: safe to run many times.
# Usage: ./scripts/cluster-up.sh
set -euo pipefail

readonly CLUSTER_NAME="boutique"
readonly CONTEXT="kind-${CLUSTER_NAME}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly KIND_CONFIG="${REPO_ROOT}/kind/cluster.yaml"

log() { printf '[cluster-up] %s\n' "$*"; }
die() { printf '[cluster-up] ERROR: %s\n' "$*" >&2; exit 1; }

for tool in docker kind kubectl; do
  command -v "${tool}" >/dev/null 2>&1 || die "'${tool}' not found in PATH"
done
docker info >/dev/null 2>&1 || die "Docker daemon not reachable"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  log "cluster '${CLUSTER_NAME}' already exists, skipping creation"
else
  log "creating cluster '${CLUSTER_NAME}' from ${KIND_CONFIG}"
  kind create cluster --config "${KIND_CONFIG}" --wait 120s
fi

kubectl config use-context "${CONTEXT}" >/dev/null
log "current context: $(kubectl config current-context)"

log "waiting for node and system pods to be Ready"
kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=180s

kubectl get nodes -o wide
log "done"
