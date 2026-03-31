#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

LOG_FILE="${SCRIPT_LOG_DIR}/full_backup_${TS}.log"
TARGET_DIR="${FULL_DIR}/${TS}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date '+%F %T') start full backup"
echo "[INFO] target dir: ${TARGET_DIR}"

mkdir -p "${TARGET_DIR}"

mapfile -t COMPRESS_ARGS < <(xtrabackup_backup_compress_args)

run_xtrabackup \
  --backup \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  "${COMPRESS_ARGS[@]}" \
  --target-dir="${FULL_MOUNT_DIR}/${TS}"

ln -sfn "${TARGET_DIR}" "${LATEST_FULL_LINK}"

echo "[INFO] full backup completed: ${TARGET_DIR}"
