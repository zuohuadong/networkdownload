#!/bin/bash
# Network download traffic generator with multiple fallback URLs

# Set UTF-8 locale to support Unicode characters and emojis
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Terminal colors and formatting
if [ -t 1 ]; then
    # Check if terminal supports colors
    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\033[1m'
    COLOR_DIM=$'\033[2m'
    COLOR_RED=$'\033[0;31m'
    COLOR_GREEN=$'\033[0;32m'
    COLOR_YELLOW=$'\033[0;33m'
    COLOR_BLUE=$'\033[0;34m'
    COLOR_MAGENTA=$'\033[0;35m'
    COLOR_CYAN=$'\033[0;36m'
    COLOR_WHITE=$'\033[0;37m'
    COLOR_GRAY=$'\033[0;90m'

    # Bold colors
    COLOR_BOLD_RED=$'\033[1;31m'
    COLOR_BOLD_GREEN=$'\033[1;32m'
    COLOR_BOLD_YELLOW=$'\033[1;33m'
    COLOR_BOLD_BLUE=$'\033[1;34m'
    COLOR_BOLD_CYAN=$'\033[1;36m'
else
    # No colors if not in terminal
    COLOR_RESET=''
    COLOR_BOLD=''
    COLOR_DIM=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_MAGENTA=''
    COLOR_CYAN=''
    COLOR_WHITE=''
    COLOR_GRAY=''
    COLOR_BOLD_RED=''
    COLOR_BOLD_GREEN=''
    COLOR_BOLD_YELLOW=''
    COLOR_BOLD_BLUE=''
    COLOR_BOLD_CYAN=''
fi

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} ${COLOR_BOLD}$1${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_BOLD_GREEN}✓${COLOR_RESET} ${COLOR_GREEN}$1${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_BOLD_YELLOW}⚠${COLOR_RESET} ${COLOR_YELLOW}$1${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_BOLD_RED}✗${COLOR_RESET} ${COLOR_RED}$1${COLOR_RESET}"
}

log_section() {
    echo ""
    echo -e "${COLOR_BOLD_CYAN}$1${COLOR_RESET}"
    echo -e "${COLOR_GRAY}$(printf '%.0s─' {1..60})${COLOR_RESET}"
}

log_dim() {
    echo -e "${COLOR_DIM}$1${COLOR_RESET}"
}

get_timestamp() {
    date '+%H:%M:%S'
}

# Dynamic logging functions for in-place updates
log_progress() {
    # Print progress message that can be updated in place
    # Usage: log_progress "message"
    echo -ne "\r${COLOR_BLUE}⏳${COLOR_RESET} ${COLOR_BOLD}$1${COLOR_RESET}\033[K"
}

log_progress_done() {
    # Complete a progress line and move to next line
    echo -e "\r${COLOR_BOLD_GREEN}✓${COLOR_RESET} ${COLOR_GREEN}$1${COLOR_RESET}\033[K"
}

clear_line() {
    echo -ne "\r\033[K"
}

# Function to show live download stats (updates in place)
show_live_stats() {
    local duration=$1
    local url=$2
    local elapsed=0
    local start_time=$(date +%s)

    while [ $elapsed -lt $duration ]; do
        local current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        local remaining=$((duration - elapsed))

        # Calculate session stats
        local session_duration=$((current_time - SESSION_START))
        local avg_speed=0
        if [ "$session_duration" -gt 0 ]; then
            avg_speed=$((TOTAL_BYTES / session_duration / 1024))
        fi

        # Progress bar
        local progress=$((elapsed * 100 / duration))
        local bar_width=30
        local filled=$((progress * bar_width / 100))
        local empty=$((bar_width - filled))
        local bar=$(printf "%${filled}s" | tr ' ' '█')$(printf "%${empty}s" | tr ' ' '░')

        # Update line in place - single line with all info
        echo -ne "\r${COLOR_CYAN}📥${COLOR_RESET} "
        echo -ne "${COLOR_BOLD}[${bar}]${COLOR_RESET} ${progress}% | "
        echo -ne "${COLOR_YELLOW}${remaining}s${COLOR_RESET} | "
        echo -ne "${COLOR_GREEN}周期:${DOWNLOAD_CYCLES}${COLOR_RESET} | "
        echo -ne "${COLOR_MAGENTA}流量:$(format_bytes $TOTAL_BYTES)${COLOR_RESET} | "
        echo -ne "${COLOR_CYAN}速度:${avg_speed}KB/s${COLOR_RESET} | "
        echo -ne "${COLOR_DIM}#${CURRENT_URL_INDEX}/${TOTAL_URLS}${COLOR_RESET}\033[K"

        sleep 1
    done

    # Clear the progress line
    echo -ne "\r\033[K"
}

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
TOP_URLS_COUNT=${top_urls:-0}  # Number of fastest URLs to keep (default 0 = no limit, keep all qualifying URLs)
MAX_DISPLAY_URLS=${max_display_urls:-10}  # Maximum number of URLs to display in list (default 10, 0 = show all)

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

