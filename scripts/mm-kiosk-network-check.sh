#!/usr/bin/env bash
# Returns 0 when the configured health URL is reachable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

CHECK_URL="${1:-}"

if [[ -z "${CHECK_URL}" ]]; then
    if [[ ! -f "${MM_KIOSK_CONFIG}" ]]; then
        exit 1
    fi

    CHECK_URL="$(json_value check_url || echo "https://meldingsmonitor.nl/up")"
fi

if curl -fsS --max-time 8 "${CHECK_URL}" >/dev/null 2>&1; then
    exit 0
fi

if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
    exit 0
fi

exit 1
