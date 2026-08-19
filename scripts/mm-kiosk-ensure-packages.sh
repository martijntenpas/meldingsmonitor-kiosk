#!/usr/bin/env bash
# Zorgt dat kiosk-specifieke systeempakketten geinstalleerd zijn (ook na updates).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

PACKAGES=(
    unclutter
)

if is_pi_desktop; then
    PACKAGES+=(
        wtype
        fonts-noto-color-emoji
        fonts-font-awesome
    )
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y "${PACKAGES[@]}"

log "Kiosk-systeempakketten gecontroleerd."
