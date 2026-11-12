#!/usr/bin/env bash
# Generate a new random Redis password for each given environment and seal it with the cluster's public key.
# The plaintext only flows through a pipe: it is never printed nor written to disk.
# Used for: password rotation, or a fresh cluster whose sealing key differs from the one used for the files in Git.
# After running it, commit deploy/secrets/ (GitOps) and restart redis-cart and cartservice if they were running.
# Usage: ./scripts/seal-secrets.sh dev prod
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly EXPECTED_CONTEXT="kind-boutique"

[[ $# -gt 0 ]] || { echo "usage: $0 <env>..." >&2; exit 1; }
for tool in kubectl kubeseal openssl; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "'${tool}' not found in PATH" >&2; exit 1; }
done
context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || { echo "current context is '${context}', expected '${EXPECTED_CONTEXT}'" >&2; exit 1; }

for env in "$@"; do
  out_dir="${REPO_ROOT}/deploy/secrets/${env}"
  mkdir -p "${out_dir}"
  # Seal into a variable first: if kubeseal fails, pipefail stops the script and the tracked file is left untouched.
  sealed="$(openssl rand -hex 24 | tr -d '\n' \
    | kubectl create secret generic redis-auth -n "${env}" --from-file=password=/dev/stdin --dry-run=client -o yaml \
    | kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system --format yaml)"
  [[ -n "${sealed}" ]] || { echo "kubeseal returned nothing for '${env}'" >&2; exit 1; }
  printf '%s\n' "${sealed}" > "${out_dir}/redis-auth.sealed.yaml"
  echo "sealed a new redis-auth password for '${env}' -> deploy/secrets/${env}/redis-auth.sealed.yaml"
done
