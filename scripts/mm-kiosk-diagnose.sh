#!/usr/bin/env bash
# Diagnose waarom het kazernescherm niet op het fysieke scherm verschijnt.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

KIOSK_USER="${MM_KIOSK_USER:-$(cat /etc/meldingsmonitor-kiosk/primary-user 2>/dev/null || detect_primary_user || echo kiosk)}"
DISPLAY="${DISPLAY:-:0}"

echo "==> MeldingsMonitor kiosk diagnose"
echo

echo "-- Systeemdiensten --"
systemctl is-active lightdm.service 2>/dev/null && echo "lightdm: actief" || echo "lightdm: NIET actief"
systemctl is-active mm-kiosk.service 2>/dev/null && echo "mm-kiosk: actief" || echo "mm-kiosk: NIET actief"
systemctl is-active mm-kiosk-web.service 2>/dev/null && echo "mm-kiosk-web: actief" || echo "mm-kiosk-web: NIET actief"
echo "Standaard boot-target: $(systemctl get-default 2>/dev/null || echo onbekend)"
echo

echo "-- Grafische sessie --"
if sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xdpyinfo >/dev/null 2>&1; then
    echo "X11 op ${DISPLAY} voor gebruiker ${KIOSK_USER}: OK"
else
    echo "X11 op ${DISPLAY} voor gebruiker ${KIOSK_USER}: NIET beschikbaar"
    echo "  -> Het scherm toont waarschijnlijk alleen de tekstconsole (SSH/login)."
fi

if pgrep -x Xorg >/dev/null 2>&1 || pgrep -x X >/dev/null 2>&1; then
    echo "Xorg-proces: draait"
else
    echo "Xorg-proces: niet gevonden"
fi

if pgrep -f chromium >/dev/null 2>&1; then
    echo "Chromium: draait"
else
    echo "Chromium: niet gevonden"
fi

echo "Browser-log ($(wc -l < /var/log/mm-kiosk-browser.log 2>/dev/null || echo 0) regels):"
tail -10 /var/log/mm-kiosk-browser.log 2>/dev/null || echo "  geen browser-log"
echo

echo "Autostart-bestanden voor ${KIOSK_USER}:"
USER_HOME="$(getent passwd "${KIOSK_USER}" 2>/dev/null | cut -d: -f6 || true)"
for path in \
    "${USER_HOME}/.config/autostart/mm-kiosk-browser.desktop" \
    "${USER_HOME}/.config/labwc/autostart/mm-kiosk-browser" \
    "${USER_HOME}/.config/systemd/user/mm-kiosk-browser.service"; do
    if [[ -f "${path}" ]]; then
        echo "  OK: ${path}"
    else
        echo "  ontbreekt: ${path}"
    fi
done
echo "systemd user browser: $(systemctl --user is-active mm-kiosk-browser.service 2>/dev/null || echo niet actief)"

echo "Ingelogde gebruiker op scherm: $(who | awk 'NR==1 {print $1}')"
echo

echo "-- Configuratie --"
if [[ -f "${MM_KIOSK_CONFIG}" ]]; then
    python3 - <<PY
import json
import sys

sys.path.insert(0, "${SCRIPT_DIR}/../web")
from kiosk_config import is_homepage_configured

with open("${MM_KIOSK_CONFIG}", encoding="utf-8") as handle:
    config = json.load(handle)

homepage = config.get("homepage", "")
print(f"homepage: {homepage}")
print(f"homepage ok: {is_homepage_configured(homepage)}")
print(f"setup_completed: {config.get('setup_completed')}")
PY
else
    echo "Config ontbreekt: ${MM_KIOSK_CONFIG}"
fi
echo

echo "-- Laatste kiosk-logregels --"
tail -15 "${MM_KIOSK_LOG}" 2>/dev/null || echo "Geen log gevonden."
echo

echo "-- Grafische pakketten --"
for pkg in xserver-xorg openbox lightdm chromium-browser chromium; do
    if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
        echo "${pkg}: geinstalleerd"
    fi
done
echo "Display manager: $(cat /etc/X11/default-display-manager 2>/dev/null || echo onbekend)"
echo "Beschikbare sessies:"
ls -1 /usr/share/xsessions/ 2>/dev/null || echo "  geen xsessions gevonden"
echo

echo "-- lightdm-log --"
journalctl -u lightdm.service -n 10 --no-pager 2>/dev/null || true
echo

if ! sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xdpyinfo >/dev/null 2>&1; then
    PRIMARY="$(cat /etc/meldingsmonitor-kiosk/primary-user 2>/dev/null || echo onbekend)"
    echo "Primaire scherm-gebruiker: ${PRIMARY}"
    echo
    echo "Aanbevolen fix:"
    echo "  cd ~/meldingsmonitor-kiosk && git pull"
    echo "  sudo bash scripts/mm-kiosk-apply-screen.sh"
    echo "  sudo reboot"
fi

if ! systemctl is-active lightdm.service >/dev/null 2>&1; then
    echo "lightdm is niet actief. Voer installatie of fix-display uit:"
    echo "  cd ~/meldingsmonitor-kiosk && sudo bash scripts/install.sh"
fi
