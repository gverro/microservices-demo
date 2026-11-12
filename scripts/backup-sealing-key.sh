#!/usr/bin/env bash
# Save the Sealed Secrets private key OUTSIDE Git, readable only by the current user (mode 600).
# Why: the SealedSecrets committed in deploy/secrets/ can only be decrypted with this key; install.sh restores
# it when the cluster is recreated. Whoever holds this file can decrypt every SealedSecret: treat it like a password.
# Run it by hand, once after the first install (and after any key rotation).
# Usage: ./scripts/backup-sealing-key.sh
set -euo pipefail

readonly EXPECTED_CONTEXT="kind-boutique"
readonly SEALING_KEY_BACKUP="${SEALING_KEY_BACKUP:-${HOME}/.config/kiratech-boutique/sealed-secrets-key.yaml}"

context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || { echo "current context is '${context}', expected '${EXPECTED_CONTEXT}'" >&2; exit 1; }

umask 077
mkdir -p "$(dirname "${SEALING_KEY_BACKUP}")"
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "${SEALING_KEY_BACKUP}"
echo "saved $(grep -c 'tls.key' "${SEALING_KEY_BACKUP}") key(s) to ${SEALING_KEY_BACKUP} ($(stat -c '%a' "${SEALING_KEY_BACKUP}"))"
