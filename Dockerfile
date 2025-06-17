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

# 从构建阶段复制 oha 二进制文件
COPY --from=builder /oha /bin/oha

# 设置默认环境变量
ENV th=2
ENV time=2147483647sec
ENV url=http://img.cmvideo.cn/publish/noms/2022/10/14/1O3VIGPVP6HTS.jpg
ENV ui=--no-tui

# 用 shell 形式的 ENTRYPOINT 让环境变量生效
ENTRYPOINT exec /bin/oha -z ${time} -c ${th} ${url}  ${ui} 





