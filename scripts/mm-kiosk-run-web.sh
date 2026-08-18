#!/usr/bin/env bash
# Runs the provisioning Flask app (used by systemd).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="${SCRIPT_DIR}/../web"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

WEB_PORT="$(json_value web_port 2>/dev/null || echo "80")"
PYTHON="${WEB_DIR}/.venv/bin/python"

if [[ ! -x "${PYTHON}" ]]; then
    PYTHON="python3"
fi

export MM_KIOSK_CONFIG
export MM_KIOSK_SCRIPTS="${SCRIPT_DIR}"
export MM_KIOSK_STATE_DIR

exec "${PYTHON}" "${WEB_DIR}/app.py" --host 0.0.0.0 --port "${WEB_PORT}"
