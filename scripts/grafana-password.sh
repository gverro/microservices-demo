#!/usr/bin/env bash
# Prints the password of the Grafana "admin" user (generated at install time, stored only in the cluster).
# Run it yourself in a terminal: the password is never written to Git or to logs.
set -euo pipefail

readonly EXPECTED_CONTEXT="kind-boutique"
context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || { echo "current context is '${context}', expected '${EXPECTED_CONTEXT}'" >&2; exit 1; }

kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d
echo
