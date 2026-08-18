#!/usr/bin/env bash
# Ensures the provisioning web server systemd unit is running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
ensure_state_dir

WEB_PORT="$(json_value web_port 2>/dev/null || echo "80")"

if [[ ! -f /etc/systemd/system/mm-kiosk-web.service ]]; then
    install -m 0644 "${SCRIPT_DIR}/../systemd/mm-kiosk-web.service" /etc/systemd/system/mm-kiosk-web.service
    systemctl daemon-reload
fi

systemctl enable mm-kiosk-web.service >/dev/null 2>&1 || true
systemctl restart mm-kiosk-web.service

for _ in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:${WEB_PORT}/api/health" >/dev/null 2>&1; then
        log "Provisioning-server bereikbaar via systemd."
        exit 0
    fi
    sleep 0.5
done

log "Provisioning-server gestart, maar healthcheck mislukt."
systemctl --no-pager --full status mm-kiosk-web.service || true
exit 1
