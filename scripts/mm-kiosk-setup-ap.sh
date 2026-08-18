#!/usr/bin/env bash
# Starts a temporary setup access point for WiFi provisioning.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
ensure_state_dir

WLAN="$(detect_wlan_interface || true)"
if [[ -z "${WLAN}" ]]; then
    log "Geen WiFi-interface gevonden; setup access point overgeslagen."
    exit 1
fi

PREFIX="$(json_value setup_ssid_prefix 2>/dev/null || echo "MeldingsMonitor-Setup")"
AP_IP="$(json_value setup_ap_ip 2>/dev/null || echo "192.168.4.1")"
AP_CIDR="$(json_value setup_ap_cidr 2>/dev/null || echo "192.168.4.0/24")"

MAC_SUFFIX="$(cat "/sys/class/net/${WLAN}/address" | tr -d ':' | tail -c 5)"
SSID="${PREFIX}-${MAC_SUFFIX^^}"

HOSTAPD_CONF="${MM_KIOSK_STATE_DIR}/hostapd.conf"
DNSMASQ_CONF="${MM_KIOSK_STATE_DIR}/dnsmasq.conf"

cat > "${HOSTAPD_CONF}" <<EOF
interface=${WLAN}
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

cat > "${DNSMASQ_CONF}" <<EOF
interface=${WLAN}
bind-interfaces
dhcp-range=${AP_CIDR},12h
domain-needed
bogus-priv
address=/#/${AP_IP}
EOF

log "Setup access point starten op ${WLAN} (${SSID})."

if command -v nmcli >/dev/null 2>&1; then
    nmcli radio wifi on || true
    nmcli device set "${WLAN}" managed no || true
fi

ip link set "${WLAN}" down || true
ip addr flush dev "${WLAN}" || true
ip addr add "${AP_IP}/24" dev "${WLAN}"
ip link set "${WLAN}" up

if [[ -f "${MM_KIOSK_STATE_DIR}/dnsmasq.pid" ]]; then
    kill "$(cat "${MM_KIOSK_STATE_DIR}/dnsmasq.pid")" 2>/dev/null || true
fi

if [[ -f "${MM_KIOSK_STATE_DIR}/hostapd.pid" ]]; then
    kill "$(cat "${MM_KIOSK_STATE_DIR}/hostapd.pid")" 2>/dev/null || true
fi

dnsmasq --keep-in-foreground --conf-file="${DNSMASQ_CONF}" \
    >> "${MM_KIOSK_LOG}" 2>&1 &
echo $! > "${MM_KIOSK_STATE_DIR}/dnsmasq.pid"

hostapd "${HOSTAPD_CONF}" >> "${MM_KIOSK_LOG}" 2>&1 &
echo $! > "${MM_KIOSK_STATE_DIR}/hostapd.pid"

log "Setup WiFi actief: ${SSID} (gateway ${AP_IP})."
