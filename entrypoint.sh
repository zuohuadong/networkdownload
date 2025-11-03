#!/bin/bash
# Network download traffic generator with multiple fallback URLs

# Stable large file URLs (100MB+ each)
# Priority URLs for China mainland (better performance in CN)
URLS="
http://cachefly.cachefly.net/100mb.test
https://speed.cloudflare.com/__down?bytes=100000000
https://sgp-speed.hetzner.com/100MB.bin
https://hkg-speed.hetzner.com/100MB.bin
https://proof.ovh.net/files/100Mb.dat
http://speedtest.tele2.net/100MB.zip
http://ipv4.download.thinkbroadband.com/100MB.zip
http://mirror.nl.leaseweb.net/speedtest/100mb.bin
https://ash-speed.hetzner.com/100MB.bin
http://speedtest.ftp.otenet.gr/files/test100Mb.db
"

# Load external URLs from file if available (auto-updated by CI)
EXTERNAL_URL_FILE="/app/urls/external_urls.txt"
if [ -f "$EXTERNAL_URL_FILE" ]; then
    echo "Loading external URLs from $EXTERNAL_URL_FILE..."
    EXTERNAL_URLS=$(grep -v '^#' "$EXTERNAL_URL_FILE" | grep -v '^$' || true)
    if [ -n "$EXTERNAL_URLS" ]; then
        EXTERNAL_COUNT=$(echo "$EXTERNAL_URLS" | wc -l)
        echo "Found $EXTERNAL_COUNT external URLs from llxhq"
        URLS="$URLS
$EXTERNAL_URLS"
    fi
fi

# Parse URLs into array
URL_LIST=$(echo "$URLS" | grep -v '^$' | grep -v '^#')
URL_COUNT=$(echo "$URL_LIST" | wc -l)

# Get thread count and time from env (with defaults)
THREADS=${th:-4}
DURATION=${time:-2147483647sec}
UI_FLAG=${ui:---no-tui}
TOOL=${tool:-oha}

# Speed monitoring settings
MIN_SPEED=${min_speed:-200}  # Minimum speed in KB/s (default 200 KB/s)
CHECK_INTERVAL=${check_interval:-300}  # Check speed every 5 minutes (default 300 seconds)
SLOW_THRESHOLD=${slow_threshold:-1}  # Number of consecutive slow detections before switching (default 1 = immediate)
SLOW_COUNT=0  # Counter for consecutive slow speed detections
BENCHMARK_SIZE=5242880  # 5MB for quick speed check (reduced from 10MB)
BENCHMARK_CONCURRENT=${benchmark_concurrent:-5}  # Concurrent benchmark threads (default 5)
MIN_BENCHMARK_SPEED=${min_benchmark_speed:-500}  # Filter out URLs slower than this in KB/s (default 500 KB/s)
TOP_URLS_COUNT=${top_urls:-3}  # Number of fastest URLs to keep and rotate (default 3)

# Traffic statistics variables
TOTAL_BYTES=0  # Total bytes downloaded (累计流量)
SESSION_START=$(date +%s)  # Session start time (会话开始时间)
DOWNLOAD_CYCLES=0  # Number of completed download cycles (下载周期数)

# Bandwidth limiting settings (using trickle)
BANDWIDTH_LIMIT_DOWNLOAD=${bandwidth_limit_download:-}  # Download bandwidth limit in KB/s (empty = no limit)
BANDWIDTH_LIMIT_UPLOAD=${bandwidth_limit_upload:-}  # Upload bandwidth limit in KB/s (empty = no limit)

# Check if trickle is available
TRICKLE_AVAILABLE=false
if command -v trickle >/dev/null 2>&1; then
    TRICKLE_AVAILABLE=true
fi

