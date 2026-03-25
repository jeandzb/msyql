#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

echo "[INFO] backup health check at $(date '+%F %T')"

LATEST_FULL="$(find "${FULL_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"
LATEST_INC="$(find "${INC_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"
LATEST_BINLOG_ARCHIVE="$(find "${BINLOG_ARCHIVE_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"

echo "[INFO] latest full backup : ${LATEST_FULL:-NONE}"
echo "[INFO] latest inc backup  : ${LATEST_INC:-NONE}"
echo "[INFO] latest binlog arch : ${LATEST_BINLOG_ARCHIVE:-NONE}"

if [[ -z "${LATEST_FULL}" ]]; then
  echo "[ERROR] no full backup found"
  exit 1
fi

echo "[INFO] backup health check passed"