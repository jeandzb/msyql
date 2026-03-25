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

docker compose -f "${COMPOSE_FILE}" run --rm xtrabackup \
  xtrabackup \
  --backup \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  --target-dir="/backup/full/${TS}"

ln -sfn "${TARGET_DIR}" "${LATEST_FULL_LINK}"

echo "[INFO] full backup completed: ${TARGET_DIR}"