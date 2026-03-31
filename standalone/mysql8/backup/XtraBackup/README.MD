## XtraBackup 最终交付说明

本目录已整理为生产项目交付最终版。

交付文件如下：

- 值班速查版：[XTRABACKUP_ONCALL_QUICK_REFERENCE.MD](/home/jean/project/jean/msyql/standalone/mysql8/backup/XtraBackup/XTRABACKUP_ONCALL_QUICK_REFERENCE.MD)
- 正式交付版：[XTRABACKUP_DELIVERY_MANUAL.MD](/home/jean/project/jean/msyql/standalone/mysql8/backup/XtraBackup/XTRABACKUP_DELIVERY_MANUAL.MD)
- 模板化配置文件：[backup.env](/home/jean/project/jean/msyql/standalone/mysql8/backup/XtraBackup/backup.env)

优先阅读：

- 值班速查版：[XTRABACKUP_ONCALL_QUICK_REFERENCE.MD](/home/jean/project/jean/msyql/standalone/mysql8/backup/XtraBackup/XTRABACKUP_ONCALL_QUICK_REFERENCE.MD)
- 正式交付版：[XTRABACKUP_DELIVERY_MANUAL.MD](/home/jean/project/jean/msyql/standalone/mysql8/backup/XtraBackup/XTRABACKUP_DELIVERY_MANUAL.MD)
- 模板化配置文件：[backup.env](/home/jean/project/jean/msyql/standalone/mysql8/backup/XtraBackup/backup.env)

这套方案现在按 `192.168.0.253` 的实际部署对齐：

- MySQL 容器：`mysql8_dev`
- Compose 文件：`/alphesh/soft/mysql8_dev/docker-compose.yaml`
- MySQL 配置：`/alphesh/soft/mysql8_dev/conf/my.cnf`
- 数据目录：`/alphesh/data/mysql8_dev/data`
- binlog 目录：`/alphesh/data/mysql8_dev/binlog`
- NFS 备份根目录：`/mnt/mysql_nfs_backup/mysql8_dev`
- XtraBackup 目录：`/mnt/mysql_nfs_backup/mysql8_dev/xtrabackup`
- 备份账号：`backup@%`

## 线上核查结论

截至 `2026-03-30`，已确认：

- MySQL `8.0.28` 正常运行，容器健康。
- 现网 `log_bin_basename=/var/lib/mysql-bin/mysql-bin`。
- 现网 `backup@%` 已具备 `RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT, BACKUP_ADMIN` 权限。
- `gtid_mode=OFF`，当前恢复依赖 `mysqlbinlog` 的时间点或位置回放，不依赖 GTID。
- 线上 NFS 中已有 `mysqldump` 全量备份文件。
- 已完成 1 条真实 XtraBackup 验证链路：
  - 全量：`2026-03-30_10-36-32`
  - 增量：`2026-03-30_10-48-34`
  - binlog 归档：`2026-03-30/mysql-bin.000005` 到 `mysql-bin.000009`
  - prepare：已验证成功
  - 独立恢复实例：已验证成功
- 当前脚本已支持压缩：
  - 全量 / 增量默认启用 `xtrabackup --compress`
  - binlog 归档默认压成 `*.gz`
  - `prepare_backup.sh` 会在工作副本里自动解压再合并
- 当前主库 `binlog_expire_logs_seconds=86400`，本地 binlog 仅保留 1 天，binlog 归档必须高频执行，否则 PITR 会断档。

## 已修正的脚本问题

- 修正了宿主机路径与 xtrabackup 容器内路径不一致的问题。现在统一使用宿主机 `/mnt/.../xtrabackup`，容器内对应 `/backup/xtrabackup`。
- 增量备份改为按“全量备份目录”分组，避免不同全量周期的增量互相串链。
- `prepare` 只会应用指定全量对应的增量链。
- `cleanup` 删除旧全量时会同时删除对应增量链，避免留下不可恢复的残链。
- 补齐了 `MYSQL_ROOT_PASSWORD` 等线上必需变量，binlog 归档可正常执行。
- `health_check` 现在会检查 `xtrabackup_checkpoints`，不再只看目录是否存在。
- `inc_backup.sh` 已修复“先创建目标目录再选 base，导致把自己当成上一份增量”的问题。
- `archive_binlog.sh` 已修复“错误解析 `SHOW MASTER STATUS`，导致无法识别当前活动 binlog”的问题。
- 已验证 `mysqlbinlog --stop-datetime` 要使用 UTC 边界，不能直接用业务本地时间。
- 已验证恢复实例不能直接从 NFS datadir 启动，应先复制到本地盘。

