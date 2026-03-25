#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <prepared_backup_dir_name>"
  echo "Example: $0 2026-03-25_02-00-00"
  exit 1
fi

PREPARED_NAME="$1"
PREPARED_DIR="${RESTORE_TEST_DIR}/prepare_${PREPARED_NAME}"
RESTORE_DIR="${RESTORE_TEST_DIR}/restored_${PREPARED_NAME}"
LOG_FILE="${SCRIPT_LOG_DIR}/restore_backup_${PREPARED_NAME}_${TS}.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date '+%F %T') start restore backup"
echo "[INFO] prepared dir: ${PREPARED_DIR}"
echo "[INFO] restore dir: ${RESTORE_DIR}"

if [[ ! -d "${PREPARED_DIR}" ]]; then
  echo "[ERROR] prepared backup dir not found: ${PREPARED_DIR}"
  exit 1
fi

rm -rf "${RESTORE_DIR}"
mkdir -p "${RESTORE_DIR}"

cp -a "${PREPARED_DIR}/." "${RESTORE_DIR}/"

echo "[INFO] restore copy completed"
echo "[INFO] next steps:"
echo "  1. stop mysql container"
echo "  2. backup current datadir"
echo "  3. replace datadir with ${RESTORE_DIR}"
echo "  4. chown -R 999:999 or mysql:mysql according to image user"
echo "  5. start mysql container"
echo "  6. replay binlog if PITR is needed"