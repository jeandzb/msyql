#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <full_backup_dir_name>"
  echo "Example: $0 2026-03-25_02-00-00"
  exit 1
fi

FULL_NAME="$1"
FULL_BACKUP_DIR="${FULL_DIR}/${FULL_NAME}"
WORK_DIR="${RESTORE_TEST_DIR}/prepare_${FULL_NAME}"
LOG_FILE="${SCRIPT_LOG_DIR}/prepare_backup_${FULL_NAME}_${TS}.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date '+%F %T') start prepare backup"
echo "[INFO] full backup dir: ${FULL_BACKUP_DIR}"
echo "[INFO] work dir: ${WORK_DIR}"

if [[ ! -d "${FULL_BACKUP_DIR}" ]]; then
  echo "[ERROR] full backup dir not found: ${FULL_BACKUP_DIR}"
  exit 1
fi

rm -rf "${WORK_DIR}"
cp -a "${FULL_BACKUP_DIR}" "${WORK_DIR}"

echo "[INFO] apply redo only on full backup copy"
docker compose -f "${COMPOSE_FILE}" run --rm xtrabackup \
  xtrabackup \
  --prepare \
  --apply-log-only \
  --target-dir="/backup/restore_test/prepare_${FULL_NAME}"

INC_LIST="$(find "${INC_DIR}" -mindepth 1 -maxdepth 1 -type d | sort || true)"

if [[ -n "${INC_LIST}" ]]; then
  while IFS= read -r incdir; do
    [[ -z "${incdir}" ]] && continue
    echo "[INFO] apply incremental dir: ${incdir}"
    docker compose -f "${COMPOSE_FILE}" run --rm xtrabackup \
      xtrabackup \
      --prepare \
      --apply-log-only \
      --target-dir="/backup/restore_test/prepare_${FULL_NAME}" \
      --incremental-dir="${incdir}"
  done <<< "${INC_LIST}"
fi

echo "[INFO] final prepare"
docker compose -f "${COMPOSE_FILE}" run --rm xtrabackup \
  xtrabackup \
  --prepare \
  --target-dir="/backup/restore_test/prepare_${FULL_NAME}"

ln -sfn "${WORK_DIR}" "${LATEST_PREPARED_LINK}"

echo "[INFO] prepare completed: ${WORK_DIR}"