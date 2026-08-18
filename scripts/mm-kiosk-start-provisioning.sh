#!/usr/bin/env bash
# Starts the provisioning Flask app in the background.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="${SCRIPT_DIR}/../web"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
ensure_state_dir

WEB_PORT="$(json_value web_port 2>/dev/null || echo "80")"
PID_FILE="${MM_KIOSK_STATE_DIR}/web.pid"

if [[ -f "${PID_FILE}" ]]; then
    existing_pid="$(cat "${PID_FILE}")"
    if kill -0 "${existing_pid}" 2>/dev/null; then
        log "Provisioning-server draait al (pid ${existing_pid})."
        exit 0
    fi
fi

export MM_KIOSK_CONFIG
export MM_KIOSK_SCRIPTS="${SCRIPT_DIR}"
export MM_KIOSK_STATE_DIR

PYTHON="${WEB_DIR}/.venv/bin/python"
if [[ ! -x "${PYTHON}" ]]; then
    PYTHON="python3"
fi

log "Provisioning-server starten op poort ${WEB_PORT}."
"${PYTHON}" "${WEB_DIR}/app.py" --host 0.0.0.0 --port "${WEB_PORT}" >> "${MM_KIOSK_LOG}" 2>&1 &
echo $! > "${PID_FILE}"

for _ in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:${WEB_PORT}/api/status" >/dev/null 2>&1; then
        log "Provisioning-server bereikbaar."
        exit 0
    fi
    sleep 0.5
done

log "Provisioning-server gestart, maar healthcheck mislukt."
exit 0
