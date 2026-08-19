#!/usr/bin/env bash
# Stelt het MeldingsMonitor bureaubladachtergrond in voor Pi desktop en Lite.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

TARGET_DIR="/opt/meldingsmonitor-kiosk"
SOURCE_WALLPAPER="${TARGET_DIR}/assets/wallpaper.png"
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
install -m 0644 "${SOURCE_WALLPAPER}" "${USER_WALLPAPER}"

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
}

configure_pcmanfm_profile "${USER_HOME}/.config/pcmanfm/LXDE-pi"
configure_pcmanfm_profile "${USER_HOME}/.config/pcmanfm/default"

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

    cat > "${AUTOSTART_DIR}/mm-kiosk-wallpaper" <<EOF
#!/bin/sh
sleep 2
pcmanfm --set-wallpaper="${USER_WALLPAPER}" --wallpaper-mode=crop 2>/dev/null || true
EOF
    chmod 0755 "${AUTOSTART_DIR}/mm-kiosk-wallpaper"
fi

if ! is_pi_desktop; then
    apt-get install -y feh 2>/dev/null || true

    OPENBOX_AUTOSTART="${USER_HOME}/.config/openbox/autostart"
    mkdir -p "$(dirname "${OPENBOX_AUTOSTART}")"

    if [[ ! -f "${OPENBOX_AUTOSTART}" ]]; then
        touch "${OPENBOX_AUTOSTART}"
    fi

    if ! grep -q 'meldingsmonitor/wallpaper.png' "${OPENBOX_AUTOSTART}"; then
        cat >> "${OPENBOX_AUTOSTART}" <<EOF
feh --bg-fill "${USER_WALLPAPER}" &
EOF
    fi
fi

chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config" "${USER_HOME}/.local/share/meldingsmonitor"

if [[ -d "/run/user/${USER_ID}" ]]; then
    sudo -u "${TARGET_USER}" \
        XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
        pcmanfm --set-wallpaper="${USER_WALLPAPER}" --wallpaper-mode=crop 2>/dev/null || true
fi

log "Bureaubladachtergrond ingesteld voor ${TARGET_USER}."
