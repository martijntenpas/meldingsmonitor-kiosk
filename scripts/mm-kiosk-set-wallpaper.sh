#!/usr/bin/env bash
# Stelt het MeldingsMonitor bureaubladachtergrond in voor Pi desktop en Lite.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

TARGET_DIR="/opt/meldingsmonitor-kiosk"
SOURCE_WALLPAPER="${TARGET_DIR}/assets/wallpaper.png"
SYSTEM_WALLPAPER="/usr/share/meldingsmonitor-kiosk/wallpaper.png"
TARGET_USER="${1:-$(detect_primary_user || true)}"

if [[ -z "${TARGET_USER}" ]] || ! id "${TARGET_USER}" >/dev/null 2>&1; then
    echo "Geen geldige gebruiker gevonden voor bureaubladachtergrond." >&2
    exit 1
fi

if [[ ! -f "${SOURCE_WALLPAPER}" ]]; then
    log "Achtergrondafbeelding ontbreekt: ${SOURCE_WALLPAPER}"
    exit 0
fi

USER_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
USER_ID="$(id -u "${TARGET_USER}")"
USER_WALLPAPER="${USER_HOME}/.local/share/meldingsmonitor/wallpaper.png"

install -d "${USER_HOME}/.local/share/meldingsmonitor"
install -d /usr/share/meldingsmonitor-kiosk
install -m 0644 "${SOURCE_WALLPAPER}" "${USER_WALLPAPER}"
install -m 0644 "${SOURCE_WALLPAPER}" "${SYSTEM_WALLPAPER}"

if command -v update-alternatives >/dev/null 2>&1; then
    update-alternatives --install /etc/alternatives/desktop-background desktop-background "${SYSTEM_WALLPAPER}" 100 2>/dev/null || true
    update-alternatives --set desktop-background "${SYSTEM_WALLPAPER}" 2>/dev/null || true
fi

configure_pcmanfm_profile() {
    local profile_dir="$1"
    mkdir -p "${profile_dir}"
    cat > "${profile_dir}/desktop-items-0.conf" <<EOF
[*]
wallpaper_mode=crop
wallpaper_common=1
wallpaper=${USER_WALLPAPER}
desktop_bg=#0c1018
show_wm_menu=0
show_trash=0
show_documents=0
show_mounts=0
EOF

    cat > "${profile_dir}/pcmanfm.conf" <<EOF
[desktop]
wallpaper_mode=crop
wallpaper_common=1
wallpaper=${USER_WALLPAPER}
desktop_bg=#0c1018
EOF
}

for profile in LXDE-pi LXDE default; do
    configure_pcmanfm_profile "${USER_HOME}/.config/pcmanfm/${profile}"
done

if is_pi_desktop && command -v labwc >/dev/null 2>&1; then
    LABWC_DIR="${USER_HOME}/.config/labwc"
    RC_FILE="${LABWC_DIR}/rc.xml"
    AUTOSTART_DIR="${LABWC_DIR}/autostart"

    mkdir -p "${LABWC_DIR}" "${AUTOSTART_DIR}"

    if [[ ! -f "${RC_FILE}" && -f /etc/xdg/labwc/rc.xml ]]; then
        cp /etc/xdg/labwc/rc.xml "${RC_FILE}"
    fi

    if [[ -f "${RC_FILE}" ]]; then
        if grep -q '<background>' "${RC_FILE}"; then
            sed -i "s|<file>.*</file>|<file>${USER_WALLPAPER}</file>|g" "${RC_FILE}"
        else
            sed -i "0,/<openbox_config[^>]*>/s|<openbox_config\\([^>]*\\)>|<openbox_config\\1>\\n  <background>\\n    <image>\\n      <file>${USER_WALLPAPER}</file>\\n      <mode>fill</mode>\\n    </image>\\n  </background>|" "${RC_FILE}"
        fi
    fi

    PREPARE_SCRIPT="${TARGET_DIR}/scripts/mm-kiosk-prepare-desktop.sh"
    cat > "${AUTOSTART_DIR}/00-mm-kiosk-prepare-desktop" <<EOF
#!/bin/sh
exec ${PREPARE_SCRIPT}
EOF
    chmod 0755 "${AUTOSTART_DIR}/00-mm-kiosk-prepare-desktop"

    rm -f "${AUTOSTART_DIR}/mm-kiosk-wallpaper" "${AUTOSTART_DIR}/mm-kiosk-hide-cursor" 2>/dev/null || true
fi

if ! is_pi_desktop; then
    apt-get install -y feh 2>/dev/null || true

    OPENBOX_AUTOSTART="${USER_HOME}/.config/openbox/autostart"
    mkdir -p "$(dirname "${OPENBOX_AUTOSTART}")"

    if [[ ! -f "${OPENBOX_AUTOSTART}" ]]; then
        touch "${OPENBOX_AUTOSTART}"
    fi

    if ! grep -q 'mm-kiosk-prepare-desktop.sh' "${OPENBOX_AUTOSTART}"; then
        cat >> "${OPENBOX_AUTOSTART}" <<EOF
${TARGET_DIR}/scripts/mm-kiosk-prepare-desktop.sh &
EOF
    fi
fi

chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config" "${USER_HOME}/.local/share/meldingsmonitor"

if [[ -d "/run/user/${USER_ID}" ]]; then
    sudo -u "${TARGET_USER}" \
        XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
        HOME="${USER_HOME}" \
        "${TARGET_DIR}/scripts/mm-kiosk-prepare-desktop.sh" || true
fi

log "Bureaubladachtergrond ingesteld voor ${TARGET_USER}."
