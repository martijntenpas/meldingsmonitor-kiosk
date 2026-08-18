#!/usr/bin/env bash
# Zorgt dat lightdm openbox start voor de bestaande desktop-gebruiker (bijv. martijn).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

TARGET_DIR="${SCRIPT_DIR}/.."
DESKTOP_USER="$(detect_desktop_user || true)"

if [[ -z "${DESKTOP_USER}" ]]; then
    DESKTOP_USER="${MM_KIOSK_USER:-kiosk}"
    useradd -m -s /bin/bash "${DESKTOP_USER}" 2>/dev/null || true
fi

log "Desktop-gebruiker voor kiosk: ${DESKTOP_USER}"

usermod -aG video,render,input,tty "${DESKTOP_USER}" 2>/dev/null || true

mkdir -p /etc/lightdm/lightdm.conf.d

for conf in /etc/lightdm/lightdm.conf.d/*.conf; do
    [[ -f "${conf}" ]] || continue
    [[ "${conf}" == */zz-mm-kiosk.conf ]] && continue
    [[ "${conf}" == *.disabled-by-mm-kiosk ]] && continue

    log "Lightdm-config uitgeschakeld: ${conf}"
    mv "${conf}" "${conf}.disabled-by-mm-kiosk"
done

if [[ -f /etc/lightdm/lightdm.conf ]]; then
    if grep -qE 'autologin-user=|autologin-session=|^user-session=' /etc/lightdm/lightdm.conf 2>/dev/null; then
        cp /etc/lightdm/lightdm.conf "/etc/lightdm/lightdm.conf.backup-by-mm-kiosk.$(date +%s)"
        sed -i '/^autologin-user=/d; /^autologin-session=/d; /^user-session=/d' /etc/lightdm/lightdm.conf
        log "Autologin-regels verwijderd uit /etc/lightdm/lightdm.conf."
    fi
fi

cat > /etc/lightdm/lightdm.conf.d/zz-mm-kiosk.conf <<EOF
[Seat:*]
autologin-user=${DESKTOP_USER}
autologin-session=openbox
user-session=openbox
autologin-user-timeout=0
greeter-hide-users=true

[Seat:seat0]
autologin-user=${DESKTOP_USER}
autologin-session=openbox
user-session=openbox
autologin-user-timeout=0
EOF

USER_ACCOUNTS_FILE="/var/lib/AccountsService/users/${DESKTOP_USER}"
mkdir -p /var/lib/AccountsService/users
if [[ -f "${USER_ACCOUNTS_FILE}" ]]; then
    if grep -q '^\[User\]' "${USER_ACCOUNTS_FILE}"; then
        sed -i '/^XSession=/d' "${USER_ACCOUNTS_FILE}" || true
        sed -i "/^\[User\]/a XSession=openbox" "${USER_ACCOUNTS_FILE}"
    else
        printf '[User]\nXSession=openbox\n' >> "${USER_ACCOUNTS_FILE}"
    fi
else
    cat > "${USER_ACCOUNTS_FILE}" <<EOF
[User]
XSession=openbox
SystemAccount=false
EOF
fi

MM_KIOSK_USER="${DESKTOP_USER}" "${SCRIPT_DIR}/mm-kiosk-configure-openbox-autostart.sh"
"${SCRIPT_DIR}/mm-kiosk-install-desktop-autostart.sh" "${DESKTOP_USER}"
update_mm_kiosk_user "${DESKTOP_USER}" "${TARGET_DIR}"

echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
systemctl enable lightdm.service

log "lightdm herstarten: ${DESKTOP_USER} met openbox-sessie."
systemctl restart lightdm.service

sleep 4

if sudo -u "${DESKTOP_USER}" DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
    log "Openbox/X11 actief voor ${DESKTOP_USER}."
    systemctl restart mm-kiosk.service 2>/dev/null || true
    exit 0
fi

log "Openbox nog niet actief; desktop-autostart voor ${DESKTOP_USER} staat klaar als fallback."
exit 0
