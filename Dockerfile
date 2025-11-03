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

# 安装 curl 用于 URL 测试
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 从构建阶段复制 oha 二进制文件
COPY --from=builder /oha /bin/oha

# 复制入口脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 创建 URLs 目录（外部 URL 列表将在运行时通过 CI 更新或卷挂载）
RUN mkdir -p /app/urls

# 设置默认环境变量
ENV th=2
ENV time=2147483647sec
ENV url_custom=""
ENV ui=--no-tui
ENV tool=oha

# 使用新的入口脚本，支持多个备用 URL
ENTRYPOINT ["/entrypoint.sh"] 





