#!/usr/bin/env bash
# Optional Krateo PoC (phase 6, R-20, docs/KRATEO.md): installs only the Krateo engine (core-provider), not the portal,
# and registers the golden path deploy/krateo/boutique-service as the self-service API "BoutiqueService".
# Not part of install.sh: the base platform stays light (options off by default, D-17).
# Prerequisites: scripts/install.sh already run (Argo CD); chart published and public on GHCR (CI job publish-chart).
# On a fork the repository and registry are this one's (schema enum, AppProject tenants, CompositionDefinition):
# see docs/KRATEO.md §8 "Su un clone o un fork".
# Idempotent: re-running it upgrades or re-applies the same objects (also after a reboot).
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
crd_version="v${chart_version//./-}"            # Krateo names the CRD version after the chart version: 0.1.1 -> v0-1-1
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

# A pod can be Running and still crash a minute later: compare the restarts before and after a 30 s window
# (counts are cumulative, so after a reboot they are above 0 even when the pods are healthy).
echo "4/5 Krateo pods are stable (no new restarts in 30 s)"
count_restarts() {
  kubectl get pods -n krateo-system -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.restartCount}{"\n"}{end}{end}' \
    | awk '{s += $1} END {print s + 0}'
}
before="$(count_restarts)"
sleep 30
after="$(count_restarts)"
(( after == before )) || { echo "Krateo pods restarted during the check (${before} -> ${after}): kubectl logs -n krateo-system deploy/krateo-core-provider --previous" >&2; exit 1; }

echo "5/5 CompositionDefinition boutique-service (downloads the chart, generates the CRD, starts its controller; ~3 min)"
kubectl apply -f "${REPO_ROOT}/deploy/krateo/compositiondefinition.yaml" >/dev/null
# After a version change Ready is still True from the previous version until Krateo starts the new version's controller
# (seen on the 0.1.0 -> 0.1.1 upgrade: CRD version added, then Ready=False, then the controller, then Ready=True).
# So wait for the new CRD version, then for that version's controller, and only then for Ready.
deadline=$(( SECONDS + 600 ))
until kubectl get crd boutiqueservices.composition.krateo.io -o jsonpath='{.spec.versions[*].name}' 2>/dev/null | tr ' ' '\n' | grep -qx "${crd_version}"; do
  (( SECONDS < deadline )) || { echo "CRD version ${crd_version} not generated after 10 min: kubectl describe compositiondefinition boutique-service -n ${CATALOG_NAMESPACE}" >&2; exit 1; }
  sleep 5
done
controller="boutiqueservices-${crd_version}-controller"
until kubectl get deployment "${controller}" -n "${CATALOG_NAMESPACE}" >/dev/null 2>&1; do
  (( SECONDS < deadline )) || { echo "controller ${controller} not created after 10 min: kubectl describe compositiondefinition boutique-service -n ${CATALOG_NAMESPACE}" >&2; exit 1; }
  sleep 5
done
kubectl rollout status deployment "${controller}" -n "${CATALOG_NAMESPACE}" --timeout 10m >/dev/null
kubectl wait compositiondefinition boutique-service -n "${CATALOG_NAMESPACE}" --for condition=Ready=True --timeout 10m >/dev/null

# The example request uses the SealedSecret in deploy/secrets/team-a: it only works with this cluster's sealing key.
if command -v kubeseal >/dev/null 2>&1 \
  && ! kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system --validate \
       < "${REPO_ROOT}/deploy/secrets/team-a/redis-auth.sealed.yaml" >/dev/null 2>&1; then
  echo "WARNING: deploy/secrets/team-a cannot be decrypted by this cluster: the team-a cart will not work until you run" >&2
  echo "  scripts/seal-secrets.sh team-a   and commit the file to the repository Argo CD reads (docs/KRATEO.md §8)" >&2
fi

kubectl get compositiondefinition -n "${CATALOG_NAMESPACE}"
echo
echo "Ready. A team requests an environment with:"
echo "  kubectl apply -f deploy/krateo/examples/team-a.yaml   (apiVersion composition.krateo.io/${crd_version})"
