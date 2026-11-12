#!/usr/bin/env bash
# Prints the initial password of the Argo CD "admin" user (generated at install time, stored only in the cluster).
# Run it yourself in a terminal: the password is never written to Git or to logs.
set -euo pipefail

readonly EXPECTED_CONTEXT="kind-boutique"
context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || { echo "current context is '${context}', expected '${EXPECTED_CONTEXT}'" >&2; exit 1; }

kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
echo
