#!/bin/bash

# ================= 配置区 =================
# Docker容器名称
CONTAINER_NAME="mysql8_test"
# 数据库认证
DB_USER="root"
DB_PASS="alphesh123"

# 备份目录 (NFS 挂载路径)
BACKUP_DIR="/mnt/mysql_nfs_backup/mysql8_test"

# 备份保留天数
RETENTION_DAYS=7
# 文件名加时间戳
DATE=$(date +%Y%m%d_%H%M%S)
# 日志文件路径
LOG_FILE="/mnt/mysql_nfs_backup/mysql8_test/backup.log"
# =========================================

# 【全局日志捕获】将整个脚本的正常输出(1)和错误输出(2)全部重定向追加到日志文件
# 后续所有的 echo 和执行过程中的任何报错，都会自动写入 LOG_FILE
exec >> "$LOG_FILE" 2>&1

echo "[$(date)] === 开始备份任务 (目标: $BACKUP_DIR) ==="

# 1. 预检查：确认挂载目录是否存在且可写
if [ ! -d "$BACKUP_DIR" ]; then
    echo "[$(date)] 错误: 备份目录 $BACKUP_DIR 不存在！请检查 NFS 是否已挂载。"
    exit 1
fi

touch "$BACKUP_DIR/test_write_permission" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[$(date)] 错误: 无法写入 $BACKUP_DIR，请检查 NFS 权限。"
    exit 1
fi
rm -f "$BACKUP_DIR/test_write_permission"

# 2. 动态获取所有以 log 结尾的表，生成排除参数
echo "[$(date)] 正在计算需要排除的日志表..."

IGNORE_TABLES_STR=$(docker exec $CONTAINER_NAME mysql -u$DB_USER -p$DB_PASS -N -e "
    SELECT CONCAT('--ignore-table=', table_schema, '.', table_name)
    FROM information_schema.tables
    WHERE table_name LIKE '%log'
      AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');
")

# 将多行结果转换为单行空格分隔的字符串
IGNORE_ARGS=$(echo $IGNORE_TABLES_STR | tr '\n' ' ')

echo "[$(date)] 将排除以下表: $IGNORE_ARGS"

# 3. 执行备份 + 压缩 (流式处理)
echo "[$(date)] 正在导出并压缩..."

docker exec $CONTAINER_NAME /usr/bin/mysqldump \
    -u$DB_USER \
    -p$DB_PASS \
    --all-databases \
    --single-transaction \
    --quick \
    --routines --events --triggers \
    $IGNORE_ARGS \
    | gzip > "$BACKUP_DIR/mysql_full_$DATE.sql.gz"

# 4. 验证与清理
if [ -s "$BACKUP_DIR/mysql_full_$DATE.sql.gz" ]; then
    FILE_SIZE=$(du -h "$BACKUP_DIR/mysql_full_$DATE.sql.gz" | cut -f1)
    echo "[$(date)] 备份成功。文件: mysql_full_$DATE.sql.gz (大小: $FILE_SIZE)"

    # 清理该目录下的旧备份压缩包
    find "$BACKUP_DIR" -name "mysql_full_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    echo "[$(date)] 已清理 $RETENTION_DAYS 天前的旧备份文件"
else
    echo "[$(date)] 失败: 备份文件为空或未生成！"
    # 删除可能的空文件
    rm -f "$BACKUP_DIR/mysql_full_$DATE.sql.gz"
fi

echo "[$(date)] === 任务结束 ==="
echo "---------------------------------------------------"