log_section "🚀 Network Download Traffic Generator"
echo ""
log_info "Configuration"
echo -e "  ${COLOR_CYAN}Tool:${COLOR_RESET}              ${COLOR_BOLD}$TOOL${COLOR_RESET}"
echo -e "  ${COLOR_CYAN}Threads:${COLOR_RESET}           ${COLOR_BOLD}$THREADS${COLOR_RESET}"
echo -e "  ${COLOR_CYAN}Duration:${COLOR_RESET}          ${COLOR_BOLD}$DURATION${COLOR_RESET}"
echo -e "  ${COLOR_CYAN}Available URLs:${COLOR_RESET}    ${COLOR_BOLD}$URL_COUNT${COLOR_RESET}"
echo ""
log_info "Speed Thresholds"
echo -e "  ${COLOR_CYAN}Min Speed:${COLOR_RESET}         ${COLOR_BOLD}${MIN_SPEED} KB/s${COLOR_RESET}"
echo -e "  ${COLOR_CYAN}Min Benchmark:${COLOR_RESET}     ${COLOR_BOLD}${MIN_BENCHMARK_SPEED} KB/s${COLOR_RESET}"
if [ "$TOP_URLS_COUNT" -eq 0 ]; then
    echo -e "  ${COLOR_CYAN}Top URLs:${COLOR_RESET}          ${COLOR_BOLD}不限制${COLOR_RESET} ${COLOR_DIM}(保留所有符合条件的节点)${COLOR_RESET}"
else
    echo -e "  ${COLOR_CYAN}Top URLs:${COLOR_RESET}          ${COLOR_BOLD}${TOP_URLS_COUNT}${COLOR_RESET}"
fi
echo -e "  ${COLOR_CYAN}Check Interval:${COLOR_RESET}    ${COLOR_BOLD}${CHECK_INTERVAL}s${COLOR_RESET} ${COLOR_DIM}(every $((CHECK_INTERVAL / 60)) min)${COLOR_RESET}"
echo -e "  ${COLOR_CYAN}Slow Threshold:${COLOR_RESET}    ${COLOR_BOLD}${SLOW_THRESHOLD}${COLOR_RESET} ${COLOR_DIM}(immediate if 1)${COLOR_RESET}"
echo -e "  ${COLOR_CYAN}Concurrent Tests:${COLOR_RESET}  ${COLOR_BOLD}${BENCHMARK_CONCURRENT}${COLOR_RESET}"
if [ "$MAX_DISPLAY_URLS" -eq 0 ]; then
    echo -e "  ${COLOR_CYAN}Max Display:${COLOR_RESET}       ${COLOR_BOLD}不限制${COLOR_RESET} ${COLOR_DIM}(显示所有节点)${COLOR_RESET}"
else
    echo -e "  ${COLOR_CYAN}Max Display:${COLOR_RESET}       ${COLOR_BOLD}${MAX_DISPLAY_URLS}${COLOR_RESET} ${COLOR_DIM}个节点${COLOR_RESET}"