## 建议调度

- 每周日 `02:00`：执行一次全量备份
- 周一到周六每天 `02:00`：执行一次增量备份
- 每 `5` 分钟：执行一次 binlog 归档
- 每天 `06:00`：执行一次备份健康检查
- 每周至少一次：对最近一条全量链执行 `prepare` 演练
- 每月至少一次：在独立测试目录做一次完整恢复验证

如果业务变更频繁，也可以把增量周期缩到每 `3` 小时一次，但不要用“所有增量都堆在一个目录层级”的旧结构。

## binlog 归档保留建议

- binlog 归档的作用是补齐最近一次全量 / 增量之后的数据变化，用于 PITR。
- 不需要无限保留所有 binlog，但归档保留期至少要覆盖你承诺的 PITR 窗口。
- 当前默认 `FULL_RETENTION_DAYS=28`、`BINLOG_RETENTION_DAYS=14`，只保证最近 14 天可以做 PITR。
- 如果要求“任何仍在保留期内的全量链都能做 PITR”，请把 `BINLOG_RETENTION_DAYS` 调整到不小于 `FULL_RETENTION_DAYS`。

## 目录结构

```text
/mnt/mysql_nfs_backup/mysql8_dev/xtrabackup/
├── full/
│   ├── 2026-03-30_02-00-00/
│   └── latest -> 2026-03-30_02-00-00
├── inc/
│   └── 2026-03-30_02-00-00/
│       ├── 2026-03-31_02-00-00/
│       └── 2026-04-01_02-00-00/
├── binlog/
│   └── 2026-04-01/
├── logs/
└── restore_test/
```

## 创建备份账号

```mysql
CREATE USER 'backup'@'%' IDENTIFIED BY 'StrongBackupPass!';
GRANT RELOAD, LOCK TABLES, PROCESS, REPLICATION CLIENT ON *.* TO 'backup'@'%';
GRANT BACKUP_ADMIN ON *.* TO 'backup'@'%';
FLUSH PRIVILEGES;
```

## 执行方式

以下命令假设脚本已部署到线上目录 `/alphesh/soft/mysql8_dev/scripts/xtrabackup/`，且 `backup.env` 已使用线上路径。

```bash
./full_backup.sh
./inc_backup.sh
./archive_binlog.sh
./health_check_backup.sh
./prepare_backup.sh 2026-03-30_02-00-00
./restore_backup.sh 2026-03-30_02-00-00
./cleanup_backup.sh
```

## 标准恢复流程

### 场景 1：宿主机或容器故障，需要快速整库恢复

1. 停掉当前 MySQL 容器。
2. 备份当前故障现场目录，禁止直接覆盖原 `datadir`。
3. 选择最近一次全量备份目录。
4. 按顺序应用该全量对应的全部增量。
5. 完成 `prepare`。
6. 将恢复结果复制到新的恢复目录。
7. 按镜像内 `mysql` 用户 UID/GID 修正权限。
8. 用恢复后的目录启动 MySQL。
9. 使用 `mysqlbinlog` 按时间点或位置回放归档 binlog，实现 PITR。
10. 验证业务库可读写、核心表行数与关键时间点一致。

### 场景 2：误删表 / 误更新

1. 恢复出一个临时实例，不直接覆盖生产。
2. 将 binlog 回放到误操作前一刻。
3. 导出目标库表。
4. 审核后再导回生产库。

## 当前限制

- 当前项目只完成了脚本和文档修正，没有直接在 `192.168.0.253` 上启用定时任务。
- 现网仍以 `mysqldump` 为实际生效方案，切换前必须先做一次完整 XtraBackup 演练。
- 因为 `gtid_mode=OFF`，恢复脚本暂不提供 GTID 维度的回放辅助。
- 由于线上本地 binlog 只保留 1 天，若归档任务停跑超过 24 小时，时间点恢复能力会失效。
