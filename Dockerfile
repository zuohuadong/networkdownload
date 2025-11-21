# 第一阶段：下载 oha
FROM debian:bullseye-slim AS builder
RUN apt-get update && apt-get install -y curl
RUN ARCH=$(dpkg --print-architecture) && \
    OS=$(uname -s | tr '[:upper:]' '[:lower:]') && \
    curl -L "https://github.com/hatoo/oha/releases/latest/download/oha-${OS}-${ARCH}" -o /oha && \
    chmod +x /oha

# 第二阶段：最终镜像
FROM debian:bullseye-slim
#FROM gcr.io/distroless/cc-debian12

ARG PACKAGE="zuohuadong/networkdownload"

LABEL name="${PACKAGE}" \
    documentation="https://github.com/${PACKAGE}/README.md" \
    licenses="MIT License" \
    source="https://github.com/${PACKAGE}"

# 安装 curl、trickle（带宽限制工具）、bash 和 iproute2（提供 ip 命令）
RUN apt-get update && apt-get install -y curl trickle bash iproute2 && rm -rf /var/lib/apt/lists/*

# 从构建阶段复制 oha 二进制文件
COPY --from=builder /oha /bin/oha

# 复制入口脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 创建 URLs 目录和脚本目录
RUN mkdir -p /app/urls /app/scripts

# 复制运行时 URL 获取脚本（首次启动时执行）
COPY scripts/fetch_urls.sh /app/scripts/fetch_urls.sh
COPY scripts/update_urls_runtime.sh /app/scripts/update_urls_runtime.sh
RUN chmod +x /app/scripts/fetch_urls.sh /app/scripts/update_urls_runtime.sh

# 设置默认环境变量
ENV th=2
ENV time=2147483647sec
ENV url_custom=""
ENV ui=--no-tui
ENV tool=oha

# URL 自动更新配置
ENV url_update_enabled=true
ENV url_update_interval=7

# 使用新的入口脚本，支持多个备用 URL
ENTRYPOINT ["/entrypoint.sh"] 