fi
echo ""
if [ -n "$BANDWIDTH_LIMIT_DOWNLOAD" ] || [ -n "$BANDWIDTH_LIMIT_UPLOAD" ]; then
    if [ "$TRICKLE_AVAILABLE" = true ]; then
        log_info "Bandwidth Limiting: ${COLOR_BOLD_GREEN}Enabled${COLOR_RESET} (via trickle)"
        [ -n "$BANDWIDTH_LIMIT_DOWNLOAD" ] && echo -e "  ${COLOR_CYAN}Download Limit:${COLOR_RESET}   ${COLOR_BOLD}${BANDWIDTH_LIMIT_DOWNLOAD} KB/s${COLOR_RESET}"
        [ -n "$BANDWIDTH_LIMIT_UPLOAD" ] && echo -e "  ${COLOR_CYAN}Upload Limit:${COLOR_RESET}     ${COLOR_BOLD}${BANDWIDTH_LIMIT_UPLOAD} KB/s${COLOR_RESET}"
    else
        log_warning "Bandwidth Limiting: UNAVAILABLE (trickle not installed)"
        log_dim "  Note: Bandwidth limiting is only available in the Debian version"
        log_dim "  Requested limits will be ignored: download=${BANDWIDTH_LIMIT_DOWNLOAD:-none} KB/s, upload=${BANDWIDTH_LIMIT_UPLOAD:-none} KB/s"
    fi
else
    log_info "Bandwidth Limiting: ${COLOR_DIM}Disabled${COLOR_RESET}"
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

