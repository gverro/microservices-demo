#!/usr/bin/env bash
# Save the Sealed Secrets private key(s) OUTSIDE Git, readable only by the current user (mode 600).
# Why: the SealedSecrets committed in deploy/secrets/ can only be decrypted with this key; install.sh restores
# it when the cluster is recreated. Whoever holds this file can decrypt every SealedSecret: treat it like a password.
# Key renewal is disabled in install.sh (keyrenewperiod=0), so one backup stays valid; run it again after a
# manual key rotation or after install.sh reports that it sealed new passwords.
# Usage: ./scripts/backup-sealing-key.sh
set -euo pipefail

readonly EXPECTED_CONTEXT="kind-boutique"
readonly SEALING_KEY_BACKUP="${SEALING_KEY_BACKUP:-${HOME}/.config/kiratech-boutique/sealed-secrets-key.yaml}"

context="$(kubectl config current-context)"
[[ "${context}" == "${EXPECTED_CONTEXT}" ]] || { echo "current context is '${context}', expected '${EXPECTED_CONTEXT}'" >&2; exit 1; }

keys="$(kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml)"
count="$(grep -c 'tls.key' <<<"${keys}" || true)"
[[ "${count}" -gt 0 ]] || { echo "no Sealed Secrets key found in kube-system: nothing saved" >&2; exit 1; }

umask 077
mkdir -p "$(dirname "${SEALING_KEY_BACKUP}")"
printf '%s\n' "${keys}" > "${SEALING_KEY_BACKUP}"
chmod 600 "${SEALING_KEY_BACKUP}"   # umask does not change an already existing file
echo "saved ${count} key(s) to ${SEALING_KEY_BACKUP} ($(stat -c '%a' "${SEALING_KEY_BACKUP}"))"
