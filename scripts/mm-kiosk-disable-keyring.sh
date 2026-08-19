#!/usr/bin/env bash
# Schakelt keyring-popups uit en configureert Chromium voor kiosk-gebruik.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

TARGET_USER="${1:-$(detect_primary_user || true)}"

if [[ -z "${TARGET_USER}" ]] || ! id "${TARGET_USER}" >/dev/null 2>&1; then
    exit 0
fi

USER_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
AUTOSTART="${USER_HOME}/.config/autostart"

mkdir -p "${AUTOSTART}"

for keyring_app in gnome-keyring-pkcs11 gnome-keyring-secrets gnome-keyring-ssh; do
    cat > "${AUTOSTART}/${keyring_app}.desktop" <<EOF
[Desktop Entry]
Hidden=true
EOF
done

cat > "${USER_HOME}/.config/chromium-flags.conf" <<'EOF'
--password-store=basic
--use-mock-keychain
--disable-translate
--disable-features=Translate,TranslateUI,TranslateNewUI,TranslateBubble
--lang=nl
--accept-lang=nl-NL,nl,en-US,en
EOF

for policy_dir in \
    /etc/chromium/policies/managed \
    /etc/chromium-browser/policies/managed; do
    mkdir -p "${policy_dir}"
    cat > "${policy_dir}/meldingsmonitor-kiosk.json" <<'EOF'
{
    "TranslateEnabled": false,
    "DefaultNotificationsSetting": 2,
    "BrowserSignin": 0,
    "AutofillAddressEnabled": false,
    "AutofillCreditCardEnabled": false
}
EOF
done

chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config"

log "Chromium kiosk-configuratie toegepast voor ${TARGET_USER}."
