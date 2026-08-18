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

if wait_for_provisioning_server "${WEB_PORT}"; then
    log "Provisioning-server draait al."
    exit 0
fi

log "Provisioning-server starten via systemd."
systemctl start mm-kiosk-web.service

if wait_for_provisioning_server "${WEB_PORT}"; then
    log "Provisioning-server bereikbaar."
    exit 0
fi

log "Provisioning-server niet bereikbaar; probeer opnieuw te starten."
systemctl restart mm-kiosk-web.service

if wait_for_provisioning_server "${WEB_PORT}"; then
    log "Provisioning-server bereikbaar na herstart."
    exit 0
fi

log "Provisioning-server start mislukt."
systemctl --no-pager --full status mm-kiosk-web.service || true
journalctl -u mm-kiosk-web.service -n 20 --no-pager || true
exit 1
