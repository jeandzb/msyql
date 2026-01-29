#!/bin/bash

# ================= 配置区 =================
# Docker容器名称
CONTAINER_NAME="mysql8_test"
# 数据库认证
DB_USER="root"
DB_PASS="alphesh123"

# 【重要】这里填写你本机挂载 NFS 的实际路径
# 例如你把 192.168.0.234:/alphesh/data/mysql_backup 挂载到了本机的 /mnt/mysql_nfs_backup
BACKUP_DIR="/mnt/mysql_nfs_backup/mysql8_test"

# 备份保留天数
RETENTION_DAYS=7
# 文件名加时间戳
DATE=$(date +%Y%m%d_%H%M%S)
# 日志文件路径
LOG_FILE="/mnt/mysql_nfs_backup/mysql8_test/backup.log"
# =========================================

echo "[$(date)] === 开始备份任务 (目标: $BACKUP_DIR) ===" >> $LOG_FILE

# 1. 预检查：确认挂载目录是否存在且可写
if [ ! -d "$BACKUP_DIR" ]; then
    echo "[$(date)] 错误: 备份目录 $BACKUP_DIR 不存在！请检查 NFS 是否已挂载。" >> $LOG_FILE
    exit 1
fi

# 测试写入权限
touch "$BACKUP_DIR/test_write_permission" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[$(date)] 错误: 无法写入 $BACKUP_DIR，请检查 NFS 权限。" >> $LOG_FILE
    exit 1
fi
rm -f "$BACKUP_DIR/test_write_permission"

# 2. 执行备份 + 压缩 (流式处理)
# 解释：mysqldump 的输出通过管道 (|) 直接传给 gzip
# gzip 压缩后的数据直接写入文件。
# 结果：磁盘上只会生成一个 .sql.gz 文件，不会产生中间的 .sql 文件。
echo "[$(date)] 正在导出并压缩..." >> $LOG_FILE

docker exec $CONTAINER_NAME /usr/bin/mysqldump \
    -u$DB_USER \
    -p$DB_PASS \
    --all-databases \
    --single-transaction \
    --quick \
    --routines --events --triggers \
    | gzip > "$BACKUP_DIR/mysql_full_$DATE.sql.gz"

# 获取管道命令的退出状态
# 注意：默认情况下 bash 只获取管道最后一个命令(gzip)的状态，
# set -o pipefail 可以让脚本捕获 mysqldump 的错误，但普通 sh 可能不支持。
# 这里我们检查生成的压缩包大小是否异常小来辅助判断。

# 3. 验证与重启
if [ -s "$BACKUP_DIR/mysql_full_$DATE.sql.gz" ]; then
    FILE_SIZE=$(du -h "$BACKUP_DIR/mysql_full_$DATE.sql.gz" | cut -f1)
    echo "[$(date)] 备份成功。文件: mysql_full_$DATE.sql.gz (大小: $FILE_SIZE)" >> $LOG_FILE

    # === 重启容器逻辑 ===
    echo "[$(date)] 正在重启 Docker 容器 $CONTAINER_NAME ..." >> $LOG_FILE
    docker restart $CONTAINER_NAME

    sleep 10
    # 检查容器状态
    if [ "$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME)" = "true" ]; then
        echo "[$(date)] 容器重启成功，服务运行中。" >> $LOG_FILE
    else
        echo "[$(date)] 警告: 容器重启后未处于运行状态！" >> $LOG_FILE
    fi
    # ===================

    # 4. 清理旧备份 (只清理该目录下的压缩包)
    find "$BACKUP_DIR" -name "mysql_full_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    echo "[$(date)] 已清理 $RETENTION_DAYS 天前的旧备份文件" >> $LOG_FILE

else
    echo "[$(date)] 失败: 备份文件为空或未生成！跳过容器重启。" >> $LOG_FILE
    # 删除可能的空文件
    rm -f "$BACKUP_DIR/mysql_full_$DATE.sql.gz"
fi

echo "[$(date)] === 任务结束 ===" >> $LOG_FILE