echo "Network Download Traffic Generator"
echo "===================================="
echo "Tool: $TOOL"
echo "Threads: $THREADS"
echo "Duration: $DURATION"
echo "Available URLs: $URL_COUNT"
echo "Min Speed Threshold: ${MIN_SPEED} KB/s"
echo "Min Benchmark Speed Filter: ${MIN_BENCHMARK_SPEED} KB/s"
echo "Top URLs to Keep: ${TOP_URLS_COUNT}"
echo "Speed Check Interval: ${CHECK_INTERVAL}s (every $((CHECK_INTERVAL / 60)) minutes)"
echo "Slow Detection Threshold: ${SLOW_THRESHOLD} consecutive times (immediate switch if 1)"
echo "Concurrent Benchmarks: ${BENCHMARK_CONCURRENT}"
if [ -n "$BANDWIDTH_LIMIT_DOWNLOAD" ] || [ -n "$BANDWIDTH_LIMIT_UPLOAD" ]; then
    if [ "$TRICKLE_AVAILABLE" = true ]; then
        echo "Bandwidth Limiting: Enabled (via trickle)"
        [ -n "$BANDWIDTH_LIMIT_DOWNLOAD" ] && echo "  Download Limit: ${BANDWIDTH_LIMIT_DOWNLOAD} KB/s"
        [ -n "$BANDWIDTH_LIMIT_UPLOAD" ] && echo "  Upload Limit: ${BANDWIDTH_LIMIT_UPLOAD} KB/s"
    else
        echo "Bandwidth Limiting: UNAVAILABLE (trickle not installed)"
        echo "  Note: Bandwidth limiting is only available in the Debian version"
        echo "  Requested limits will be ignored: download=${BANDWIDTH_LIMIT_DOWNLOAD:-none} KB/s, upload=${BANDWIDTH_LIMIT_UPLOAD:-none} KB/s"
    fi
else
    echo "Bandwidth Limiting: Disabled"
fi
echo ""

# Function to format bytes to human readable format
format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024)) KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1048576)) MB"
    else
        local gb=$((bytes / 1073741824))
        local remainder=$((bytes % 1073741824))
        local decimal=$((remainder * 100 / 1073741824))
        printf "%d.%02d GB\n" $gb $decimal
    fi
}

# Function to format seconds to human readable duration
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Function to display traffic statistics
show_stats() {
    local current_time=$(date +%s)
    local session_duration=$((current_time - SESSION_START))
    local avg_speed=0

    if [ "$session_duration" -gt 0 ]; then
        avg_speed=$((TOTAL_BYTES / session_duration / 1024))  # KB/s
    fi

    echo ""
    echo "=========================================="
    echo "📊 流量统计 | Traffic Statistics"
    echo "=========================================="
    echo "总下载流量: $(format_bytes $TOTAL_BYTES)"
    echo "运行时长: $(format_duration $session_duration)"
    echo "下载周期: ${DOWNLOAD_CYCLES} 次"
    echo "平均速度: ${avg_speed} KB/s"
    [ -n "$CURRENT_URL" ] && echo "当前节点: $CURRENT_URL"
    echo "=========================================="
    echo ""
}

# Function to test if a URL is accessible
test_url() {
    local url=$1
    if command -v curl >/dev/null 2>&1; then
        curl -s --connect-timeout 5 --max-time 10 -r 0-1024 "$url" >/dev/null 2>&1
        return $?
    elif command -v wget >/dev/null 2>&1; then
        wget -q --timeout=5 --tries=1 --spider "$url" >/dev/null 2>&1
        return $?
    else
        # If no curl/wget, just try the URL directly
        return 0
    fi
}

# Function to benchmark URL speed (download speed test)
benchmark_url() {
    local url=$1

    if ! command -v curl >/dev/null 2>&1; then
        echo "0"  # No curl, return 0 speed
        return
    fi

    # Download 5MB and measure speed (reduced from 10MB for lower overhead)
    local start_time=$(date +%s)
    local bytes_downloaded=$(curl -s --connect-timeout 5 --max-time 6 -r 0-$BENCHMARK_SIZE "$url" 2>/dev/null | wc -c)
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Avoid division by zero
    if [ "$duration" -eq 0 ]; then
        duration=1
    fi

    # Calculate speed in KB/s
    local speed=$((bytes_downloaded / duration / 1024))
    echo "$speed"
}

# Function to benchmark a single URL and save result to file (for concurrent execution)
benchmark_url_to_file() {
    local url=$1
    local result_file=$2

    # Simplified output
    # Check if URL is accessible
    if test_url "$url" >/dev/null 2>&1; then
        # Measure download speed
        speed=$(benchmark_url "$url")
        echo "${speed} ${url}" >> "$result_file"
    fi
}

