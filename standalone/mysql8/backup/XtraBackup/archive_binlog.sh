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
  mysql -u"${MYSQL_ROOT_USER}" -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH BINARY LOGS;"

CURRENT_BINLOG="$(docker exec "${MYSQL_CONTAINER}" \
  mysql -N -B -u"${MYSQL_ROOT_USER}" -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW MASTER STATUS" \
  | awk 'NR==1 {print $1}')"

if [[ -z "${CURRENT_BINLOG}" ]]; then
  echo "[ERROR] unable to determine current active binlog"
  exit 1
fi

echo "[INFO] current active binlog: ${CURRENT_BINLOG}"

docker exec "${MYSQL_CONTAINER}" \
  mysql -N -B -u"${MYSQL_ROOT_USER}" -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW MASTER STATUS" \
  > "${BINLOG_ARCHIVE_DIR}/${DATE}/master_status_${TS}.txt"

find "${MYSQL_BINLOG_DIR}" -maxdepth 1 -type f -name 'mysql-bin.*' ! -name "${CURRENT_BINLOG}" | while read -r f; do
  base="$(basename "$f")"
  archive_path="${BINLOG_ARCHIVE_DIR}/${DATE}/${base}"

  if [[ "${BINLOG_ARCHIVE_COMPRESS_ENABLED}" == "1" ]]; then
    if [[ ! -f "${archive_path}.gz" ]]; then
      cp -a "$f" "${archive_path}"
      ${BINLOG_ARCHIVE_COMPRESS_CMD} "${archive_path}"
      echo "[INFO] archived: ${base}.gz"
    fi
  elif [[ ! -f "${archive_path}" ]]; then
    cp -a "$f" "${archive_path}"
    echo "[INFO] archived: ${base}"
  fi
done

if [[ -f "${MYSQL_BINLOG_DIR}/mysql-bin.index" && ! -f "${BINLOG_ARCHIVE_DIR}/${DATE}/mysql-bin.index" ]]; then
  cp -a "${MYSQL_BINLOG_DIR}/mysql-bin.index" "${BINLOG_ARCHIVE_DIR}/${DATE}/mysql-bin.index"
fi

echo "[INFO] archive binlog completed"
