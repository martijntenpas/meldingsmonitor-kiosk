#!/usr/bin/env bash
# Returns 0 when a WiFi interface is present on this device.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

if detect_wlan_interface >/dev/null 2>&1; then
    exit 0
fi

exit 1