# Function to re-benchmark and re-sort all URLs (with concurrent benchmarking)
rebenchmark_urls() {
    echo "⚠️  速度过慢，重新测速所有节点..."

    TEMP_FILE=$(mktemp)
    local pids=()
    local count=0

    # Re-benchmark all original URLs (not just current filtered list)
    local ORIGINAL_URLS="$URL_LIST"

    # If we have the original full list, use it; otherwise re-read from the inline list
    if [ -z "$FULL_URL_LIST" ]; then
        FULL_URL_LIST=$(echo "$URLS" | grep -v '^$' | grep -v '^#')
        if [ -f "$EXTERNAL_URL_FILE" ]; then
            EXTERNAL_URLS=$(grep -v '^#' "$EXTERNAL_URL_FILE" | grep -v '^$' || true)
            if [ -n "$EXTERNAL_URLS" ]; then
                FULL_URL_LIST="$FULL_URL_LIST
$EXTERNAL_URLS"
            fi
        fi
    fi

    for url in $FULL_URL_LIST; do
        # Launch benchmark in background
        benchmark_url_to_file "$url" "$TEMP_FILE" &
        pids+=($!)
        count=$((count + 1))

        # Limit concurrent processes
        if [ "$count" -ge "$BENCHMARK_CONCURRENT" ]; then
            # Wait for current batch to complete
            for pid in "${pids[@]}"; do
                wait $pid 2>/dev/null
            done
            pids=()
            count=0
        fi
    done

    # Wait for remaining processes
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null
    done

    # Sort by speed (descending) and filter URLs
    SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk -v min_speed="$MIN_BENCHMARK_SPEED" -v max_count="$TOP_URLS_COUNT" '
        $1 >= min_speed && count < max_count {
            print $2
            count++
        }
    ')

    # Count filtered URLs
    local FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c .)

    if [ "$FILTERED_COUNT" -eq 0 ]; then
        echo "⚠️  警告：没有找到速度大于 ${MIN_BENCHMARK_SPEED} KB/s 的节点"
        # Fallback: use top N fastest URLs regardless of speed
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}' | head -n "$TOP_URLS_COUNT")
        FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c . || echo "1")
    fi

    # Show filtered results
    echo "✓ 测速完成，过滤后保留 $FILTERED_COUNT 个最快节点："
    local index=1
    for url in $SORTED_URLS; do
        # Get speed from temp file before deletion
        speed=$(grep -F "$url" "$TEMP_FILE" | head -1 | awk '{print $1}')
        echo "  $index. $url (${speed} KB/s)"
        index=$((index + 1))
    done

    rm -f "$TEMP_FILE"

    # Update URL list
    URL_LIST="$SORTED_URLS"
    SLOW_COUNT=0  # Reset slow count
}

