#!/usr/bin/env bash
# Controlled failure scenarios for the runbook and the demo. Only in the dev namespace.
#
#   scripts/fault.sh list
#   scripts/fault.sh <scenario> inject    # pause Argo CD auto-sync of boutique-dev, then break something
#   scripts/fault.sh restore              # give control back to Git: auto-sync on, Argo CD reverts the drift
#
# Why the pause: boutique-dev has selfHeal, so a change made with kubectl is reverted within seconds and the
# symptom would never be visible. Every fault below changes a resource that Argo CD manages, so "restore"
# (auto-sync on again) is also the fix: the cluster goes back to what Git declares.
set -euo pipefail

readonly EXPECTED_CONTEXT="kind-boutique"
readonly NS="dev"
readonly APP="boutique-dev"
readonly BAD_TAG="v0.0.0-does-not-exist"

usage() {
  cat <<EOF
usage: $0 list | <scenario> inject | restore
scenarios:
  bad-image       frontend image tag that does not exist           -> ImagePullBackOff, rollout stuck
  bad-config      frontend points to a wrong product catalog name  -> pods Ready, pages 500
  no-endpoints    cartservice Service selector matches no pod      -> Service without endpoints, pages 500
  netpol          NetworkPolicy no longer allows frontend -> productcatalogservice -> timeouts, pages 500
EOF
}

die() { printf '[fault] ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[fault] %s\n' "$*"; }

context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || die "current context is '${context}', expected '${EXPECTED_CONTEXT}'"

pause_sync() {
  if [[ -n "$(kubectl get application "${APP}" -n argocd -o jsonpath='{.spec.syncPolicy.automated}')" ]]; then
    kubectl patch application "${APP}" -n argocd --type json -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]' >/dev/null
    log "auto-sync of ${APP} paused (Argo CD will show OutOfSync but will not revert)"
  else
    log "auto-sync of ${APP} already paused"
  fi
}

restore() {
  # Same policy as deploy/argocd/boutique-dev.yaml.
  kubectl patch application "${APP}" -n argocd --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null
  log "auto-sync of ${APP} restored: Argo CD now brings ${NS} back to Git"
  log "follow it with: kubectl get application ${APP} -n argocd -w   then   scripts/smoke-test.sh ${NS}"
}

inject() {
  local scenario="$1"
  case "${scenario}" in
    bad-image)
      pause_sync
      image="$(kubectl get deploy frontend -n "${NS}" -o jsonpath='{.spec.template.spec.containers[?(@.name=="server")].image}')"
      kubectl set image deploy/frontend -n "${NS}" "server=${image%:*}:${BAD_TAG}" >/dev/null
      log "frontend image set to ${image%:*}:${BAD_TAG}" ;;
    bad-config)
      pause_sync
      kubectl set env deploy/frontend -n "${NS}" -c server PRODUCT_CATALOG_SERVICE_ADDR=productcatalog:3550 >/dev/null
      log "frontend PRODUCT_CATALOG_SERVICE_ADDR set to productcatalog:3550 (the Service is productcatalogservice)" ;;
    no-endpoints)
      pause_sync
      kubectl patch service cartservice -n "${NS}" --type merge -p '{"spec":{"selector":{"app":"cart-service"}}}' >/dev/null
      log "cartservice Service selector set to app=cart-service (the pods have app=cartservice)" ;;
    netpol)
      pause_sync
      # ingress[0].from[0] is the frontend pod selector (check it before removing it)
      first="$(kubectl get networkpolicy productcatalogservice -n "${NS}" -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.app}')"
      [[ "${first}" == "frontend" ]] || die "unexpected NetworkPolicy layout (ingress[0].from[0] is '${first}'), not changing it"
      kubectl patch networkpolicy productcatalogservice -n "${NS}" --type json \
        -p '[{"op":"remove","path":"/spec/ingress/0/from/0"}]' >/dev/null
      log "NetworkPolicy productcatalogservice no longer allows ingress from app=frontend" ;;
    *) usage >&2; exit 2 ;;
  esac
  log "injected '${scenario}' in ${NS}. Observe, diagnose, then: $0 restore"
}

case "${1:-}" in
  list) usage ;;
  restore) restore ;;
  "") usage >&2; exit 2 ;;
  *)
    [[ "${2:-}" == "inject" ]] || { usage >&2; exit 2; }
    inject "$1" ;;
esac
