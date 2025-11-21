#!/bin/bash
# 运行时更新 URL 列表（合并新旧 URL）
# 用于 Docker 容器运行时定期更新

set -e

SOURCE_URL="https://raw.githubusercontent.com/uu6/llxhq/main/index.php"
URL_FILE="/app/urls/external_urls.txt"
TEMP_FILE=$(mktemp)
TEMP_FILTERED=$(mktemp)
TEMP_NEW_URLS=$(mktemp)

# 清理临时文件
cleanup() {
    rm -f "$TEMP_FILE" "$TEMP_FILTERED" "$TEMP_NEW_URLS"
}
trap cleanup EXIT

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [URL更新] $1"
}

log_info "开始更新 URL 列表..."

# 备份当前的 URL 文件
if [ -f "$URL_FILE" ]; then
    BACKUP_FILE="${URL_FILE}.backup.$(date +%s)"
    cp "$URL_FILE" "$BACKUP_FILE"
    log_info "已备份当前 URL 列表: $BACKUP_FILE"
fi

# 获取当前的 URL 列表（去除注释和空行）
CURRENT_URLS=""
if [ -f "$URL_FILE" ]; then
    CURRENT_URLS=$(grep -v '^#' "$URL_FILE" | grep -v '^$' || true)
fi
CURRENT_COUNT=$(echo "$CURRENT_URLS" | grep -c '^' || echo "0")
log_info "当前 URL 数量: $CURRENT_COUNT"

# 获取新的 URL
log_info "从 $SOURCE_URL 获取最新 URL..."
if ! curl -sSL --connect-timeout 30 --max-time 60 "$SOURCE_URL" -o "$TEMP_FILE"; then
    log_info "警告: 获取新 URL 失败，继续使用现有列表"
    exit 0
fi

# 提取所有 http/https URL
grep -oE 'https?://[^"'"'"'<>[:space:]]+' "$TEMP_FILE" | sort -u > "$TEMP_FILTERED"
RAW_COUNT=$(wc -l < "$TEMP_FILTERED")
log_info "提取到 $RAW_COUNT 个原始 URL"

# 过滤 URL（排除小文件）
EXCLUDE_EXT="\.js$|\.css$|\.json$|\.xml$|\.svg$|\.ico$|\.woff$|\.woff2$|\.ttf$|\.eot$"
KEEP_KEYWORDS="\.apk|\.exe|\.dmg|\.bin|\.zip|\.7z|\.mp4|\.mov|\.avi|\.mkv|\.png|\.jpg|\.jpeg|\.gif|\.test|mb\.test|download|speed|speedtest|cdn|file|bytes=|__down|\.dat"

{
    while IFS= read -r url; do
        url=$(echo "$url" | sed 's/[。,，、：；]$//')
        lower_url=$(echo "$url" | tr '[:upper:]' '[:lower:]')

        if echo "$lower_url" | grep -qE "$EXCLUDE_EXT"; then
            if echo "$url" | grep -qiE 'chunk|vendor|bundle|lib'; then
                if ! echo "$lower_url" | grep -qE '\.json$|\.xml$'; then
                    echo "$url"
                fi
            fi
            continue
        fi

        if echo "$lower_url" | grep -qE "$KEEP_KEYWORDS"; then
            echo "$url"
        fi
    done < "$TEMP_FILTERED"
} | sort -u > "$TEMP_NEW_URLS"

NEW_URLS=$(cat "$TEMP_NEW_URLS")
NEW_COUNT=$(echo "$NEW_URLS" | grep -c '^' || echo "0")
log_info "过滤后新 URL 数量: $NEW_COUNT"

# 合并新旧 URL（去重）
MERGED_URLS=$(
    {
        echo "$CURRENT_URLS"
        echo "$NEW_URLS"
    } | grep -v '^$' | sort -u
)
MERGED_COUNT=$(echo "$MERGED_URLS" | grep -c '^' || echo "0")

# 计算新增的 URL
ADDED_COUNT=$((MERGED_COUNT - CURRENT_COUNT))

log_info "合并结果: 共 $MERGED_COUNT 个 URL (+$ADDED_COUNT 新增)"

# 如果有新增 URL，则更新文件
if [ "$ADDED_COUNT" -gt 0 ]; then
    CURRENT_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

    {
        echo "# Auto-generated and merged URLs from https://github.com/uu6/llxhq"
        echo "# Total URLs: $MERGED_COUNT"
        echo "# Last updated: $CURRENT_TIME"
        echo "# Added this update: +$ADDED_COUNT"
        echo ""
        echo "$MERGED_URLS"
    } > "$URL_FILE"

    log_info "✓ 已更新 URL 列表，新增 $ADDED_COUNT 个 URL"

    # 触发重新测速标记（如果主进程支持）
    touch /tmp/url_updated_flag

    # 显示新增的 URL（前5个）
    NEW_ONLY=$(comm -13 <(echo "$CURRENT_URLS" | sort) <(echo "$MERGED_URLS" | sort))
    NEW_ONLY_COUNT=$(echo "$NEW_ONLY" | grep -c '^' || echo "0")
    if [ "$NEW_ONLY_COUNT" -gt 0 ]; then
        log_info "新增 URL 示例:"
        echo "$NEW_ONLY" | head -5 | sed 's/^/  + /'
    fi
else
    log_info "没有新增 URL，跳过更新"
fi

log_info "URL 更新完成"
