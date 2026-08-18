#!/usr/bin/env bash
# Zorgt dat lightdm automatisch inlogt als kiosk-gebruiker met openbox.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

KIOSK_USER="${MM_KIOSK_USER:-kiosk}"

if ! id "${KIOSK_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${KIOSK_USER}"
    log "Gebruiker ${KIOSK_USER} aangemaakt."
fi

usermod -aG video,render,input,tty "${KIOSK_USER}" 2>/dev/null || true

mkdir -p /etc/lightdm/lightdm.conf.d

for conf in /etc/lightdm/lightdm.conf.d/*.conf; do
    [[ -f "${conf}" ]] || continue
    [[ "${conf}" == */99-mm-kiosk.conf ]] && continue
    [[ "${conf}" == *.disabled-by-mm-kiosk ]] && continue

    log "Lightdm-config uitgeschakeld: ${conf}"
    mv "${conf}" "${conf}.disabled-by-mm-kiosk"
done

if [[ -f /etc/lightdm/lightdm.conf ]]; then
    if grep -qE '^autologin-user=|^autologin-session=' /etc/lightdm/lightdm.conf 2>/dev/null; then
        cp /etc/lightdm/lightdm.conf "/etc/lightdm/lightdm.conf.backup-by-mm-kiosk.$(date +%s)"
        sed -i '/^autologin-user=/d; /^autologin-session=/d; /^user-session=/d' /etc/lightdm/lightdm.conf
        log "Autologin-regels verwijderd uit /etc/lightdm/lightdm.conf."
    fi
fi

cat > /etc/lightdm/lightdm.conf.d/99-mm-kiosk.conf <<EOF
[Seat:*]
autologin-user=${KIOSK_USER}
autologin-session=openbox
user-session=openbox
autologin-user-timeout=0
greeter-hide-users=true
EOF

if [[ -f "/var/lib/AccountsService/users/${KIOSK_USER}" ]]; then
    sed -i '/^XSession=/d' "/var/lib/AccountsService/users/${KIOSK_USER}" || true
fi

for user_conf in /var/lib/AccountsService/users/*; do
    [[ -f "${user_conf}" ]] || continue
    username="$(basename "${user_conf}")"
    [[ "${username}" == "${KIOSK_USER}" ]] && continue

    if grep -q '^XSession=' "${user_conf}" 2>/dev/null; then
        sed -i '/^XSession=/d' "${user_conf}" || true
        log "XSession verwijderd voor ${username} in AccountsService."
    fi
done

"${SCRIPT_DIR}/mm-kiosk-configure-openbox-autostart.sh"

echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
systemctl enable lightdm.service

log "lightdm herstarten met autologin voor ${KIOSK_USER}."
systemctl restart lightdm.service

sleep 3

if sudo -u "${KIOSK_USER}" DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
    log "Autologin OK: X11 beschikbaar voor ${KIOSK_USER}."
    exit 0
fi

log "Autologin voor ${KIOSK_USER} nog niet actief; fallback voor bestaande desktop-sessie."
ACTIVE_USER="$(who | awk 'NR==1 {print $1}')"
if [[ -n "${ACTIVE_USER}" && "${ACTIVE_USER}" != "${KIOSK_USER}" ]]; then
    "${SCRIPT_DIR}/mm-kiosk-install-desktop-autostart.sh" "${ACTIVE_USER}"
    log "Browser-autostart geinstalleerd voor ${ACTIVE_USER}."
fi

exit 0