# Function to run download with current tool (runs for CHECK_INTERVAL seconds, then returns)
run_download() {
    local url=$1
    local output_file=$(mktemp)

    # Build trickle command if bandwidth limiting is enabled and trickle is available
    local trickle_cmd=""
    if [ "$TRICKLE_AVAILABLE" = true ] && { [ -n "$BANDWIDTH_LIMIT_DOWNLOAD" ] || [ -n "$BANDWIDTH_LIMIT_UPLOAD" ]; }; then
        trickle_cmd="trickle"
        [ -n "$BANDWIDTH_LIMIT_DOWNLOAD" ] && trickle_cmd="$trickle_cmd -d $BANDWIDTH_LIMIT_DOWNLOAD"
        [ -n "$BANDWIDTH_LIMIT_UPLOAD" ] && trickle_cmd="$trickle_cmd -u $BANDWIDTH_LIMIT_UPLOAD"
    fi

    case "$TOOL" in
        oha)
            # Run for CHECK_INTERVAL seconds - continuous download during this period
            $trickle_cmd /bin/oha -z "${CHECK_INTERVAL}sec" -c "$THREADS" "$url" $UI_FLAG > "$output_file" 2>&1 &
            local pid=$!
            ;;
        autocannon)
            $trickle_cmd autocannon $UI_FLAG -c "$THREADS" -d $CHECK_INTERVAL "$url" > "$output_file" 2>&1 &
            local pid=$!
            ;;
        *)
            echo "Unknown tool: $TOOL"
            rm -f "$output_file"
            exit 1
            ;;
    esac

    # Wait for the download to complete
    wait $pid
    local exit_code=$?

    # Parse and accumulate traffic statistics
    local cycle_bytes=0
    if [ "$exit_code" -eq 0 ]; then
        case "$TOOL" in
            oha)
                # Parse oha output for total data transferred
                # Look for patterns like "Data: 1.23 GB" or "Data: 456 MB"
                cycle_bytes=$(grep -oP 'Data:\s+[\d.]+\s+[KMGT]?B' "$output_file" | head -1 | awk '{
                    value=$2
                    unit=$3
                    bytes=0
                    if (unit == "B") bytes = value
                    else if (unit == "KB") bytes = value * 1024
                    else if (unit == "MB") bytes = value * 1024 * 1024
                    else if (unit == "GB") bytes = value * 1024 * 1024 * 1024
                    else if (unit == "TB") bytes = value * 1024 * 1024 * 1024 * 1024
                    print int(bytes)
                }')
                ;;
            autocannon)
                # Parse autocannon output for total bytes
                # Look for "Bytes/Sec" or total bytes transferred
                cycle_bytes=$(grep -oP '\d+\.?\d*\s+[KMGT]?B' "$output_file" | tail -1 | awk '{
                    value=$1
                    unit=$2
                    bytes=0
                    if (unit == "B") bytes = value
                    else if (unit == "KB") bytes = value * 1024
                    else if (unit == "MB") bytes = value * 1024 * 1024
                    else if (unit == "GB") bytes = value * 1024 * 1024 * 1024
                    print int(bytes)
                }')
                ;;
        esac

        # Update total bytes if we got a valid value
        if [ -n "$cycle_bytes" ] && [ "$cycle_bytes" -gt 0 ]; then
            TOTAL_BYTES=$((TOTAL_BYTES + cycle_bytes))
            DOWNLOAD_CYCLES=$((DOWNLOAD_CYCLES + 1))
        fi
    fi

    # Show output if not suppressed
    if [ -z "$UI_FLAG" ] || [ "$UI_FLAG" = "" ]; then
        cat "$output_file"
    fi

    rm -f "$output_file"
    return $exit_code
}

# Function to check current download speed
check_current_speed() {
    local url=$1

    local current_speed=$(benchmark_url "$url")

    if [ "$current_speed" -lt "$MIN_SPEED" ]; then
        SLOW_COUNT=$((SLOW_COUNT + 1))
        echo "⚠️  速度 ${current_speed} KB/s 低于阈值 ${MIN_SPEED} KB/s (检测次数: ${SLOW_COUNT}/${SLOW_THRESHOLD})"

        if [ "$SLOW_COUNT" -ge "$SLOW_THRESHOLD" ]; then
            echo "🔄 当前节点过慢，准备切换..."
            # Count remaining URLs in list
            local url_count=$(echo "$URL_LIST" | wc -w)

            if [ "$url_count" -gt 1 ]; then
                echo "✓ 切换到下一个快速节点"
                SLOW_COUNT=0  # Reset counter for next URL
                return 1  # Trigger URL switch to next in list
            else
                echo "⚠️  已是最后一个快速节点，重新测速所有节点..."
                rebenchmark_urls
                return 1  # Trigger URL switch
            fi
        else
            echo "→ 继续观察，如果持续慢速将切换节点"
        fi
        return 0  # Continue with current URL for now
    else
        if [ "$SLOW_COUNT" -gt 0 ]; then
            echo "✓ 速度已恢复 (${current_speed} KB/s)"
        fi
        SLOW_COUNT=0  # Reset counter if speed is good
    fi

    return 0
}

