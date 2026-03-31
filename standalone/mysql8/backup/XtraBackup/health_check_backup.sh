#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

echo "[INFO] backup health check at $(date '+%F %T')"

LATEST_FULL="$(find "${FULL_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"
LATEST_FULL_NAME=""
LATEST_INC=""
LATEST_BINLOG_ARCHIVE="$(find "${BINLOG_ARCHIVE_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"

echo "[INFO] latest full backup : ${LATEST_FULL:-NONE}"
echo "[INFO] latest binlog arch : ${LATEST_BINLOG_ARCHIVE:-NONE}"

if [[ -z "${LATEST_FULL}" ]]; then
  echo "[ERROR] no full backup found"
  exit 1
fi

LATEST_FULL_NAME="$(basename "${LATEST_FULL}")"
LATEST_INC="$(find "${INC_DIR}/${LATEST_FULL_NAME}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)"

echo "[INFO] latest inc backup  : ${LATEST_INC:-NONE}"

if [[ ! -f "${LATEST_FULL}/xtrabackup_checkpoints" ]]; then
  echo "[ERROR] invalid full backup, xtrabackup_checkpoints missing: ${LATEST_FULL}"
  exit 1
fi

if [[ -n "${LATEST_INC}" && ! -f "${LATEST_INC}/xtrabackup_checkpoints" ]]; then
  echo "[ERROR] invalid incremental backup, xtrabackup_checkpoints missing: ${LATEST_INC}"
  exit 1
fi

if [[ -z "${LATEST_BINLOG_ARCHIVE}" ]]; then
  echo "[WARN] no archived binlog found, PITR is not available yet"
fi

echo "[INFO] backup health check passed"
