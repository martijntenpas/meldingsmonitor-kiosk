#!/usr/bin/env bash
# Schakelt keyring-popups uit voor de kiosk-gebruiker.

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
EOF

chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config"

log "Keyring-popups uitgeschakeld voor ${TARGET_USER}."
