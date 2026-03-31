#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

LOG_FILE="${SCRIPT_LOG_DIR}/inc_backup_${TS}.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date '+%F %T') start incremental backup"

if [[ ! -L "${LATEST_FULL_LINK}" || ! -d "${LATEST_FULL_LINK}" ]]; then
  echo "[ERROR] latest full backup not found: ${LATEST_FULL_LINK}"
  exit 1
fi

LATEST_FULL_DIR="$(readlink -f "${LATEST_FULL_LINK}")"
LATEST_FULL_NAME="$(basename "${LATEST_FULL_DIR}")"
CHAIN_DIR="${INC_DIR}/${LATEST_FULL_NAME}"
TARGET_DIR="${CHAIN_DIR}/${TS}"
TARGET_MOUNT_DIR="${INC_MOUNT_DIR}/${LATEST_FULL_NAME}/${TS}"

echo "[INFO] current full backup base: ${LATEST_FULL_DIR}"
echo "[INFO] target dir: ${TARGET_DIR}"

mkdir -p "${CHAIN_DIR}"

LAST_INC_DIR="$(find "${CHAIN_DIR}" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/xtrabackup_checkpoints' ';' -print | sort | tail -n 1 || true)"

if [[ -n "${LAST_INC_DIR}" && -d "${LAST_INC_DIR}" ]]; then
  BASE_DIR_FOR_INC="${LAST_INC_DIR}"
  BASE_MOUNT_DIR="${INC_MOUNT_DIR}/${LATEST_FULL_NAME}/$(basename "${LAST_INC_DIR}")"
  echo "[INFO] use last incremental as base: ${BASE_DIR_FOR_INC}"
else
  BASE_DIR_FOR_INC="${LATEST_FULL_DIR}"
  BASE_MOUNT_DIR="${FULL_MOUNT_DIR}/${LATEST_FULL_NAME}"
  echo "[INFO] no incremental found, use latest full as base: ${BASE_DIR_FOR_INC}"
fi

mkdir -p "${TARGET_DIR}"

mapfile -t COMPRESS_ARGS < <(xtrabackup_backup_compress_args)

run_xtrabackup \
  --backup \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  "${COMPRESS_ARGS[@]}" \
  --target-dir="${TARGET_MOUNT_DIR}" \
  --incremental-basedir="${BASE_MOUNT_DIR}"

echo "[INFO] incremental backup completed: ${TARGET_DIR}"
