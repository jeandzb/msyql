# 1. 指定基础镜像
FROM registry.cn-beijing.aliyuncs.com/alphesh-soft/mysql:8.0.28

# 2. 维护者信息
LABEL maintainer="yourname@example.com"

# 3. 修复源并安装 jemalloc
# 步骤解析：
# A. 移除 /etc/apt/sources.list.d/mysql.list，避免 GPG 密钥过期报错 (我们不需要更新 MySQL)
# B. 将 Debian 10 源修改为归档源 (archive.debian.org)
# C. 忽略源的过期时间限制 (Acquire::Check-Valid-Until=false)
# D. 安装 libjemalloc2
RUN rm -f /etc/apt/sources.list.d/mysql.list \
    && echo "deb http://archive.debian.org/debian/ buster main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://archive.debian.org/debian-security/ buster/updates main contrib non-free" >> /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get -o Acquire::Check-Valid-Until=false install -y libjemalloc2 \
    && rm -rf /var/lib/apt/lists/*

# 4. 设置环境变量 LD_PRELOAD
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# 5. 验证文件是否存在
RUN ls -lh $LD_PRELOAD

# 6. 暴露端口
EXPOSE 3306