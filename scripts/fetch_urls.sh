#!/bin/bash
# 从 https://github.com/uu6/llxhq/blob/main/index.php 提取刷流 URL
# 定期更新到 urls/external_urls.txt

set -e

# 多个 ghproxy 镜像列表（按优先级排序）
GHPROXY_MIRRORS=(
    "https://raw.githubusercontent.com"  # 直连（优先尝试）
    "https://gh-proxy.net/https://raw.githubusercontent.com"
    "https://ghproxy.com/https://raw.githubusercontent.com"
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com"
    "https://ghps.cc/https://raw.githubusercontent.com"
    "https://gh.api.99988866.xyz/https://raw.githubusercontent.com"
)

SOURCE_PATH="/uu6/llxhq/main/index.php"
OUTPUT_FILE="urls/external_urls.txt"
TEMP_FILE=$(mktemp)
TEMP_FILTERED=$(mktemp)

# 清理临时文件
cleanup() {
    rm -f "$TEMP_FILE" "$TEMP_FILTERED"
}
trap cleanup EXIT

# 尝试使用多个镜像下载
fetch_with_mirrors() {
    local success=false
    
    for mirror in "${GHPROXY_MIRRORS[@]}"; do
        local url="${mirror}${SOURCE_PATH}"
        echo "Trying: $url"
        
        if curl -sSL --connect-timeout 15 --max-time 60 "$url" -o "$TEMP_FILE" 2>/dev/null; then
            # 验证下载的文件不为空且包含有效内容
            if [ -s "$TEMP_FILE" ] && grep -q "http" "$TEMP_FILE" 2>/dev/null; then
                echo "✓ Successfully fetched from: $url"
                success=true
                break
            else
                echo "✗ Invalid content from: $url"
            fi
        else
            echo "✗ Failed to fetch from: $url"
        fi
    done
    
    if [ "$success" = false ]; then
        echo "Error: Failed to fetch URL from all mirrors"
        exit 1
    fi
}

echo "Fetching content using multiple mirrors..."
fetch_with_mirrors

echo "Extracting URLs..."

# 提取所有 http/https URL（使用更宽松的匹配）
grep -oE 'https?://[^"'"'"'<>[:space:]]+' "$TEMP_FILE" | sort -u > "$TEMP_FILTERED"

echo "Found $(cat "$TEMP_FILTERED" | wc -l) raw URLs"

# 排除小文件扩展名
EXCLUDE_EXT="\.js$|\.css$|\.json$|\.xml$|\.svg$|\.ico$|\.woff$|\.woff2$|\.ttf$|\.eot$"

# 保留可能的大文件 URL 关键词
KEEP_KEYWORDS="\.apk|\.exe|\.dmg|\.bin|\.zip|\.7z|\.mp4|\.mov|\.avi|\.mkv|\.png|\.jpg|\.jpeg|\.gif|\.test|mb\.test|download|speed|speedtest|cdn|file|bytes=|__down|\.dat"

# 过滤 URL
{
    while IFS= read -r url; do
        # 移除 URL 末尾的标点符号
        url=$(echo "$url" | sed 's/[。,，、：；]$//')
        lower_url=$(echo "$url" | tr '[:upper:]' '[:lower:]')

        # 检查是否包含排除的扩展名
        if echo "$lower_url" | grep -qE "$EXCLUDE_EXT"; then
            # 但如果是大的 chunk/vendor/bundle 文件则保留（排除 .json 和 .xml）
            if echo "$url" | grep -qiE 'chunk|vendor|bundle|lib'; then
                if ! echo "$lower_url" | grep -qE '\.json$|\.xml$'; then
                    echo "$url"
                fi
            fi
            continue
        fi

        # 保留包含关键词的 URL
        if echo "$lower_url" | grep -qE "$KEEP_KEYWORDS"; then
            echo "$url"
        fi
    done < "$TEMP_FILTERED"
} | sort -u > "${TEMP_FILTERED}.final"

FILTERED_URLS=$(cat "${TEMP_FILTERED}.final")
rm -f "${TEMP_FILTERED}.final"

# 统计数量
URL_COUNT=$(echo "$FILTERED_URLS" | grep -c '^' || echo "0")
echo "Found $URL_COUNT unique URLs"

# 获取当前时间（UTC）
CURRENT_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# 创建输出目录
mkdir -p "$(dirname "$OUTPUT_FILE")"

# 保存到文件
{
    echo "# Auto-generated URLs from https://github.com/uu6/llxhq"
    echo "# Total URLs: $URL_COUNT"
    echo "# Last updated: $CURRENT_TIME"
    echo ""
    echo "$FILTERED_URLS"
} > "$OUTPUT_FILE"

echo "Successfully saved $URL_COUNT URLs to $OUTPUT_FILE"

# 输出一些示例
echo ""
echo "Sample URLs:"
echo "$FILTERED_URLS" | head -5 | sed 's/^/  - /'
