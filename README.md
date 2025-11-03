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

✅ **智能测速选择**：启动时自动测试所有 URL 速度，优先使用最快的节点
✅ **并发测速**：默认 5 个并发测速，启动时间从 60 秒降至约 10 秒
✅ **动态速度监控**：每 60 秒检查下载速度，低于阈值时自动重新测速切换节点
✅ **多 URL 自动切换**：内置多个稳定的测速文件源（Cloudflare、OVH、Tele2 等）
✅ **自动更新 URL 列表**：通过 CI 定期从 [llxhq](https://github.com/uu6/llxhq) 获取最新刷流 URL
✅ **故障自动切换**：当一个 URL 失败时自动切换到下一个可用源
✅ **高稳定性**：不依赖单一资源，避免被限速或失效
✅ **灵活配置**：支持自定义 URL、线程数、持续时间、速度阈值等参数

## 内置 URL 列表

该工具内置以下稳定的大文件下载源（100MB），优先使用对中国大陆友好的节点：

**亚洲优先节点**（中国大陆访问更快）：
- Cachefly CDN（全球节点）
- Cloudflare Speed Test
- Hetzner 新加坡节点
- Hetzner 香港节点

**欧美备用节点**：
- OVH Network Test
- Tele2 Speed Test
- ThinkBroadband Test
- LeaseWeb Speed Test
- Hetzner 美国节点
- OTE Speed Test

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `th` | 线程数（并发连接数） | `4` |
| `time` | 运行时间（仅 oha 版本有效） | `2147483647sec` |
| `url_custom` | 自定义 URL（留空则使用内置 URL 列表） | `` |
| `ui` | 日志输出控制 | `--no-tui` (rust)<br>`--no-progress` (bun) |
| `min_speed` | 最低速度阈值（KB/s），低于此值将触发慢速计数 | `200` |
| `check_interval` | 速度检查间隔（秒），建议 300-600 秒 | `300` |
| `benchmark_concurrent` | 并发测速线程数，加快启动速度 | `5` |

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

### 自定义速度监控参数
```bash
# 设置最低速度为 500 KB/s，每 10 分钟检查一次
docker run -e min_speed=500 -e check_interval=600 zuohuadong/networkdownload

# 增加并发测速数量以加快启动（适合高带宽网络）
docker run -e benchmark_concurrent=10 zuohuadong/networkdownload
```

### 组合配置
```bash
docker run -e th=20 -e min_speed=300 -e check_interval=300 -e benchmark_concurrent=8 zuohuadong/networkdownload
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

1. **并发测速**：容器启动时，并发测试所有内置 URL（默认 5 个并发，下载 5MB 数据测速）
2. **智能排序**：根据实际测速结果，将 URL 按速度从快到慢排序
3. **快速启动**：并发测速将启动时间从 60 秒降低到约 10 秒
4. **优先使用最快节点**：自动选择测速最快的 URL 开始下载流量
5. **持续下载**：每个周期持续下载 5 分钟（可通过 `check_interval` 配置）
6. **定期检查**：每个下载周期结束后检查速度（下载 5MB 测试）
7. **连续慢速检测**：如果速度连续 3 次低于阈值（约 15 分钟），触发重新测速
8. **智能切换**：重新测试所有 URL 并切换到新的最快节点
9. **故障切换**：如果当前 URL 下载失败，立即切换到速度次快的 URL

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

### 智能测速如何工作？

启动时会对每个 URL 进行速度测试：
- **并发测速**：默认同时测试 5 个 URL，大幅减少启动时间（从 60秒降到约 10秒）
- 下载 5MB 数据样本测试实际速度（低开销）
- 根据你的网络环境自动选择最快的节点
- 不同地区和网络环境会自动适配最优节点
- 避免硬编码节点优先级，实现真正的自适应

**并发测速优化**：
- 顺序测速：10个 URL × 6秒 = 60秒启动时间
- 并发测速（5个）：2轮 × 6秒 = **约12秒启动时间**
- 时间节省：**80%+**

### 动态速度监控如何工作？

运行过程中会定期监控下载速度，采用低开销策略：
- 默认每 5 分钟检查一次当前 URL 的实际下载速度
- 检查时仅下载 5MB 测试数据，开销极小（每小时约 60MB）
- 如果速度低于设定阈值（默认 200 KB/s），慢速计数器 +1
- 必须连续 3 次检测到慢速（约 15 分钟）才触发重新测速
- 如果速度恢复，计数器自动清零
- 重新测速时切换到新的最快节点
- 适应网络环境变化（如高峰期、线路拥塞等）

**性能优化设计**：
- ✅ 持续下载 5 分钟，不频繁中断
- ✅ 测速开销低：每小时仅约 60MB（12次 × 5MB）
- ✅ 避免误触发：连续慢速才切换，容忍短暂波动
- ✅ 可自定义检查间隔，平衡响应速度和性能开销

**使用场景示例**：
```
场景：晚高峰时某国际节点变慢
  ↓
第 1 次检测（5分钟后）：150 KB/s，低于 200 KB/s，计数 1/3
  ↓
第 2 次检测（10分钟后）：180 KB/s，仍低于阈值，计数 2/3
  ↓
第 3 次检测（15分钟后）：160 KB/s，仍低于阈值，计数 3/3
  ↓
触发重新测速所有 URL（约 50MB 开销）
  ↓
发现国内 CDN 节点此时更快（400 KB/s）
  ↓
自动切换到新节点，保持稳定速度
```

### 可以添加自己的 URL 吗？

可以！使用 `url_custom` 环境变量：

```bash
docker run -e url_custom=https://your-cdn.com/file.bin zuohuadong/networkdownload
```

也可以修改 `entrypoint.sh` 中的 `URLS` 变量添加更多备用 URL。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

Apache License 2.0
 
