#!/usr/bin/env bash
# Verbergt de muiscursor op het bureaublad en in Chromium (Pi kiosk).

set -uo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

hide_cursor_once() {
    if command -v unclutter >/dev/null 2>&1; then
        if ! pgrep -f 'unclutter.*-idle' >/dev/null 2>&1; then
            DISPLAY="${DISPLAY:-:0}" unclutter -idle 0 -root -noevents &
        fi
    fi

    if command -v wtype >/dev/null 2>&1 && [[ -S "${RUNTIME_DIR}/wayland-0" ]]; then
        wtype -M alt -M logo -P h -m alt -m logo 2>/dev/null || true
    fi
}

if [[ "${MM_KIOSK_CURSOR_LOOP_STARTED:-}" == "1" ]]; then
    exit 0
fi

export MM_KIOSK_CURSOR_LOOP_STARTED=1

hide_cursor_once

(
    while true; do
        sleep 2
        hide_cursor_once
    done
) &
