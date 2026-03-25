#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

LOG_FILE="${SCRIPT_LOG_DIR}/inc_backup_${TS}.log"
TARGET_DIR="${INC_DIR}/${TS}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date '+%F %T') start incremental backup"
echo "[INFO] target dir: ${TARGET_DIR}"

if [[ ! -L "${LATEST_FULL_LINK}" || ! -d "${LATEST_FULL_LINK}" ]]; then
  echo "[ERROR] latest full backup not found: ${LATEST_FULL_LINK}"
  exit 1
fi

mkdir -p "${TARGET_DIR}"

LAST_INC_DIR="$(find "${INC_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"

if [[ -n "${LAST_INC_DIR}" && -d "${LAST_INC_DIR}" ]]; then
  BASE_DIR_FOR_INC="${LAST_INC_DIR}"
  echo "[INFO] use last incremental as base: ${BASE_DIR_FOR_INC}"
else
  BASE_DIR_FOR_INC="$(readlink -f "${LATEST_FULL_LINK}")"
  echo "[INFO] no incremental found, use latest full as base: ${BASE_DIR_FOR_INC}"
fi

docker compose -f "${COMPOSE_FILE}" run --rm xtrabackup \
  xtrabackup \
  --backup \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  --target-dir="/backup/inc/${TS}" \
  --incremental-basedir="${BASE_DIR_FOR_INC}"

echo "[INFO] incremental backup completed: ${TARGET_DIR}"