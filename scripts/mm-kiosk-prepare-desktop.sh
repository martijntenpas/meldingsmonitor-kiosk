#!/usr/bin/env bash
# Past MeldingsMonitor-achtergrond toe en verbergt de cursor (direct bij opstart).

set -uo pipefail

KIOSK_ROOT="${MM_KIOSK_ROOT:-/opt/meldingsmonitor-kiosk}"
WALLPAPER="${HOME}/.local/share/meldingsmonitor/wallpaper.png"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

apply_wallpaper() {
    [[ -f "${WALLPAPER}" ]] || return

    if command -v pcmanfm >/dev/null 2>&1; then
        pcmanfm --set-wallpaper="${WALLPAPER}" --wallpaper-mode=crop 2>/dev/null || true
        pcmanfm --desktop --profile LXDE-pi --set-wallpaper="${WALLPAPER}" --wallpaper-mode=crop 2>/dev/null || true
        pcmanfm --desktop --profile default --set-wallpaper="${WALLPAPER}" --wallpaper-mode=crop 2>/dev/null || true
    fi

    if command -v feh >/dev/null 2>&1; then
        DISPLAY="${DISPLAY:-:0}" feh --bg-fill "${WALLPAPER}" 2>/dev/null || true
    fi
}

hide_cursor_once() {
    if command -v wtype >/dev/null 2>&1 && [[ -S "${RUNTIME_DIR}/wayland-0" ]]; then
        wtype -M alt -M logo -P h -m alt -m logo 2>/dev/null || true
    fi

    if command -v unclutter >/dev/null 2>&1; then
        if ! pgrep -f 'unclutter.*-idle' >/dev/null 2>&1; then
            DISPLAY="${DISPLAY:-:0}" unclutter -idle 0 -root -noevents &
        fi
    fi
}

start_cursor_loop() {
    if [[ "${MM_KIOSK_CURSOR_LOOP_STARTED:-}" == "1" ]]; then
        return
    fi
    export MM_KIOSK_CURSOR_LOOP_STARTED=1

    (
        while true; do
            hide_cursor_once
            sleep 5
        done
    ) &
}

start_wallpaper_loop() {
    if [[ "${MM_KIOSK_WALLPAPER_LOOP_STARTED:-}" == "1" ]]; then
        return
    fi
    export MM_KIOSK_WALLPAPER_LOOP_STARTED=1

    apply_wallpaper

    (
        for _ in $(seq 1 40); do
            sleep 3
            apply_wallpaper
        done
    ) &
}

apply_wallpaper
hide_cursor_once
start_wallpaper_loop
start_cursor_loop
