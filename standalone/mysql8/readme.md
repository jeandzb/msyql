# MySQL 8.0（Docker 单节点）生产部署与备份恢复 README

> 适用场景
> - 单台数据库专用服务器
> - MySQL 8.0 以 Docker / Docker Compose 方式部署
> - 支持单实例单节点，也支持同一宿主机部署多个 MySQL 实例
> - 不做主从
> - 目标是：**快速恢复、保证数据完整性、便于长期维护**

---

# 目录

- [1. 方案目标](#1-方案目标)
- [2. 整体架构说明](#2-整体架构说明)
- [3. 目录规划](#3-目录规划)
- [4. MySQL 配置文件](#4-mysql-配置文件)
- [5. Docker Compose 配置](#5-docker-compose-配置)
- [6. 备份方案设计](#6-备份方案设计)
- [7. 备份账号创建](#7-备份账号创建)
- [8. 备份脚本说明](#8-备份脚本说明)
- [9. 脚本内容](#9-脚本内容)
- [10. 日常操作步骤](#10-日常操作步骤)
- [11. 恢复流程](#11-恢复流程)
- [12. 多实例部署注意事项](#12-多实例部署注意事项)
- [13. 常见问题说明](#13-常见问题说明)
- [14. 上线检查清单](#14-上线检查清单)

---

# 1. 方案目标

本方案用于在单节点 Docker 环境中部署 MySQL 8.0，并建立一套可落地的备份与恢复体系。

核心目标：

1. **MySQL 容器常驻运行**
2. **XtraBackup 不常驻**
    - 仅在备份时通过临时容器拉起执行
    - 执行完成后自动销毁
3. **备份方式采用**
    - 全量物理备份
    - 增量物理备份
    - Binlog 归档
    - 必要时配合 PITR（时间点恢复）
4. **数据目录、日志目录、binlog 目录、backup 目录分离**
5. **统一维护一份 my.cnf**
    - 支持单实例单节点
    - 支持多实例单节点

---

# 2. 整体架构说明

## 2.1 服务角色

本方案中包含两个逻辑角色：

### 1）MySQL 容器
- 常驻运行
- 负责真正提供数据库服务
- 持续向宿主机挂载目录写入数据文件、binlog、日志

### 2）XtraBackup 容器
- 不常驻
- 仅在执行备份/prepare/恢复演练时临时拉起
- 通过网络连接 MySQL
- 同时访问同一份宿主机数据目录
- 读取物理数据文件并输出备份到 `/backup`
- 执行完成后自动销毁

---

## 2.2 为什么 XtraBackup 既要连接 MySQL，又要挂载数据目录

XtraBackup 是**物理备份工具**，不是逻辑导出工具。

它做两件事：

### 控制面
通过网络连接 MySQL：
- 获取备份所需元信息
- 做备份协调
- 获取相关状态

### 数据面
通过挂载宿主机同一份数据目录：
- 读取 MySQL 的物理数据文件
- 生成可恢复的物理备份

因此：

- **连接 MySQL** 不是为了把表数据通过 SQL 导出来
- **挂载 datadir** 才是为了真正读取底层物理数据文件

---

# 3. 目录规划

建议每个实例都按如下结构组织目录。

以实例 `mysql8_3309` 为例：

```text
/alphesh/mysql/mysql8_3309/
  conf/
    my.cnf
  data/
  logs/
  binlog/
  backup/
    full/
    inc/
    binlog/
    restore_test/
  scripts/
    backup.env
    full_backup.sh
    inc_backup.sh
    prepare_backup.sh
    restore_backup.sh
    archive_binlog.sh
    cleanup_backup.sh
    health_check_backup.sh
    crontab.example
  compose.yaml