# Benchmark all URLs and sort by speed (only run once at startup, with concurrent benchmarking)
if [ -z "$SORTED_URLS" ]; then
    echo "🔍 正在测速所有节点..."

    TEMP_FILE=$(mktemp)
    pids=()
    count=0

    for url in $URL_LIST; do
        # Launch benchmark in background
        benchmark_url_to_file "$url" "$TEMP_FILE" &
        pids+=($!)
        count=$((count + 1))

        # Limit concurrent processes
        if [ "$count" -ge "$BENCHMARK_CONCURRENT" ]; then
            # Wait for current batch to complete
            for pid in "${pids[@]}"; do
                wait $pid 2>/dev/null
            done
            pids=()
            count=0
        fi
    done

    # Wait for remaining processes
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null
    done

    # Sort by speed (descending) and extract URLs
    # Filter: only keep URLs faster than MIN_BENCHMARK_SPEED and limit to TOP_URLS_COUNT
    SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk -v min_speed="$MIN_BENCHMARK_SPEED" -v max_count="$TOP_URLS_COUNT" '
        $1 >= min_speed && count < max_count {
            print $2
            count++
        }
    ')

    # Count filtered URLs
    FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c .)
    TOTAL_TESTED=$(wc -l < "$TEMP_FILE")

    if [ "$FILTERED_COUNT" -eq 0 ]; then
        echo "⚠️  警告：没有找到速度大于 ${MIN_BENCHMARK_SPEED} KB/s 的节点"
        echo "⚠️  降低 min_benchmark_speed 阈值或检查网络连接"
        # Fallback: use all URLs sorted by speed
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}' | head -n "$TOP_URLS_COUNT")
        FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c . || echo "1")
    fi

    # Show filtered results
    echo "✓ 测速完成，过滤结果："
    echo "  总测试: $TOTAL_TESTED 个节点"
    echo "  过滤后: $FILTERED_COUNT 个节点 (速度 ≥ ${MIN_BENCHMARK_SPEED} KB/s)"
    echo ""
    echo "将使用的最快节点："
    index=1
    for url in $SORTED_URLS; do
        # Get speed from temp file before deletion
        speed=$(grep -F "$url" "$TEMP_FILE" | head -1 | awk '{print $1}')
        echo "  $index. $url (${speed} KB/s)"
        index=$((index + 1))
    done
    echo ""

    # Clean up temp file after displaying results
    rm -f "$TEMP_FILE"

    # Use sorted URLs
    URL_LIST="$SORTED_URLS"
fi

# Main loop: use fastest URLs, only switch when speed degrades or download fails
# Initialize URL index
CURRENT_URL_INDEX=1
URL_ARRAY=($URL_LIST)  # Convert to array for indexed access
TOTAL_URLS=${#URL_ARRAY[@]}

while true; do
    # Handle custom URL if provided
    if [ -n "$url_custom" ]; then
        CURRENT_URL="$url_custom"
        echo "📥 使用自定义节点: $url_custom"

        if run_download "$url_custom"; then
            show_stats

            # Check speed, but continue using custom URL regardless
            if ! check_current_speed "$url_custom"; then
                echo "⚠️  自定义节点速度过慢，但将继续使用"
            fi
        else
            echo "❌ 自定义节点下载失败，重试中..."
            sleep 3
        fi
        continue
    fi

    # Get current URL from array (bash arrays are 0-indexed)
    local url="${URL_ARRAY[$((CURRENT_URL_INDEX - 1))]}"

    if [ -z "$url" ]; then
        echo "⚠️  URL 列表为空，重新测速..."
        rebenchmark_urls
        URL_ARRAY=($URL_LIST)
        TOTAL_URLS=${#URL_ARRAY[@]}
        CURRENT_URL_INDEX=1
        continue
    fi

    CURRENT_URL="$url"
    echo "📥 使用节点 #${CURRENT_URL_INDEX}/${TOTAL_URLS}: $url"

    # Run the download for CHECK_INTERVAL seconds
    if run_download "$url"; then
        # Download cycle completed successfully
        show_stats

        # Check if speed is acceptable
        if ! check_current_speed "$url"; then
            # Speed is too slow, switch to next URL
            echo "🔄 切换到下一个节点..."
            CURRENT_URL_INDEX=$((CURRENT_URL_INDEX % TOTAL_URLS + 1))

            # If we've cycled back to first URL, maybe rebenchmark
            if [ "$CURRENT_URL_INDEX" -eq 1 ]; then
                echo "⚠️  已尝试所有快速节点，重新测速..."
                rebenchmark_urls
                URL_ARRAY=($URL_LIST)
                TOTAL_URLS=${#URL_ARRAY[@]}
            fi
            sleep 1
        else
            # Speed is good, continue using this URL
            echo "✓ 速度正常，继续使用当前节点"
        fi
    else
        # Download failed, try next URL
        echo "❌ 下载失败，切换到下一个节点..."
        CURRENT_URL_INDEX=$((CURRENT_URL_INDEX % TOTAL_URLS + 1))
        sleep 3
    fi
done
