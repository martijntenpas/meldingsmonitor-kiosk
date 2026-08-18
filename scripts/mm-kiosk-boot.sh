#!/usr/bin/env bash
# Main boot orchestrator: setup mode or kiosk mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="${SCRIPT_DIR}/../web"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
ensure_state_dir

if [[ ! -f "${MM_KIOSK_CONFIG}" ]]; then
    install -d "$(dirname "${MM_KIOSK_CONFIG}")"
    install -m 0644 "${SCRIPT_DIR}/../config/config.example.json" "${MM_KIOSK_CONFIG}"
    log "Standaardconfig aangemaakt op ${MM_KIOSK_CONFIG}."
fi

SETUP_COMPLETED="$(json_value setup_completed 2>/dev/null || echo "false")"
FORCE_SETUP="$(json_value force_setup 2>/dev/null || echo "false")"
WEB_PORT="$(json_value web_port 2>/dev/null || echo "80")"

ONLINE=0
if "${SCRIPT_DIR}/mm-kiosk-network-check.sh"; then
    ONLINE=1
fi

NEEDS_SETUP=0
if [[ "${FORCE_SETUP}" == "true" || "${SETUP_COMPLETED}" != "true" ]]; then
    NEEDS_SETUP=1
fi

if [[ "${NEEDS_SETUP}" -eq 0 && "${ONLINE}" -eq 0 ]]; then
    log "Geen internet terwijl setup afgerond is; setup-modus opnieuw openen."
    NEEDS_SETUP=1
fi

if [[ "${NEEDS_SETUP}" -eq 1 ]]; then
    log "Setup-modus actief."

    if ! "${SCRIPT_DIR}/mm-kiosk-network-check.sh"; then
        "${SCRIPT_DIR}/mm-kiosk-setup-ap.sh" || log "Kon setup access point niet starten."
    fi

    export MM_KIOSK_CONFIG
    export MM_KIOSK_SCRIPTS="${SCRIPT_DIR}"

    PYTHON="${WEB_DIR}/.venv/bin/python"
    if [[ ! -x "${PYTHON}" ]]; then
        PYTHON="python3"
    fi

    exec "${PYTHON}" "${WEB_DIR}/app.py" --host 0.0.0.0 --port "${WEB_PORT}"
fi

log "Online; kiosk-modus starten."
exec "${SCRIPT_DIR}/mm-kiosk-start-kiosk.sh"
