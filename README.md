<div align="center">

# 🚀 NetworkSpeedTest

### 智能网络测速工具

[![CI Debian](https://img.shields.io/github/actions/workflow/status/zuohuadong/networkdownload/docker-image.yml?style=flat-square&logo=docker&label=Debian&color=blue)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image.yml)
[![CI Alpine](https://img.shields.io/github/actions/workflow/status/zuohuadong/networkdownload/docker-image%20alpine.yml?style=flat-square&logo=alpine-linux&label=Alpine&color=0D597F)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image%20alpine.yml)
[![CI Bun](https://img.shields.io/github/actions/workflow/status/zuohuadong/networkdownload/docker-image-bun.yml?style=flat-square&logo=bun&label=Bun&color=fbf0df)](https://github.com/zuohuadong/networkdownload/actions/workflows/docker-image-bun.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/zuohuadong/networkdownload?style=flat-square&logo=docker&color=2496ED)](https://hub.docker.com/r/zuohuadong/networkdownload)
[![Docker Image Size](https://img.shields.io/docker/image-size/zuohuadong/networkdownload/latest?style=flat-square&logo=docker&color=2496ED)](https://hub.docker.com/r/zuohuadong/networkdownload)
[![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)](LICENSE)

多节点智能测速 · 自动选择最优线路 · 实时速度监控 · 动态节点更新

</div>

---

## 快速开始

```bash
docker run zuohuadong/networkdownload
```

> 💡 **提示**：查看更多镜像版本，请访问 [Docker Hub](https://hub.docker.com/r/zuohuadong/networkdownload)

## 特性

- ✅ **智能多节点测速**：启动时自动测试所有测速节点，智能选择最优线路
- ✅ **并发测速**：默认 5 个并发测速，快速完成节点评估（约 10 秒）
- ✅ **实时速度监控**：持续监控网络速度，动态评估网络质量
- ✅ **滑动窗口算法**：使用最近 3 次测速结果的平均值，准确反映网络状态
- ✅ **智能容错机制**：容忍短暂网络波动，避免误判
- ✅ **自动节点优选**：智能过滤慢速节点，只使用高质量测速源
- ✅ **多测速源支持**：内置多个全球测速节点（Cloudflare、OVH、Tele2、Hetzner 等）
- ✅ **测速源动态更新**：首次启动时从 [llxhq](https://github.com/uu6/llxhq) 获取最新测速节点，运行时定期自动更新
- ✅ **故障自动切换**：测速节点失败时自动切换到备用节点
- ✅ **高可用性设计**：多节点冗余，确保测速服务稳定可靠
- ✅ **带宽限速测试**：支持限速环境下的网络测速（基于 trickle）
- ✅ **Webhook 告警**：网络异常时自动发送通知，便于监控
- ✅ **灵活配置**：支持自定义测速节点、并发数、测速间隔、速度阈值等参数


## 内置测速节点

该工具内置以下稳定的测速节点（100MB 测试文件），优先使用对中国大陆友好的节点：

**亚洲优先节点**（中国大陆访问更快）：
- Cachefly CDN（全球 CDN 节点）
- Cloudflare Speed Test（全球 CDN）
- Hetzner 新加坡数据中心
- Hetzner 香港数据中心

**欧美备用节点**：
- OVH Network Test（法国）
- Tele2 Speed Test（瑞典）
- ThinkBroadband Test（英国）
- LeaseWeb Speed Test（荷兰）
- Hetzner 美国数据中心
- OTE Speed Test（希腊）

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `th` | 测速并发连接数 | `2` |
| `time` | 测速持续时间（仅 oha 版本有效） | `2147483647sec` |
| `url_custom` | 自定义测速节点 URL（留空则使用内置节点列表） | `` |
| `ui` | 日志输出控制 | `--no-tui` (debian)<br>`--no-progress` (bun)<br>`silent` 或 `--silent` (完全静默) |
| `min_speed` | 最低速度阈值（KB/s），低于此值视为网络异常 | `200` |
| `check_interval` | 测速间隔（秒），建议 300-600 秒 | `300` |
| `slow_threshold` | 慢速检测次数阈值，达到后切换节点 | `2` (容忍1次波动) |
| `min_benchmark_speed` | 节点过滤阈值（KB/s），过滤掉速度低于此值的节点 | `200` |
| `top_urls` | 保留最快的 N 个节点（0=不限制，保留所有符合条件的节点） | `0` (不限制) |
| `benchmark_concurrent` | 并发测速数量，加快节点评估速度 | `5` |
| `max_display_urls` | 节点列表最大显示数量（0=显示全部） | `10` |
| `speed_window_enabled` | 是否启用滑动窗口平均速度（减少速度波动影响） | `true` |
| `speed_window_size` | 滑动窗口大小（保留最近 N 次测速结果） | `3` |
| `url_update_enabled` | 是否启用测速节点列表自动更新 | `true` |
| `url_update_interval` | 节点列表自动更新间隔（天） | `7` |
| `webhook_url` | Webhook 通知地址（留空则禁用通知） | `` |
| `webhook_enabled` | 是否启用 Webhook 通知 | `true` |
| `webhook_min_interval` | Webhook 最小发送间隔（秒），避免频繁通知 | `3600` (1小时) |
| `webhook_notify_slow` | 是否在速度过低时发送通知 | `true` |
| `webhook_notify_no_nodes` | 是否在无可用节点时发送通知 | `true` |
| `bandwidth_limit_download` | 下载带宽限制（KB/s），用于限速环境测试<br>**仅 Debian 版本支持** | `` |
| `bandwidth_limit_upload` | 上传带宽限制（KB/s），用于限速环境测试<br>**仅 Debian 版本支持** | `` |

## 使用示例

### 基本使用（使用默认配置）
```bash
docker run zuohuadong/networkdownload
```

### 自定义线程数
```bash
docker run -e th=10 zuohuadong/networkdownload
```

### 使用自定义测速节点
```bash
docker run -e url_custom=https://your-speedtest-server.com/testfile.bin zuohuadong/networkdownload
```

### 查看详细日志
```bash
# debian/alpine 版本
docker run -e ui="" zuohuadong/networkdownload

# bun 版本
docker run -e ui="" zuohuadong/networkdownload:bun
```

### 完全静默模式（不输出任何日志）
```bash
# 所有版本通用 - 完全禁用日志输出
docker run -e ui=silent zuohuadong/networkdownload

# 或者使用
docker run -e ui=--silent zuohuadong/networkdownload
```

### 自定义测速参数
```bash
# 设置速度阈值为 500 KB/s，每 10 分钟测速一次
docker run -e min_speed=500 -e check_interval=600 zuohuadong/networkdownload

# 增加并发测速数量以加快节点评估（适合高带宽网络）
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

### 测速配置示例
```bash
# 高性能测速：只使用最快节点，快速响应网络变化
docker run \
  -e th=20 \
  -e top_urls=3 \
  -e min_benchmark_speed=1000 \
  -e slow_threshold=1 \
  -e speed_window_enabled=false \
  -e check_interval=300 \
  zuohuadong/networkdownload

# 稳定性优先：保留所有快速节点，容忍短暂波动（推荐）
docker run \
  -e th=10 \
  -e top_urls=0 \
  -e min_benchmark_speed=300 \
  -e slow_threshold=3 \
  -e speed_window_size=5 \
  -e check_interval=600 \
  zuohuadong/networkdownload

# 全面测速：保留所有高于平均速度的节点
docker run \
  -e th=15 \
  -e top_urls=0 \
  -e min_benchmark_speed=200 \
  -e slow_threshold=2 \
  zuohuadong/networkdownload
```

### 限速环境测速
```bash
# ⚠️ 注意：带宽限速功能仅支持 Debian 版本（latest/debian）

# 模拟 10 MB/s 限速环境进行测速 - Debian 版本
docker run -e bandwidth_limit_download=10240 zuohuadong/networkdownload

# 同时限制下载和上传带宽进行测速 - Debian 版本
docker run -e bandwidth_limit_download=10240 -e bandwidth_limit_upload=5120 zuohuadong/networkdownload:debian

# 在限速环境下进行网络测速 - Debian 版本
docker run -e th=10 -e bandwidth_limit_download=20480 -e min_speed=500 zuohuadong/networkdownload:latest
```

### Webhook 告警通知

```bash
# 启用 Webhook 告警（当网络异常或无可用节点时发送通知）
docker run -e webhook_url=https://your-webhook-endpoint.com/notify zuohuadong/networkdownload

# 自定义 Webhook 配置（最小通知间隔 30 分钟）
docker run -e webhook_url=https://your-webhook-endpoint.com/notify \
  -e webhook_min_interval=1800 \
  zuohuadong/networkdownload

# 只在无可用节点时通知，不在速度过低时通知
docker run -e webhook_url=https://your-webhook-endpoint.com/notify \
  -e webhook_notify_slow=false \
  -e webhook_notify_no_nodes=true \
  zuohuadong/networkdownload

# 结合测速监控使用 Webhook 告警
docker run -e webhook_url=https://your-webhook-endpoint.com/notify \
  -e min_speed=500 \
  -e slow_threshold=3 \
  -e webhook_min_interval=3600 \
  zuohuadong/networkdownload

# 禁用 Webhook 通知
docker run -e webhook_enabled=false zuohuadong/networkdownload
```

**Webhook JSON 数据格式**：
```json
{
  "title": "网络速度异常警告",
  "message": "测速结果持续低于阈值 (平均 180 KB/s < 200 KB/s)，已连续检测 2 次。正在尝试切换测速节点...",
  "level": "warning",
  "hostname": "container-hostname",
  "timestamp": "2025-11-06T12:34:56Z",
  "stats": {
    "total_traffic": "15.23 GB",
    "avg_speed": "5420 KB/s",
    "session_duration": "02:45:30",
    "download_cycles": 33,
    "current_node": "2/5"
  }
}
```

**支持的通知类型**：
- `warning`：网络速度异常警告（当平均速度低于 `min_speed` 阈值时）
- `error`：无可用测速节点警告（当所有节点都不满足速度要求时）

## 版本说明

| 版本标签 | 工具 | 架构支持 | 特点 |
|---------|------|----------|------|
| `latest` / `debian` | oha | amd64, arm64, arm/v7 | 占用内存小，性能好，**支持带宽限速** |
| `alpine` | oha | amd64, arm64 | 体积最小（基于 Alpine），**不支持带宽限速** |
| `bun` | autocannon | amd64, arm64 | 兼容性好，使用 bun 优化，**不支持带宽限速** |

### 多架构支持

所有镜像均支持多架构，Docker 会自动选择适合你系统的架构：
- **x86_64 / amd64**：Intel/AMD 64位处理器
- **ARM64 / aarch64**：ARM 64位处理器（树莓派4、Apple Silicon等）
- **ARM v7**：ARM 32位处理器（仅 debian 版本支持）

## 工作原理

1. **动态节点获取**：首次启动时从 `https://raw.githubusercontent.com/uu6/llxhq/main/index.php` 获取最新测速节点列表
2. **并发测速**：容器启动时，并发测试所有测速节点（默认 5 个并发，下载 5MB 数据测速）
3. **智能过滤**：双重过滤机制，确保只使用真正快速的节点：
   - 过滤条件 1：速度 ≥ min_benchmark_speed（默认 200 KB/s）
   - 过滤条件 2：速度 ≥ 所有节点的平均速度
   - 保留所有同时满足两个条件的节点（默认不限制数量）
   - 可通过 `top_urls` 参数限制保留节点数量
4. **快速启动**：并发测速将启动时间从 60 秒降低到约 10 秒
5. **优选节点**：自动选择最快的节点并持续使用，不会轮询所有节点
6. **持续测速**：每个周期持续测速 5 分钟（可通过 `check_interval` 配置）
7. **定期检查**：每个测速周期结束后检查速度（下载 5MB 测试）
8. **智能切换**：如果速度低于阈值，立即切换到下一个快速节点（默认不等待）
9. **节点轮换**：只在保留的几个最快节点之间切换，不使用慢速节点
10. **故障处理**：如果所有快速节点都变慢或失败，重新测试所有节点并更新节点列表
11. **定期更新**：运行时定期从源地址更新节点列表（默认 7 天更新一次）

## 构建镜像

### 手动构建

```bash
# 构建 debian 版本
docker build -t networkdownload:debian -f Dockerfile .

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
- **动态节点**：容器首次启动时从 [llxhq](https://github.com/uu6/llxhq) 获取最新测速节点

每次构建后，GitHub Actions 会自动推送以下标签：
- `latest`, `debian`, `debian-时间戳`
- `alpine`, `alpine-时间戳`
- `bun`, `bun-时间戳`

查看构建状态：[GitHub Actions](https://github.com/zuohuadong/networkdownload/actions)

## 技术栈

- **构建工具**: [oha](https://github.com/hatoo/oha) (Rust) / [autocannon](https://github.com/mcollina/autocannon) (Node.js)
- **容器化**: Docker multi-stage build
- **CI/CD**: GitHub Actions
- **多架构**: Docker Buildx + QEMU

## 常见问题

### 如何在限速环境下测速？

**⚠️ 重要提示：带宽限制功能仅在 Debian 版本（`latest` / `debian`）中可用。**

本工具的 Debian 版本内置了 `trickle` 带宽限制工具，可以模拟限速环境进行测速：

```bash
# 模拟 10 MB/s 限速环境进行测速 - 仅 Debian 版本
docker run -e bandwidth_limit_download=10240 zuohuadong/networkdownload:debian

# 同时限制下载和上传带宽进行测速（下载 10 MB/s，上传 5 MB/s） - 仅 Debian 版本
docker run -e bandwidth_limit_download=10240 -e bandwidth_limit_upload=5120 zuohuadong/networkdownload:latest
```

**注意**：带宽限制单位为 **KB/s**（千字节/秒）
- 1 MB/s = 1024 KB/s
- 10 MB/s = 10240 KB/s
- 100 MB/s = 102400 KB/s

**版本限制说明**：
- ✅ **Debian 版本** (`latest`, `debian`)：支持带宽限速测试
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

### 如何查看实时测速统计？

运行时不显示日志（默认），如需查看详细测速统计：

```bash
# debian/alpine 版本
docker run -e ui="" zuohuadong/networkdownload

# bun 版本
docker run -e ui="" zuohuadong/networkdownload:bun
```

### 为什么选择这些测速节点？

内置的测速节点都是知名 CDN 或网络服务商提供的公共测速文件：
- 全球节点覆盖广，适合不同地区测速
- 带宽充足，不易被限速
- 专门用于网络测速，合法合规
- 高可用性，多个备份节点

### 智能测速如何工作？

启动时会对每个测速节点进行速度测试：
- **并发测速**：默认同时测试 5 个节点，大幅减少启动时间（从 60秒降到约 10秒）
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
- 顺序测速：10个节点 × 6秒 = 60秒启动时间
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

结果：只使用真正高速的节点，确保测速准确性
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

### 如何配置 Webhook 通知？

Webhook 通知功能可以帮助你实时监控下载状态，在出现异常时及时收到告警。

**支持的 Webhook 服务**：
- 任何接受 JSON POST 请求的 Webhook 服务
- 企业通讯工具（钉钉、企业微信、飞书等，需要配置 Webhook 转换）
- 自定义监控系统或告警平台

**配置示例**：

```bash
# 1. 基本配置（最简单）
docker run -e webhook_url=https://your-webhook.com/notify zuohuadong/networkdownload

# 2. 生产环境配置（推荐）
docker run \
  -e webhook_url=https://your-webhook.com/notify \
  -e webhook_min_interval=3600 \
  -e webhook_notify_slow=true \
  -e webhook_notify_no_nodes=true \
  -e min_speed=500 \
  -e slow_threshold=3 \
  zuohuadong/networkdownload

# 3. 仅关键告警（只在无可用节点时通知）
docker run \
  -e webhook_url=https://your-webhook.com/notify \
  -e webhook_notify_slow=false \
  -e webhook_notify_no_nodes=true \
  zuohuadong/networkdownload
```

**通知触发条件**：
1. **速度过低**（`webhook_notify_slow=true`）：
   - 当滑动窗口平均速度连续低于 `min_speed` 阈值
   - 达到 `slow_threshold` 次数后触发通知
   - 示例：min_speed=200, slow_threshold=2 时，连续 2 次检测速度低于 200 KB/s

2. **无可用节点**（`webhook_notify_no_nodes=true`）：
   - 初始测速时没有找到满足条件的节点
   - 运行时重新测速后所有节点都不满足条件
   - 示例：所有节点速度都低于 `min_benchmark_speed` 或平均速度

**频率限制**：
- 使用 `webhook_min_interval` 避免通知轰炸
- 默认 3600 秒（1 小时）最多发送一次
- 适合长期运行的监控场景

### 节点列表如何更新？

本工具采用动态节点更新机制：

**首次启动**：
- 容器启动时自动从 `https://raw.githubusercontent.com/uu6/llxhq/main/index.php` 获取最新测速节点
- 如果获取失败，将使用内置的备用节点列表（Cloudflare、Hetzner 等）

**运行时更新**：
- 默认每 7 天自动更新一次节点列表（可通过 `url_update_interval` 配置）
- 更新时会保留当前正在使用的节点，确保服务不中断
- 可通过 `url_update_enabled=false` 禁用自动更新

**配置示例**：
```bash
# 禁用运行时自动更新
docker run -e url_update_enabled=false zuohuadong/networkdownload

# 自定义更新间隔（每 3 天更新一次）
docker run -e url_update_interval=3 zuohuadong/networkdownload
```

**注意**：即使节点更新失败，工具仍会使用已有的节点列表继续工作，不会影响核心测速功能。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

Apache License 2.0
