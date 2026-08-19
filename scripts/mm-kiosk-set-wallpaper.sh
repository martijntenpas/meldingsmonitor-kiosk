#!/usr/bin/env bash
# Stelt het MeldingsMonitor bureaubladachtergrond permanent in (eenmalig bij installatie).

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
WALLPAPER_PATH="${SYSTEM_WALLPAPER}"

install -d /usr/share/meldingsmonitor-kiosk
install -m 0644 "${SOURCE_WALLPAPER}" "${SYSTEM_WALLPAPER}"

if [[ -d /usr/share/rpd-wallpaper ]]; then
    install -m 0644 "${SOURCE_WALLPAPER}" /usr/share/rpd-wallpaper/meldingsmonitor.png
fi

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
wallpaper=${WALLPAPER_PATH}
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
wallpaper=${WALLPAPER_PATH}
desktop_bg=#0c1018
EOF
}

for profile in LXDE-pi LXDE default; do
    configure_pcmanfm_profile "${USER_HOME}/.config/pcmanfm/${profile}"
done

if [[ -d /etc/xdg/pcmanfm ]]; then
    for profile_dir in /etc/xdg/pcmanfm/*/; do
        [[ -d "${profile_dir}" ]] || continue
        configure_pcmanfm_profile "${profile_dir%/}"
    done
fi

configure_labwc_background() {
    local rc_file="$1"
    [[ -f "${rc_file}" ]] || return

    if grep -q '<background>' "${rc_file}"; then
        sed -i "s|<file>.*</file>|<file>${WALLPAPER_PATH}</file>|g" "${rc_file}"
    else
        sed -i "0,/<openbox_config[^>]*>/s|<openbox_config\\([^>]*\\)>|<openbox_config\\1>\\n  <background>\\n    <image>\\n      <file>${WALLPAPER_PATH}</file>\\n      <mode>fill</mode>\\n    </image>\\n  </background>|" "${rc_file}"
    fi
}

if is_pi_desktop && command -v labwc >/dev/null 2>&1; then
    LABWC_DIR="${USER_HOME}/.config/labwc"
    RC_FILE="${LABWC_DIR}/rc.xml"

    mkdir -p "${LABWC_DIR}"

    if [[ ! -f "${RC_FILE}" && -f /etc/xdg/labwc/rc.xml ]]; then
        cp /etc/xdg/labwc/rc.xml "${RC_FILE}"
    fi

    configure_labwc_background "${RC_FILE}"

    if [[ -f /etc/xdg/labwc/rc.xml ]]; then
        configure_labwc_background /etc/xdg/labwc/rc.xml
    fi

    rm -f "${LABWC_DIR}/autostart/00-mm-kiosk-prepare-desktop" \
        "${LABWC_DIR}/autostart/mm-kiosk-wallpaper" 2>/dev/null || true
fi

if ! is_pi_desktop; then
    apt-get install -y feh 2>/dev/null || true

    mkdir -p /etc/xdg/openbox
    OPENBOX_AUTOSTART="/etc/xdg/openbox/autostart"
    touch "${OPENBOX_AUTOSTART}"
    if ! grep -q 'meldingsmonitor-kiosk/wallpaper.png' "${OPENBOX_AUTOSTART}"; then
        cat >> "${OPENBOX_AUTOSTART}" <<EOF
feh --bg-fill "${WALLPAPER_PATH}" &
EOF
    fi
fi

chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config"

log "Bureaubladachtergrond permanent ingesteld voor ${TARGET_USER}."
