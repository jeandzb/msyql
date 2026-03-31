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
WORK_MOUNT_DIR="${RESTORE_TEST_MOUNT_DIR}/prepare_${FULL_NAME}"
LOG_FILE="${SCRIPT_LOG_DIR}/prepare_backup_${FULL_NAME}_${TS}.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

decompress_if_needed() {
  local backup_dir="$1"
  local mount_dir="${backup_dir/#${RESTORE_TEST_DIR}/${RESTORE_TEST_MOUNT_DIR}}"

  if ! find "${backup_dir}" -type f -name '*.qp' -print -quit | grep -q .; then
    return 0
  fi

  echo "[INFO] decompress backup dir: ${backup_dir}"
  run_xtrabackup \
    --decompress \
    --remove-original \
    --parallel="${XTRABACKUP_DECOMPRESS_THREADS}" \
    --target-dir="${mount_dir}"
}

echo "[INFO] $(date '+%F %T') start prepare backup"
echo "[INFO] full backup dir: ${FULL_BACKUP_DIR}"
echo "[INFO] work dir: ${WORK_DIR}"

if [[ ! -d "${FULL_BACKUP_DIR}" ]]; then
  echo "[ERROR] full backup dir not found: ${FULL_BACKUP_DIR}"
  exit 1
fi

rm -rf "${WORK_DIR}"
cp -a "${FULL_BACKUP_DIR}" "${WORK_DIR}"

decompress_if_needed "${WORK_DIR}"

echo "[INFO] apply redo only on full backup copy"
run_xtrabackup \
  --prepare \
  --apply-log-only \
  --target-dir="${WORK_MOUNT_DIR}"

INC_CHAIN_DIR="${INC_DIR}/${FULL_NAME}"
INC_LIST="$(find "${INC_CHAIN_DIR}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort || true)"

if [[ -n "${INC_LIST}" ]]; then
  while IFS= read -r incdir; do
    [[ -z "${incdir}" ]] && continue
    incbase="$(basename "${incdir}")"
    work_inc_dir="${WORK_DIR}/inc_${incbase}"

    rm -rf "${work_inc_dir}"
    cp -a "${incdir}" "${work_inc_dir}"
    decompress_if_needed "${work_inc_dir}"

    echo "[INFO] apply incremental dir: ${incdir}"
    run_xtrabackup \
      --prepare \
      --apply-log-only \
      --target-dir="${WORK_MOUNT_DIR}" \
      --incremental-dir="${RESTORE_TEST_MOUNT_DIR}/prepare_${FULL_NAME}/inc_${incbase}"
  done <<< "${INC_LIST}"
fi

echo "[INFO] final prepare"
run_xtrabackup \
  --prepare \
  --target-dir="${WORK_MOUNT_DIR}"

ln -sfn "${WORK_DIR}" "${LATEST_PREPARED_LINK}"

echo "[INFO] prepare completed: ${WORK_DIR}"
