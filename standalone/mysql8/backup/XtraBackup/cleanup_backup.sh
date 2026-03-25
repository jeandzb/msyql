#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

LOG_FILE="${SCRIPT_LOG_DIR}/cleanup_backup_${TS}.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date '+%F %T') start cleanup"

echo "[INFO] cleanup full backups older than ${FULL_RETENTION_DAYS} days"
find "${FULL_DIR}" -mindepth 1 -maxdepth 1 -type d -mtime +"${FULL_RETENTION_DAYS}" -print -exec rm -rf {} \;

echo "[INFO] cleanup incremental backups older than ${INC_RETENTION_DAYS} days"
find "${INC_DIR}" -mindepth 1 -maxdepth 1 -type d -mtime +"${INC_RETENTION_DAYS}" -print -exec rm -rf {} \;

echo "[INFO] cleanup archived binlogs older than ${BINLOG_RETENTION_DAYS} days"
find "${BINLOG_ARCHIVE_DIR}" -mindepth 1 -maxdepth 1 -type d -mtime +"${BINLOG_RETENTION_DAYS}" -print -exec rm -rf {} \;

echo "[INFO] cleanup old script logs older than 30 days"
find "${SCRIPT_LOG_DIR}" -type f -mtime +30 -print -delete

echo "[INFO] cleanup completed"