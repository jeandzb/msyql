#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backup.env"

LOG_FILE="${SCRIPT_LOG_DIR}/archive_binlog_${TS}.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date '+%F %T') start archive binlog"

mkdir -p "${BINLOG_ARCHIVE_DIR}/${DATE}"

echo "[INFO] flush binary logs"
docker exec "${MYSQL_CONTAINER}" \
  mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-alphesh123}" -e "FLUSH BINARY LOGS;"

CURRENT_BINLOG="$(docker exec "${MYSQL_CONTAINER}" \
  mysql -N -B -uroot -p"${MYSQL_ROOT_PASSWORD:-alphesh123}" -e "SHOW MASTER STATUS\G" \
  | awk '/File:/ {print $2}')"

if [[ -z "${CURRENT_BINLOG}" ]]; then
  echo "[ERROR] unable to determine current active binlog"
  exit 1
fi

echo "[INFO] current active binlog: ${CURRENT_BINLOG}"

find "${MYSQL_BINLOG_DIR}" -maxdepth 1 -type f -name 'mysql-bin.*' ! -name "${CURRENT_BINLOG}" | while read -r f; do
  base="$(basename "$f")"
  if [[ ! -f "${BINLOG_ARCHIVE_DIR}/${DATE}/${base}" ]]; then
    cp -a "$f" "${BINLOG_ARCHIVE_DIR}/${DATE}/${base}"
    echo "[INFO] archived: ${base}"
  fi
done

echo "[INFO] archive binlog completed"