#!/usr/bin/env bash
# Smoke test of one Online Boutique environment: is anything big broken?
# Checks, from the bottom up, so the first FAIL tells where to look:
#   1. Argo CD   - the Application is Healthy (Synced is reported, not required: prod waits for promotion)
#   2. Workloads - every Deployment has all its replicas ready
#   3. Services  - every Service has at least one ready endpoint (otherwise traffic reaches nobody)
#   4. HTTP      - the main pages answer 200 through the Ingress
# Read-only: it never changes the cluster.
# Usage: scripts/smoke-test.sh [dev|prod]   (default: dev). Exit code 0 = all PASS, 1 = at least one FAIL.
set -euo pipefail

readonly EXPECTED_CONTEXT="kind-boutique"
readonly PRODUCT_ID="OLJCESPC7Z"   # a product of the upstream catalog (sunglasses)
env="${1:-dev}"
[[ "${env}" == "dev" || "${env}" == "prod" ]] || { echo "usage: $0 [dev|prod]" >&2; exit 2; }

for tool in kubectl curl; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "'${tool}' not found in PATH" >&2; exit 2; }
done
context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || { echo "current context is '${context}', expected '${EXPECTED_CONTEXT}'" >&2; exit 2; }

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

echo "== smoke test: ${env} ($(date -u +%Y-%m-%dT%H:%M:%SZ))"

# 1. Argo CD
app="boutique-${env}"
read -r sync health < <(kubectl get application "${app}" -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}' 2>/dev/null || echo "Missing Missing")
if [[ "${health}" == "Healthy" ]]; then pass "argocd   ${app} health=${health}"; else fail "argocd   ${app} health=${health}"; fi
if [[ "${sync}" == "Synced" ]]; then pass "argocd   ${app} sync=${sync}"; else warn "argocd   ${app} sync=${sync} (cluster differs from Git: pending promotion, paused sync or drift)"; fi

# 2. Workloads: desired replicas = ready replicas, and the rollout is complete
#    (during a stuck rolling update the old pods are still ready, so "ready" alone would hide it:
#    the total number of pods, old plus new, stays above the desired replicas until the rollout ends)
while read -r name desired ready total; do
  [[ -n "${name}" ]] || continue
  ready="${ready:-0}"; total="${total:-0}"
  if [[ "${desired}" != "${ready}" ]]; then
    fail "deploy   ${name} ${ready}/${desired} ready (kubectl get pods -n ${env} -l app=${name}; kubectl describe pod ...)"
  elif [[ "${desired}" != "${total}" ]]; then
    fail "deploy   ${name} rollout not complete: ${total} pods for ${desired} replicas (kubectl rollout status deploy/${name} -n ${env})"
  else
    pass "deploy   ${name} ${ready}/${desired} ready"
  fi
done < <(kubectl get deploy -n "${env}" -o jsonpath='{range .items[*]}{.metadata.name} {.spec.replicas} {.status.readyReplicas} {.status.replicas}{"\n"}{end}')

# 3. Services: at least one ready endpoint each
for svc in $(kubectl get svc -n "${env}" -o jsonpath='{.items[*].metadata.name}'); do
  count="$(kubectl get endpointslices -n "${env}" -l "kubernetes.io/service-name=${svc}" \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' 2>/dev/null | grep -c . || true)"
  if [[ "${count}" -gt 0 ]]; then pass "service  ${svc} ${count} ready endpoint(s)"
  else fail "service  ${svc} has no ready endpoints (selector or readiness: kubectl get endpointslices -n ${env} -l kubernetes.io/service-name=${svc})"; fi
done

# 4. HTTP through the Ingress (the host comes from the Ingress itself)
host="$(kubectl get ingress frontend -n "${env}" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
if [[ -z "${host}" ]]; then
  fail "http     no Ingress 'frontend' in ${env}"
else
  for path in "/" "/product/${PRODUCT_ID}" "/cart"; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://${host}${path}" || true)"
    if [[ "${code}" == "200" ]]; then pass "http     GET http://${host}${path} -> ${code}"
    else fail "http     GET http://${host}${path} -> ${code:-no answer} (kubectl logs -n ${env} deploy/frontend --tail=20)"; fi
  done
fi

if [[ "${failures}" -eq 0 ]]; then
  echo "== RESULT: OK (${env})"
else
  echo "== RESULT: ${failures} FAIL (${env})"
  exit 1
fi
