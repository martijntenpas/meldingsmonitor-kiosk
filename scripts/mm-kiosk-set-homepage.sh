#!/usr/bin/env bash
# Saves the kazernescherm URL without using the web interface.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

HOMEPAGE="${1:-}"
COMPLETE="${2:-false}"

if [[ -z "${HOMEPAGE}" ]]; then
    echo "Gebruik: sudo $0 <kazernescherm-url> [complete]" >&2
    exit 1
fi

python3 - <<PY
import json
import sys

sys.path.insert(0, "${SCRIPT_DIR}/../web")
from kiosk_config import is_homepage_configured

path = "${MM_KIOSK_CONFIG}"
homepage = """${HOMEPAGE}"""
complete = """${COMPLETE}""".lower() in {"1", "true", "yes", "complete"}

if not homepage.startswith("https://"):
    raise SystemExit("Gebruik een HTTPS-URL voor het kazernescherm.")

if not is_homepage_configured(homepage):
    raise SystemExit("URL lijkt geen geldige MeldingsMonitor kazernescherm-link.")

with open(path, encoding="utf-8") as handle:
    config = json.load(handle)

config["homepage"] = homepage.strip()

if complete:
    config["setup_completed"] = True
    config["force_setup"] = False

with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=4, ensure_ascii=False)
    handle.write("\n")

print("Kazernescherm-link opgeslagen.")
PY

if [[ "${COMPLETE}" == "complete" || "${COMPLETE}" == "true" || "${COMPLETE}" == "1" ]]; then
    log "Setup afgerond; kiosk herstarten."
    systemctl restart mm-kiosk.service
fi
