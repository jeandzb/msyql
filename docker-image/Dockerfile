# 1. 指定基础镜像
FROM registry.cn-beijing.aliyuncs.com/alphesh-soft/mysql:8.0.28

# 2. 维护者信息 (可选)
LABEL maintainer="yourname@example.com"

# 3. 安装 jemalloc
# mysql:8.0.28 官方镜像基于 Oracle Linux 8，使用 microdnf 作为包管理器。
# jemalloc 位于 EPEL 源中，因此需要分步安装：
# 1. 更新包缓存
# 2. 安装 epel-release (为了获取 jemalloc)
# 3. 安装 jemalloc
# 4. 清理缓存以减小镜像体积
RUN microdnf update -y \
    && microdnf install -y epel-release \
    && microdnf install -y jemalloc \
    && microdnf clean all \
    && rm -rf /var/cache/yum

# 4. 设置环境变量 LD_PRELOAD
# 这是启用 jemalloc 的核心步骤。
# 在 Oracle Linux 8 (RHEL 8) 中，jemalloc 库文件默认安装在 /usr/lib64/libjemalloc.so.2
ENV LD_PRELOAD=/usr/lib64/libjemalloc.so.2

# 5. (构建时检查) 验证库文件是否存在
# 如果库文件路径不对，构建会在这一步报错停止，防止生成无效镜像
RUN ls -lh $LD_PRELOAD

# 6. 暴露端口 (继承自基础镜像，显式声明是个好习惯)
EXPOSE 3306