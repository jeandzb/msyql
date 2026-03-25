## 备份规则：
每周日 02:00：全量备份
每天 02:00：增量备份/每 3 小时 1 次增量备份
每 5 分钟/15 分钟：归档新的 binlog 文件
每天：校验最近备份目录结构与 prepare 能力
每周：做一次完整恢复演练

## 创建备份账号
```mysql
CREATE USER 'backup'@'%' IDENTIFIED BY 'StrongBackupPass!';
GRANT RELOAD, LOCK TABLES, PROCESS, REPLICATION CLIENT ON *.* TO 'backup'@'%';
GRANT BACKUP_ADMIN ON *.* TO 'backup'@'%';
FLUSH PRIVILEGES;
```
## 标准恢复流程
场景 1：宿主机或容器故障，需要快速整库恢复
* 停掉当前 MySQL 容器
* 备份现有损坏现场目录，避免二次破坏
* 取最近全量备份
* 如有增量，按顺序 apply
* 对备份做 prepare
* 恢复到一个新的 datadir
* 修正文件属主属组
* 用恢复后的 datadir 启动 MySQL
* 验证实例可读写
* 用 mysqlbinlog 回放到故障前时点

MySQL 官方明确说明 mysqlbinlog 可以按事件时间或位置筛选 binlog 并重放，实现时间点恢复。

场景 2：误删表 / 误执行 UPDATE
* 先恢复出一个临时实例
* 回放到误操作前一刻
* 导出需要恢复的库表
* 导回生产库

这样比直接在线“回滚”更稳。