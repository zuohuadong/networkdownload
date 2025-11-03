# networkdownload

[![ci-debian](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image.yml/badge.svg)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image.yml)
[![ci-alpine](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image%20alpine.yml/badge.svg)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image%20alpine.yml)
[![ci-bun](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image-bun.yml/badge.svg)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image-bun.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/zuohuadong/networkdownload.svg)](https://hub.docker.com/r/zuohuadong/networkdownload)
[![Docker Image Size](https://img.shields.io/docker/image-size/zuohuadong/networkdownload/latest)](https://hub.docker.com/r/zuohuadong/networkdownload)

网络下行流量拉取工具，支持多个备用 URL 自动切换，确保高可用性和稳定性。

## 快速开始

```bash
docker run zuohuadong/networkdownload
```

**Docker Hub**: https://hub.docker.com/r/zuohuadong/networkdownload

## 特性

✅ **多 URL 自动切换**：内置多个稳定的测速文件源（Cloudflare、OVH、Tele2 等）
✅ **故障自动切换**：当一个 URL 失败时自动切换到下一个可用源
✅ **高稳定性**：不依赖单一资源，避免被限速或失效
✅ **灵活配置**：支持自定义 URL、线程数、持续时间等参数

## 内置 URL 列表

该工具内置以下稳定的大文件下载源（100MB）：

- Cloudflare Speed Test
- OVH Network Test
- Tele2 Speed Test
- ThinkBroadband Test
- LeaseWeb Speed Test
- Hetzner Speed Test
- OTE Speed Test

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `th` | 线程数（并发连接数） | `2` |
| `time` | 运行时间（仅 oha 版本有效） | `2147483647sec` |
| `url_custom` | 自定义 URL（留空则使用内置 URL 列表） | `` |
| `ui` | 日志输出控制 | `--no-tui` (rust)<br>`--no-progress` (bun) |

## 使用示例

### 基本使用（使用默认配置）
```bash
docker run zuohuadong/networkdownload
```

### 自定义线程数
```bash
docker run -e th=10 zuohuadong/networkdownload
```

### 使用自定义 URL
```bash
docker run -e url_custom=https://your-custom-url.com/file.bin zuohuadong/networkdownload
```

### 查看详细日志
```bash
# rust/alpine 版本
docker run -e ui="" zuohuadong/networkdownload

# bun 版本
docker run -e ui="" zuohuadong/networkdownload:bun
```

### 组合配置
```bash
docker run -e th=20 -e url_custom=https://example.com/100MB.bin zuohuadong/networkdownload
```

## 版本说明

| 版本标签 | 工具 | 架构支持 | 特点 |
|---------|------|----------|------|
| `latest` / `rust` / `debian` | oha | amd64, arm64, arm/v7 | 占用内存小，性能好 |
| `alpine` | oha | amd64, arm64 | 体积最小（基于 Alpine） |
| `bun` / `nodejs` | autocannon | amd64, arm64 | 兼容性好，使用 bun 优化 |

### 多架构支持

所有镜像均支持多架构，Docker 会自动选择适合你系统的架构：
- **x86_64 / amd64**：Intel/AMD 64位处理器
- **ARM64 / aarch64**：ARM 64位处理器（树莓派4、Apple Silicon等）
- **ARM v7**：ARM 32位处理器（仅 debian 版本支持）

## 工作原理

1. 容器启动时，脚本会按顺序尝试内置的 URL 列表
2. 每个 URL 会先进行连通性测试
3. 选择第一个可用的 URL 开始下载流量
4. 如果下载失败，自动切换到下一个 URL
5. 如果所有 URL 都失败，等待 30 秒后重试

## 构建镜像

### 手动构建

```bash
# 构建 rust 版本
docker build -t networkdownload:rust -f Dockerfile .

# 构建 alpine 版本
docker build -t networkdownload:alpine -f Dockfile-alpine .

# 构建 bun 版本
docker build -t networkdownload:bun -f Dockfile-bun .
```

### 自动构建（CI/CD）

本项目使用 GitHub Actions 实现自动构建和发布：

- **触发条件**：推送到 `main` 分支或手动触发
- **构建平台**：使用 Docker Buildx 进行多架构构建
- **发布目标**：自动推送到 [Docker Hub](https://hub.docker.com/r/zuohuadong/networkdownload)
- **构建缓存**：使用 GitHub Actions Cache 加速构建

每次推送后，GitHub Actions 会自动构建并推送以下标签：
- `latest`, `rust`, `debian`, `debian-时间戳`
- `alpine`, `alpine-时间戳`
- `bun`, `nodejs`, `bun-时间戳`

查看构建状态：[GitHub Actions](https://github.com/zuohuadong/networkdownload/actions)

## 技术栈

- **构建工具**: [oha](https://github.com/hatoo/oha) (Rust) / [autocannon](https://github.com/mcollina/autocannon) (Node.js)
- **容器化**: Docker multi-stage build
- **CI/CD**: GitHub Actions
- **多架构**: Docker Buildx + QEMU

## 常见问题

### 如何限制带宽使用？

Docker 支持网络限流：

```bash
# 限制下载带宽为 10MB/s
docker run --network=my-network \
  --cap-add=NET_ADMIN \
  zuohuadong/networkdownload
```

或使用系统工具如 `tc` (Traffic Control) 进行限流。

### 如何查看实时流量统计？

运行时不显示日志（默认），如需查看详细统计：

```bash
# rust/alpine 版本
docker run -e ui="" zuohuadong/networkdownload

# bun 版本
docker run -e ui="" zuohuadong/networkdownload:bun
```

### 为什么选择这些测速 URL？

内置的 URL 都是知名 CDN 或网络服务商提供的公共测速文件：
- 全球节点覆盖广
- 带宽充足，不易被限速
- 专门用于测速，合法合规
- 高可用性，多个备份

### 可以添加自己的 URL 吗？

可以！使用 `url_custom` 环境变量：

```bash
docker run -e url_custom=https://your-cdn.com/file.bin zuohuadong/networkdownload
```

也可以修改 `entrypoint.sh` 中的 `URLS` 变量添加更多备用 URL。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
 
