#!/usr/bin/env bash
# Optional Krateo PoC (phase 6, R-20, docs/KRATEO.md): installs only the Krateo engine (core-provider), not the portal,
# and registers the golden path deploy/krateo/boutique-service as the self-service API "BoutiqueService".
# Not part of install.sh: the base platform stays light (options off by default, D-17).
# Prerequisites: scripts/install.sh already run (Argo CD); chart published and public on GHCR (CI job publish-chart).
# Idempotent: re-running it upgrades or re-applies the same objects.
# Usage: ./scripts/krateo-poc.sh
# Then a team requests an environment with: kubectl apply -f deploy/krateo/examples/team-a.yaml
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly EXPECTED_CONTEXT="kind-boutique"
readonly CORE_PROVIDER_VERSION="1.0.0"          # latest stable chart on https://charts.krateo.io (18/11/2026)
readonly CATALOG_NAMESPACE="boutique-catalog"     # where the CompositionDefinition and the teams' Compositions live

for tool in kubectl helm; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "'${tool}' not found in PATH" >&2; exit 1; }
done
context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || { echo "current context is '${context}', expected '${EXPECTED_CONTEXT}'" >&2; exit 1; }
kubectl get namespace argocd >/dev/null 2>&1 || { echo "Argo CD not found: run scripts/install.sh first" >&2; exit 1; }

# kind nodes share the host kernel: with the Ubuntu/WSL default of 128 inotify instances the core-provider
# crashes with "too many open files" (https://kind.sigs.k8s.io/docs/user/known-issues/, README prerequisites).
inotify_instances="$(cat /proc/sys/fs/inotify/max_user_instances)"
if (( inotify_instances < 512 )); then
  echo "fs.inotify.max_user_instances is ${inotify_instances}, Krateo needs 512. Run once:" >&2
  echo "  sudo sysctl fs.inotify.max_user_instances=512" >&2
  echo "  echo 'fs.inotify.max_user_instances = 512' | sudo tee /etc/sysctl.d/99-kind-inotify.conf" >&2
  exit 1
fi

# The chart must be pullable without credentials: Krateo downloads it like any public chart.
chart_url="$(sed -n 's/^ *url: *//p' "${REPO_ROOT}/deploy/krateo/compositiondefinition.yaml")"
chart_version="$(sed -n 's/^ *version: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${REPO_ROOT}/deploy/krateo/compositiondefinition.yaml")"
if ! helm show chart "${chart_url}" --version "${chart_version}" >/dev/null 2>&1; then
  echo "cannot pull ${chart_url}:${chart_version} anonymously: is it published (CI publish-chart) and public on GHCR?" >&2
  exit 1
fi

# Before any Krateo pod exists: the namespaces and the DNS policy (ndots:1, see deploy/krateo/dns-ndots-policy.yaml),
# so that every Krateo pod, including the controllers created later, can resolve ghcr.io.
echo "1/5 namespaces krateo-system and ${CATALOG_NAMESPACE}, DNS policy ndots:1"
kubectl apply -f "${REPO_ROOT}/deploy/krateo/dns-ndots-policy.yaml" >/dev/null
for ns in krateo-system "${CATALOG_NAMESPACE}"; do
  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl label namespace "${ns}" boutique.kiratech.local/dns-ndots-1=true --overwrite >/dev/null
done

echo "2/5 Krateo core-provider ${CORE_PROVIDER_VERSION} (namespace krateo-system)"
helm upgrade --install krateo-core-provider core-provider --repo https://charts.krateo.io \
  --version "${CORE_PROVIDER_VERSION}" -n krateo-system --wait --timeout 5m >/dev/null

echo "3/5 AppProject tenants (Argo CD may only deploy into team-* namespaces)"
kubectl apply -f "${REPO_ROOT}/deploy/krateo/appproject-tenants.yaml" >/dev/null

echo "4/5 Krateo pods are stable (no restarts)"
sleep 30
restarts="$(kubectl get pods -n krateo-system -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | sort -n | tail -1)"
(( restarts == 0 )) || { echo "a Krateo pod restarted ${restarts} times: kubectl logs -n krateo-system deploy/krateo-core-provider --previous" >&2; exit 1; }

echo "5/5 CompositionDefinition boutique-service (downloads the chart, generates the CRD, starts its controller; ~3 min)"
kubectl apply -f "${REPO_ROOT}/deploy/krateo/compositiondefinition.yaml" >/dev/null
kubectl wait compositiondefinition boutique-service -n "${CATALOG_NAMESPACE}" --for condition=Ready=True --timeout 10m >/dev/null

kubectl get compositiondefinition -n "${CATALOG_NAMESPACE}"
echo
echo "Ready. A team requests an environment with:"
echo "  kubectl apply -f deploy/krateo/examples/team-a.yaml"
