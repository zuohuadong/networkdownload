<div align="center">

# 🚀 NetworkDownload

### 网络下行流量拉取工具

[![CI Debian](https://img.shields.io/github/actions/workflow/status/zuohuadong/networkdownload/docker-image.yml?style=flat-square&logo=docker&label=Debian&color=blue)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image.yml)
[![CI Alpine](https://img.shields.io/github/actions/workflow/status/zuohuadong/networkdownload/docker-image%20alpine.yml?style=flat-square&logo=alpine-linux&label=Alpine&color=0D597F)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image%20alpine.yml)
[![CI Bun](https://img.shields.io/github/actions/workflow/status/zuohuadong/networkdownload/docker-image-bun.yml?style=flat-square&logo=bun&label=Bun&color=fbf0df)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image-bun.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/zuohuadong/networkdownload?style=flat-square&logo=docker&color=2496ED)](https://hub.docker.com/r/zuohuadong/networkdownload)
[![Docker Image Size](https://img.shields.io/docker/image-size/zuohuadong/networkdownload/latest?style=flat-square&logo=docker&color=2496ED)](https://hub.docker.com/r/zuohuadong/networkdownload)
[![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)](LICENSE)

支持多个备用 URL 自动切换 · 智能测速选择 · 带宽限速

</div>

---

## 快速开始

```bash
docker run zuohuadong/networkdownload
```

> 💡 **提示**：查看更多镜像版本，请访问 [Docker Hub](https://hub.docker.com/r/zuohuadong/networkdownload)

## 特性

- ✅ **智能测速选择**：启动时自动测试所有 URL 速度，优先使用最快的节点
- ✅ **并发测速**：默认 5 个并发测速，启动时间从 60 秒降至约 10 秒
- ✅ **动态速度监控**：每 5 分钟检查下载速度，低于阈值时切换节点
- ✅ **滑动窗口平滑**：使用最近 3 次测速结果的平均值，有效减少速度波动误判
- ✅ **容错机制**：默认容忍 1 次速度波动，避免因短暂网络抖动而频繁切换
- ✅ **智能节点过滤**：自动过滤慢速节点，只使用最快的几个节点
- ✅ **多 URL 自动切换**：内置多个稳定的测速文件源（Cloudflare、OVH、Tele2 等）
- ✅ **自动更新 URL 列表**：Docker 构建时从 [llxhq](https://github.com/uu6/llxhq) 获取最新刷流 URL，并支持运行时定期更新
- ✅ **故障自动切换**：当一个 URL 失败时自动切换到下一个可用源
- ✅ **高稳定性**：不依赖单一资源，避免被限速或失效
- ✅ **带宽限速**：支持通过环境变量精确控制下载和上传带宽（基于 trickle）
- ✅ **灵活配置**：支持自定义 URL、线程数、持续时间、速度阈值、带宽限制等参数


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
| `th` | 线程数（并发连接数） | `2` |
| `time` | 运行时间（仅 oha 版本有效） | `2147483647sec` |
| `url_custom` | 自定义 URL（留空则使用内置 URL 列表） | `` |
| `ui` | 日志输出控制 | `--no-tui` (rust)<br>`--no-progress` (bun) |
| `min_speed` | 最低速度阈值（KB/s），低于此值将触发慢速计数 | `200` |
| `check_interval` | 速度检查间隔（秒），建议 300-600 秒 | `300` |
| `slow_threshold` | 慢速检测次数阈值，达到后切换节点 | `2` (容忍1次波动) |
| `min_benchmark_speed` | 过滤阈值（KB/s），启动时过滤掉速度低于此值的节点 | `200` |
| `top_urls` | 保留最快的 N 个节点用于轮换（0=不限制，保留所有符合条件的节点） | `0` (不限制) |
| `benchmark_concurrent` | 并发测速线程数，加快启动速度 | `5` |
| `max_display_urls` | 节点列表最大显示数量（0=显示全部） | `10` |
| `speed_window_enabled` | 是否启用滑动窗口平均速度（减少速度波动影响） | `true` |
| `speed_window_size` | 滑动窗口大小（保留最近 N 次测速结果） | `3` |
| `url_update_enabled` | 是否启用运行时 URL 列表自动更新 | `true` |
| `url_update_interval` | URL 列表自动更新间隔（天） | `7` |
| `bandwidth_limit_download` | 下载带宽限制（KB/s），留空则不限制<br>**仅 Debian 版本支持** | `` |
| `bandwidth_limit_upload` | 上传带宽限制（KB/s），留空则不限制<br>**仅 Debian 版本支持** | `` |

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

# 限制保留最快的 3 个节点，过滤掉低于 1000 KB/s 的节点
docker run -e top_urls=3 -e min_benchmark_speed=1000 zuohuadong/networkdownload

# 不限制节点数量，保留所有高于平均速度的节点（默认行为）
docker run -e top_urls=0 -e min_benchmark_speed=500 zuohuadong/networkdownload

# 容忍多次慢速检测后再切换节点（适合网络波动环境）
docker run -e slow_threshold=3 zuohuadong/networkdownload

# 调整滑动窗口大小以平滑速度波动（保留最近5次测速）
docker run -e speed_window_size=5 zuohuadong/networkdownload

# 禁用滑动窗口，使用实时速度判断（更敏感）
docker run -e speed_window_enabled=false -e slow_threshold=1 zuohuadong/networkdownload
```

### 优化配置示例
```bash
# 高性能配置：只使用最快节点，快速切换慢速节点
docker run \
  -e th=20 \
  -e top_urls=3 \
  -e min_benchmark_speed=1000 \
  -e slow_threshold=1 \
  -e speed_window_enabled=false \
  -e check_interval=300 \
  zuohuadong/networkdownload

# 稳定性优先配置：保留所有快速节点，容忍短暂波动（推荐）
docker run \
  -e th=10 \
  -e top_urls=0 \
  -e min_benchmark_speed=300 \
  -e slow_threshold=3 \
  -e speed_window_size=5 \
  -e check_interval=600 \
  zuohuadong/networkdownload

# 最大化可用节点：保留所有高于平均速度的节点
docker run \
  -e th=15 \
  -e top_urls=0 \
  -e min_benchmark_speed=200 \
  -e slow_threshold=2 \
  zuohuadong/networkdownload
```

### 带宽限速
```bash
# ⚠️ 注意：带宽限速仅支持 Debian 版本（latest/rust/debian）

# 限制下载带宽为 10 MB/s (10240 KB/s) - Debian 版本
docker run -e bandwidth_limit_download=10240 zuohuadong/networkdownload

# 同时限制下载和上传带宽 - Debian 版本
docker run -e bandwidth_limit_download=10240 -e bandwidth_limit_upload=5120 zuohuadong/networkdownload:debian

# 结合其他配置使用带宽限速 - Debian 版本
docker run -e th=10 -e bandwidth_limit_download=20480 -e min_speed=500 zuohuadong/networkdownload:latest
```

## 版本说明

| 版本标签 | 工具 | 架构支持 | 特点 |
|---------|------|----------|------|
| `latest` / `rust` / `debian` | oha | amd64, arm64, arm/v7 | 占用内存小，性能好，**支持带宽限速** |
| `alpine` | oha | amd64, arm64 | 体积最小（基于 Alpine），**不支持带宽限速** |
| `bun` | autocannon | amd64, arm64 | 兼容性好，使用 bun 优化，**不支持带宽限速** |

### 多架构支持

所有镜像均支持多架构，Docker 会自动选择适合你系统的架构：
- **x86_64 / amd64**：Intel/AMD 64位处理器
- **ARM64 / aarch64**：ARM 64位处理器（树莓派4、Apple Silicon等）
- **ARM v7**：ARM 32位处理器（仅 debian 版本支持）

## 工作原理

1. **并发测速**：容器启动时，并发测试所有内置 URL（默认 5 个并发，下载 5MB 数据测速）
2. **智能过滤**：双重过滤机制，确保只使用真正快速的节点：
   - 过滤条件 1：速度 ≥ min_benchmark_speed（默认 200 KB/s）
   - 过滤条件 2：速度 ≥ 所有节点的平均速度
   - 保留所有同时满足两个条件的节点（默认不限制数量）
   - 可通过 `top_urls` 参数限制保留节点数量
3. **快速启动**：并发测速将启动时间从 60 秒降低到约 10 秒
4. **粘性使用**：自动选择最快的节点并持续使用，不会轮询所有节点
5. **持续下载**：每个周期持续下载 5 分钟（可通过 `check_interval` 配置）
6. **定期检查**：每个下载周期结束后检查速度（下载 5MB 测试）
7. **立即切换**：如果速度低于阈值，立即切换到下一个快速节点（默认不等待）
8. **智能轮换**：只在保留的几个最快节点之间切换，不使用慢速节点
9. **故障处理**：如果所有快速节点都变慢或失败，重新测试所有 URL 并更新节点列表

## 构建镜像

### 手动构建

```bash
# 构建 rust 版本
docker build -t networkdownload:rust -f Dockerfile .

# 构建 alpine 版本
docker build -t networkdownload:alpine -f Dockerfile-alpine .

# 构建 bun 版本
docker build -t networkdownload:bun -f Dockerfile-bun .
```

### 自动构建（CI/CD）

本项目使用 GitHub Actions 实现自动构建和发布：

- **触发条件**：推送到 `main` 分支、手动触发或每周定时触发
- **构建平台**：使用 Docker Buildx 进行多架构构建
- **发布目标**：自动推送到 [Docker Hub](https://hub.docker.com/r/zuohuadong/networkdownload)
- **构建缓存**：使用 GitHub Actions Cache 加速构建
- **URL 更新**：每次构建时自动从 [llxhq](https://github.com/uu6/llxhq) 获取最新刷流 URL

每次构建后，GitHub Actions 会自动推送以下标签：
- `latest`, `rust`, `debian`, `debian-时间戳`
- `alpine`, `alpine-时间戳`
- `bun`, `bun-时间戳`

查看构建状态：[GitHub Actions](https://github.com/zuohuadong/networkdownload/actions)

## 技术栈

- **构建工具**: [oha](https://github.com/hatoo/oha) (Rust) / [autocannon](https://github.com/mcollina/autocannon) (Node.js)
- **容器化**: Docker multi-stage build
- **CI/CD**: GitHub Actions
- **多架构**: Docker Buildx + QEMU

## 常见问题

### 如何限制带宽使用？

**⚠️ 重要提示：带宽限制功能仅在 Debian 版本（`latest` / `rust` / `debian`）中可用。**

本工具的 Debian 版本内置了 `trickle` 带宽限制工具，可以通过环境变量轻松控制带宽：

```bash
# 限制下载带宽为 10 MB/s (10240 KB/s) - 仅 Debian 版本
docker run -e bandwidth_limit_download=10240 zuohuadong/networkdownload:debian

# 同时限制下载和上传带宽（下载 10 MB/s，上传 5 MB/s） - 仅 Debian 版本
docker run -e bandwidth_limit_download=10240 -e bandwidth_limit_upload=5120 zuohuadong/networkdownload:latest
```

**注意**：带宽限制单位为 **KB/s**（千字节/秒）
- 1 MB/s = 1024 KB/s
- 10 MB/s = 10240 KB/s
- 100 MB/s = 102400 KB/s

**版本限制说明**：
- ✅ **Debian 版本** (`latest`, `rust`, `debian`)：支持带宽限速
- ❌ **Alpine 版本** (`alpine`)：不支持（Alpine Linux 软件库中没有 trickle）
- ❌ **Bun 版本** (`bun`)：不支持（基于 Alpine）

**其他版本的替代方法**：

如果你使用 Alpine 或 Bun 版本，可以使用 Docker 自带的网络限流功能：

```bash
# 使用 Docker 网络限流（需要 NET_ADMIN 权限）
docker run --network=my-network \
  --cap-add=NET_ADMIN \
  zuohuadong/networkdownload:alpine
```

或者使用系统级工具如 `tc` (Traffic Control) 进行限流。

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
- **计算平均速度**：统计所有节点的平均速度作为基准
- **双重智能过滤**：
  - 条件 1：速度 ≥ min_benchmark_speed（默认 200 KB/s）
  - 条件 2：速度 ≥ 平均速度
  - 只保留同时满足两个条件的节点
- **智能保留节点**：默认保留所有符合条件的快速节点，可通过 `top_urls` 限制数量
- 根据你的网络环境自动选择最优节点
- 不同地区和网络环境会自动适配最优节点组合

**并发测速优化**：
- 顺序测速：10个 URL × 6秒 = 60秒启动时间
- 并发测速（5个）：2轮 × 6秒 = **约12秒启动时间**
- 时间节省：**80%+**

**双重过滤优化示例**：
```
测试 10 个节点，结果如下：
  节点 1:  6000 KB/s  ⚡ (远超平均)
  节点 2:  1500 KB/s  ↑ (高于平均)
  节点 3:  1200 KB/s  ↑ (高于平均)
  节点 4:   800 KB/s  → (接近平均)
  节点 5:   600 KB/s  → (接近平均)
  节点 6:   300 KB/s  (低于平均)
  节点 7-10: < 200 KB/s (慢速)

平均速度: 1200 KB/s
过滤阈值: max(200, 1200) = 1200 KB/s

✓ 保留节点 1、2、3（速度 ≥ 1200 KB/s）
✗ 过滤节点 4-10（速度 < 1200 KB/s 或 < 平均值）

结果：只使用真正高速的节点，避免浪费时间
```

### 动态速度监控如何工作？

运行过程中会定期监控下载速度，采用智能切换策略：
- 默认每 5 分钟检查一次当前 URL 的实际下载速度
- 检查时仅下载 5MB 测试数据，开销极小（每小时约 60MB）
- **滑动窗口平滑**：使用最近 3 次测速结果的平均值，减少波动误判（默认启用）
- **智能容错**：默认容忍 1 次速度波动，连续 2 次检测到慢速才切换节点
- **粘性使用**：如果当前节点速度良好，会持续使用该节点，不会切换
- **智能轮换**：只在预先筛选的最快几个节点之间切换
- **全局重测**：如果所有快速节点都变慢，自动重新测试所有 URL 并更新节点列表
- 适应网络环境变化（如高峰期、线路拥塞等）

**性能优化设计**：
- ✅ 持续下载 5 分钟，不频繁中断
- ✅ 测速开销低：每小时仅约 60MB（12次 × 5MB）
- ✅ 智能判断：结合历史数据，避免因短暂波动而误判
- ✅ 只用快速节点：避免轮询到慢速节点导致速度骤降
- ✅ 可自定义检查间隔和阈值，平衡响应速度和性能开销

**使用场景示例**：
```
场景 1：最快节点稳定
  节点 #1 (Cloudflare 6000 KB/s) → 持续使用 → 不切换
  结果：流量稳定，速度始终保持在 6 MB/s

场景 2：短暂网络波动（新：智能容错）
  测速 1: 5000 KB/s → 正常
  测速 2: 180 KB/s  → 检测到慢速 [1/2] 继续观察
  测速 3: 5100 KB/s → 速度恢复，重置计数器
  结果：识别出短暂波动，保持在优质节点，避免误判

场景 3：节点持续变慢（新：滑动窗口判断）
  测速 1: 5000 KB/s → 滑动平均: 5000
  测速 2: 180 KB/s  → 滑动平均: 2590 (仍高于阈值) [1/2]
  测速 3: 150 KB/s  → 滑动平均: 1777 (低于阈值) [2/2]
    ↓ 连续 2 次检测到慢速，触发切换
  节点 #2 (Hetzner 5000 KB/s) → 切换成功
  结果：准确识别真正变慢的节点并切换

场景 4：所有快速节点都变慢
  节点 #1, #2, #3 都低于阈值
    ↓ 触发全局重测
  重新测试所有 10 个 URL
    ↓ 发现其他节点变快
  更新为新的最快 3 个节点
  结果：适应网络环境变化，始终使用最优节点
```

### 可以添加自己的 URL 吗？

可以！使用 `url_custom` 环境变量：

```bash
docker run -e url_custom=https://your-cdn.com/file.bin zuohuadong/networkdownload
```

也可以修改 `entrypoint.sh` 中的 `URLS` 变量添加更多备用 URL。

### 为什么看到"URL 更新脚本不存在"的警告？

如果你看到以下警告：
```
⚠ URL 更新脚本不存在: /app/scripts/update_urls_runtime.sh
```

**可能原因**：
1. 使用的是旧版本 Docker 镜像，该脚本尚未包含在镜像中
2. 使用自定义构建时未正确复制脚本文件

**解决方法**：
```bash
# 方法 1：拉取最新镜像（推荐）
docker pull zuohuadong/networkdownload:latest

# 方法 2：禁用运行时 URL 自动更新功能
docker run -e url_update_enabled=false zuohuadong/networkdownload

# 方法 3：如果自己构建，确保 Dockerfile 包含以下内容：
# RUN mkdir -p /app/scripts
# COPY scripts/update_urls_runtime.sh /app/scripts/update_urls_runtime.sh
# RUN chmod +x /app/scripts/update_urls_runtime.sh
```

**注意**：此警告不会影响核心下载功能，只是运行时无法自动更新 URL 列表。内置的 URL 列表仍然可以正常使用。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

Apache License 2.0