# Function to display traffic statistics (dynamic, in-place update)
show_stats() {
    local current_time=$(date +%s)
    local session_duration=$((current_time - SESSION_START))
    local avg_speed=0

    if [ "$session_duration" -gt 0 ]; then
        avg_speed=$((TOTAL_BYTES / session_duration / 1024))  # KB/s
    fi

    local short_url="${CURRENT_URL:0:40}"
    [ ${#CURRENT_URL} -gt 40 ] && short_url="${short_url}..."

    # Single line dynamic update
    echo -ne "\r${COLOR_CYAN}📊${COLOR_RESET} "
    echo -ne "${COLOR_BOLD}周期:${DOWNLOAD_CYCLES}${COLOR_RESET} | "
    echo -ne "${COLOR_GREEN}流量:$(format_bytes $TOTAL_BYTES)${COLOR_RESET} | "
    echo -ne "${COLOR_YELLOW}时长:$(format_duration $session_duration)${COLOR_RESET} | "
    echo -ne "${COLOR_MAGENTA}速度:${avg_speed}KB/s${COLOR_RESET} | "
    echo -ne "${COLOR_CYAN}节点:#${CURRENT_URL_INDEX}/${TOTAL_URLS}${COLOR_RESET}"
    echo -ne "\033[K"
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
    log_warning "速度过慢，重新测速所有节点..."

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

    # Calculate average speed from all tested URLs
    local avg_speed=0
    local total_speed=0
    local valid_count=0

    while IFS= read -r line; do
        local speed=$(echo "$line" | awk '{print $1}')
        if [ -n "$speed" ] && [ "$speed" -gt 0 ]; then
            total_speed=$((total_speed + speed))
            valid_count=$((valid_count + 1))
        fi
    done < "$TEMP_FILE"

    if [ "$valid_count" -gt 0 ]; then
        avg_speed=$((total_speed / valid_count))
    fi

    # Sort by speed (descending) and filter URLs
    # Filter 1: speed >= MIN_BENCHMARK_SPEED
    # Filter 2: speed >= average speed
    # Filter 3: limit to TOP_URLS_COUNT (if > 0)
    if [ "$TOP_URLS_COUNT" -eq 0 ]; then
        # No limit, keep all qualifying URLs
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk -v min_speed="$MIN_BENCHMARK_SPEED" -v avg_speed="$avg_speed" '
            $1 >= min_speed && $1 >= avg_speed {
                print $2
            }
        ')
    else
        # Limit to TOP_URLS_COUNT
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk -v min_speed="$MIN_BENCHMARK_SPEED" -v avg_speed="$avg_speed" -v max_count="$TOP_URLS_COUNT" '
            $1 >= min_speed && $1 >= avg_speed && count < max_count {
                print $2
                count++
            }
        ')
    fi

    # Count filtered URLs
    local FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c .)

    if [ "$FILTERED_COUNT" -eq 0 ]; then
        log_warning "没有找到同时满足以下条件的节点："
        log_dim "  1. 速度 ≥ ${MIN_BENCHMARK_SPEED} KB/s"
        log_dim "  2. 速度 ≥ 平均速度 (${avg_speed} KB/s)"
        log_dim "  → 降低筛选条件，使用速度最快的节点"

        # Fallback: use top N fastest URLs regardless of speed
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}' | head -n "$TOP_URLS_COUNT")
        FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c . || echo "1")
    fi

    # Show filtered results
    log_success "测速完成，保留 ${FILTERED_COUNT} 个最快节点"
    log_dim "  平均速度: ${avg_speed} KB/s | 过滤阈值: max(${MIN_BENCHMARK_SPEED}, ${avg_speed}) KB/s"
    echo ""
    local index=1
    local displayed=0
    for url in $SORTED_URLS; do
        # Limit display count if MAX_DISPLAY_URLS > 0
        if [ "$MAX_DISPLAY_URLS" -gt 0 ] && [ "$displayed" -ge "$MAX_DISPLAY_URLS" ]; then
            local remaining=$((FILTERED_COUNT - displayed))
            if [ "$remaining" -gt 0 ]; then
                log_dim "  ... 还有 ${remaining} 个节点未显示 (设置 max_display_urls=0 显示全部)"
            fi
            break
        fi

        # Get speed from temp file before deletion
        speed=$(grep -F "$url" "$TEMP_FILE" | head -1 | awk '{print $1}')
        local short_url="${url:0:45}"
        [ ${#url} -gt 45 ] && short_url="${short_url}..."

        # Color code based on speed
        local speed_color="${COLOR_GREEN}"
        if [ "$speed" -lt "$MIN_BENCHMARK_SPEED" ]; then
            speed_color="${COLOR_YELLOW}"
        fi
        if [ "$speed" -lt "$MIN_SPEED" ]; then
            speed_color="${COLOR_RED}"
        fi

        # Show speed relative to average
        local speed_indicator=""
        if [ "$speed" -ge $((avg_speed * 2)) ]; then
            speed_indicator="${COLOR_GREEN}⚡${COLOR_RESET}"
        elif [ "$speed" -ge $((avg_speed * 3 / 2)) ]; then
            speed_indicator="${COLOR_GREEN}↑${COLOR_RESET}"
        elif [ "$speed" -ge "$avg_speed" ]; then
            speed_indicator="${COLOR_CYAN}→${COLOR_RESET}"
        fi

        printf "  ${COLOR_BOLD}#%d${COLOR_RESET} ${speed_color}%-8s KB/s${COLOR_RESET} %s ${COLOR_DIM}%s${COLOR_RESET}\n" "$index" "$speed" "$speed_indicator" "$short_url"
        index=$((index + 1))
        displayed=$((displayed + 1))
    done
    echo ""

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
            log_error "Unknown tool: $TOOL"
            rm -f "$output_file"
            exit 1
            ;;
    esac

    # Show live progress while download is running
    show_live_stats "$CHECK_INTERVAL" "$url" &
    local progress_pid=$!

    # Wait for the download to complete
    wait $pid
    local exit_code=$?

    # Stop the progress display
    kill $progress_pid 2>/dev/null
    wait $progress_pid 2>/dev/null
    clear_line

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

    # Speed check is silent, just update internal counters
    local current_speed=$(benchmark_url "$url")

    if [ "$current_speed" -lt "$MIN_SPEED" ]; then
        SLOW_COUNT=$((SLOW_COUNT + 1))

        if [ "$SLOW_COUNT" -ge "$SLOW_THRESHOLD" ]; then
            # Count remaining URLs in list
            local url_count=$(echo "$URL_LIST" | wc -w)

            if [ "$url_count" -gt 1 ]; then
                SLOW_COUNT=0  # Reset counter for next URL
                return 1  # Trigger URL switch to next in list
            else
                # Need to rebenchmark all URLs
                rebenchmark_urls
                return 1  # Trigger URL switch
            fi
        fi
        return 0  # Continue with current URL for now
    else
        SLOW_COUNT=0  # Reset counter if speed is good
    fi

    return 0
}

# Benchmark all URLs and sort by speed (only run once at startup, with concurrent benchmarking)
if [ -z "$SORTED_URLS" ]; then
    log_section "🔍 节点测速中..."
    echo ""
    log_info "并发测试 ${COLOR_BOLD}$URL_COUNT${COLOR_RESET} 个节点 (并发数: ${COLOR_BOLD}${BENCHMARK_CONCURRENT}${COLOR_RESET})"
    echo ""

    TEMP_FILE=$(mktemp)
    pids=()
    count=0
    tested=0

    for url in $URL_LIST; do
        tested=$((tested + 1))
        log_progress "测速进度: ${tested}/${URL_COUNT}"

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
    clear_line

    # Calculate average speed from all tested URLs
    avg_speed=0
    total_speed=0
    valid_count=0

    while IFS= read -r line; do
        speed=$(echo "$line" | awk '{print $1}')
        if [ -n "$speed" ] && [ "$speed" -gt 0 ]; then
            total_speed=$((total_speed + speed))
            valid_count=$((valid_count + 1))
        fi
    done < "$TEMP_FILE"

    if [ "$valid_count" -gt 0 ]; then
        avg_speed=$((total_speed / valid_count))
    fi

    # Sort by speed (descending) and filter URLs
    # Filter 1: speed >= MIN_BENCHMARK_SPEED
    # Filter 2: speed >= average speed
    # Filter 3: limit to TOP_URLS_COUNT (if > 0)
    if [ "$TOP_URLS_COUNT" -eq 0 ]; then
        # No limit, keep all qualifying URLs
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk -v min_speed="$MIN_BENCHMARK_SPEED" -v avg_speed="$avg_speed" '
            $1 >= min_speed && $1 >= avg_speed {
                print $2
            }
        ')
    else
        # Limit to TOP_URLS_COUNT
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk -v min_speed="$MIN_BENCHMARK_SPEED" -v avg_speed="$avg_speed" -v max_count="$TOP_URLS_COUNT" '
            $1 >= min_speed && $1 >= avg_speed && count < max_count {
                print $2
                count++
            }
        ')
    fi

    # Count filtered URLs
    FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c .)
    TOTAL_TESTED=$(wc -l < "$TEMP_FILE")

    if [ "$FILTERED_COUNT" -eq 0 ]; then
        log_warning "没有找到同时满足以下条件的节点："
        log_dim "  1. 速度 ≥ ${MIN_BENCHMARK_SPEED} KB/s"
        log_dim "  2. 速度 ≥ 平均速度 (${avg_speed} KB/s)"
        log_dim "  → 降低筛选条件，使用速度最快的节点"

        # Fallback: use top N fastest URLs regardless of thresholds
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}' | head -n "$TOP_URLS_COUNT")
        FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c . || echo "1")
    fi

    # Show filtered results
    log_success "测速完成"
    echo ""
    log_info "测速结果汇总"
    printf "  ${COLOR_CYAN}总测试节点:${COLOR_RESET}   ${COLOR_BOLD}%s 个${COLOR_RESET}\n" "$TOTAL_TESTED"
    printf "  ${COLOR_CYAN}平均速度:${COLOR_RESET}     ${COLOR_BOLD}%s KB/s${COLOR_RESET}\n" "$avg_speed"
    printf "  ${COLOR_CYAN}过滤阈值:${COLOR_RESET}     ${COLOR_BOLD}%s KB/s${COLOR_RESET} ${COLOR_DIM}(min_benchmark_speed)${COLOR_RESET}\n" "$MIN_BENCHMARK_SPEED"
    printf "  ${COLOR_CYAN}过滤后保留:${COLOR_RESET}   ${COLOR_BOLD}%s 个${COLOR_RESET} ${COLOR_DIM}(速度 ≥ max(${MIN_BENCHMARK_SPEED}, ${avg_speed}) KB/s)${COLOR_RESET}\n" "$FILTERED_COUNT"
    echo ""
    log_info "将使用的节点列表"
    echo ""
    index=1
    displayed=0
    for url in $SORTED_URLS; do
        # Limit display count if MAX_DISPLAY_URLS > 0
        if [ "$MAX_DISPLAY_URLS" -gt 0 ] && [ "$displayed" -ge "$MAX_DISPLAY_URLS" ]; then
            remaining=$((FILTERED_COUNT - displayed))
            if [ "$remaining" -gt 0 ]; then
                log_dim "  ... 还有 ${remaining} 个节点未显示 (设置 max_display_urls=0 显示全部)"
            fi
            break
        fi

        # Get speed from temp file before deletion
        speed=$(grep -F "$url" "$TEMP_FILE" | head -1 | awk '{print $1}')
        short_url="${url:0:45}"
        [ ${#url} -gt 45 ] && short_url="${short_url}..."

        # Color code based on speed
        speed_color="${COLOR_GREEN}"
        if [ "$speed" -lt "$MIN_BENCHMARK_SPEED" ]; then
            speed_color="${COLOR_YELLOW}"
        fi
        if [ "$speed" -lt "$MIN_SPEED" ]; then
            speed_color="${COLOR_RED}"
        fi

        # Show speed relative to average
        speed_indicator=""
        if [ "$speed" -ge $((avg_speed * 2)) ]; then
            speed_indicator="${COLOR_GREEN}⚡${COLOR_RESET}"  # Much faster than average
        elif [ "$speed" -ge $((avg_speed * 3 / 2)) ]; then
            speed_indicator="${COLOR_GREEN}↑${COLOR_RESET}"  # Faster than average
        elif [ "$speed" -ge "$avg_speed" ]; then
            speed_indicator="${COLOR_CYAN}→${COLOR_RESET}"  # Around average
        fi

        printf "  ${COLOR_BOLD}#%d${COLOR_RESET} ${speed_color}%-8s KB/s${COLOR_RESET} %s ${COLOR_DIM}%s${COLOR_RESET}\n" "$index" "$speed" "$speed_indicator" "$short_url"
        index=$((index + 1))
        displayed=$((displayed + 1))
    done
    echo ""

    # Clean up temp file after displaying results
    rm -f "$TEMP_FILE"

    # Use sorted URLs
    URL_LIST="$SORTED_URLS"
fi

# Main loop: use fastest URLs, only switch when speed degrades or download fails
# Main loop: use fastest URLs, only switch when speed degrades or download fails
# Initialize URL index
CURRENT_URL_INDEX=1
URL_ARRAY=($URL_LIST)  # Convert to array for indexed access
TOTAL_URLS=${#URL_ARRAY[@]}

log_section "🚀 开始下载流量"
echo ""

while true; do
    # Handle custom URL if provided
    if [ -n "$url_custom" ]; then
        CURRENT_URL="$url_custom"

        if run_download "$url_custom"; then
            # Check speed silently
            check_current_speed "$url_custom" >/dev/null 2>&1
        else
            # Download failed, wait and retry
            sleep 3
        fi
        continue
    fi

    # Get current URL from array (bash arrays are 0-indexed)
    url="${URL_ARRAY[$((CURRENT_URL_INDEX - 1))]}"

    if [ -z "$url" ]; then
        # URL list is empty, rebenchmark
        rebenchmark_urls
        URL_ARRAY=($URL_LIST)
        TOTAL_URLS=${#URL_ARRAY[@]}
        CURRENT_URL_INDEX=1
        continue
    fi

    CURRENT_URL="$url"


    # Run the download for CHECK_INTERVAL seconds
    if run_download "$url"; then
        # Download cycle completed successfully
        # Check if speed is acceptable (silently)
        if ! check_current_speed "$url"; then
            # Speed is too slow, switch to next URL
            CURRENT_URL_INDEX=$((CURRENT_URL_INDEX % TOTAL_URLS + 1))

            # If we've cycled back to first URL, rebenchmark
            if [ "$CURRENT_URL_INDEX" -eq 1 ]; then
                rebenchmark_urls
                URL_ARRAY=($URL_LIST)
                TOTAL_URLS=${#URL_ARRAY[@]}
            fi
        fi
    else
        # Download failed, try next URL
        CURRENT_URL_INDEX=$((CURRENT_URL_INDEX % TOTAL_URLS + 1))
        sleep 3
    fi
done
