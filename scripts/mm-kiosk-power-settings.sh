#!/usr/bin/env bash
# Disables screen blanking, sleep, suspend and hibernate for 24/7 kiosk use.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

log "Energie- en scherminstellingen uitschakelen voor kioskmodus."

mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/mm-kiosk.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
IdleActionSec=0
EOF

for target in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
    systemctl mask "${target}" 2>/dev/null || true
done

if [[ -w /sys/module/kernel/parameters/consoleblank ]]; then
    echo 0 > /sys/module/kernel/parameters/consoleblank
fi

mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/mm-kiosk-consoleblank.conf <<'EOF'
w /sys/module/kernel/parameters/consoleblank - - - - 0
EOF

if is_raspberry_pi && command -v raspi-config >/dev/null 2>&1; then
    raspi-config nonint do_blanking 1 >/dev/null 2>&1 || true
fi

KIOSK_USER="${MM_KIOSK_USER:-kiosk}"
OPENBOX_AUTOSTART="/etc/xdg/openbox/autostart"

if [[ -f "${OPENBOX_AUTOSTART}" ]] && ! grep -q "mm-kiosk power settings" "${OPENBOX_AUTOSTART}"; then
    cat >> "${OPENBOX_AUTOSTART}" <<'EOF'

# mm-kiosk power settings
xset s off
xset s noblank
xset -dpms
xset dpms 0 0 0
EOF
fi

if command -v lightdm >/dev/null 2>&1; then
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/51-mm-kiosk-power.conf <<'EOF'
[Seat:*]
xserver-command=X -s 0 -dpms
EOF
fi

systemctl daemon-reload
systemctl restart systemd-logind 2>/dev/null || true

log "Energie- en scherminstellingen toegepast."
