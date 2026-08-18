#!/usr/bin/env bash
# Sync station-screen-kiosk to a standalone public Git repository.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${MM_KIOSK_PUBLISH_DIR:-$(cd "${SOURCE_DIR}/../../.." && pwd)/meldingsmonitor-kiosk}"
REMOTE_URL="${MM_KIOSK_REMOTE_URL:-https://github.com/martijntenpas/meldingsmonitor-kiosk.git}"
BRANCH="${MM_KIOSK_BRANCH:-main}"

echo "Bron:  ${SOURCE_DIR}"
echo "Doel:  ${TARGET_DIR}"
echo "Remote: ${REMOTE_URL}"

mkdir -p "${TARGET_DIR}"

rsync -a --delete \
    --exclude '.git' \
    --exclude 'web/.venv' \
    --exclude '__pycache__' \
    --exclude '.pytest_cache' \
    "${SOURCE_DIR}/" "${TARGET_DIR}/"

if [[ ! -d "${TARGET_DIR}/.git" ]]; then
    git -C "${TARGET_DIR}" init -b "${BRANCH}"
    git -C "${TARGET_DIR}" remote add origin "${REMOTE_URL}" 2>/dev/null || \
        git -C "${TARGET_DIR}" remote set-url origin "${REMOTE_URL}"
fi

git -C "${TARGET_DIR}" add -A

if git -C "${TARGET_DIR}" diff --cached --quiet; then
    echo "Geen wijzigingen om te publiceren."
    exit 0
fi

git -C "${TARGET_DIR}" commit -m "chore: sync from meldingsmonitor monorepo"

echo "Pushen naar ${REMOTE_URL} ..."
git -C "${TARGET_DIR}" push -u origin "${BRANCH}"

echo "Publicatie afgerond."
