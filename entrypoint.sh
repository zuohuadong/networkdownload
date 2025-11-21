#!/bin/bash
# Network download traffic generator with multiple fallback URLs

# Set UTF-8 locale to support Unicode characters and emojis
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# URL 自动更新配置
URL_UPDATE_INTERVAL_DAYS=${url_update_interval:-7}  # 默认 7 天更新一次
URL_UPDATE_ENABLED=${url_update_enabled:-true}      # 默认启用自动更新

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
    [ "$SILENT_MODE" = true ] && return
    echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} ${COLOR_BOLD}$1${COLOR_RESET}"
}

log_success() {
    [ "$SILENT_MODE" = true ] && return
    echo -e "${COLOR_BOLD_GREEN}✓${COLOR_RESET} ${COLOR_GREEN}$1${COLOR_RESET}"
}

log_warning() {
    [ "$SILENT_MODE" = true ] && return
    echo -e "${COLOR_BOLD_YELLOW}⚠${COLOR_RESET} ${COLOR_YELLOW}$1${COLOR_RESET}"
}

log_error() {
    [ "$SILENT_MODE" = true ] && return
    echo -e "${COLOR_BOLD_RED}✗${COLOR_RESET} ${COLOR_RED}$1${COLOR_RESET}"
}

log_section() {
    [ "$SILENT_MODE" = true ] && return
    echo ""
    echo -e "${COLOR_BOLD_CYAN}$1${COLOR_RESET}"
    echo -e "${COLOR_GRAY}$(printf '%.0s─' {1..60})${COLOR_RESET}"
}

log_dim() {
    [ "$SILENT_MODE" = true ] && return
    echo -e "${COLOR_DIM}$1${COLOR_RESET}"
}

get_timestamp() {
    date '+%H:%M:%S'
}

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

# Dynamic logging functions for in-place updates
log_progress() {
    [ "$SILENT_MODE" = true ] && return
    # Print progress message that can be updated in place
    # Usage: log_progress "message"
    printf "\r%b %b%b\033[K" "${COLOR_BLUE}⏳${COLOR_RESET}" "${COLOR_BOLD}" "$1${COLOR_RESET}"
}

log_progress_done() {
    [ "$SILENT_MODE" = true ] && return
    # Complete a progress line and move to next line
    printf "\r%b %b%b\033[K\n" "${COLOR_BOLD_GREEN}✓${COLOR_RESET}" "${COLOR_GREEN}" "$1${COLOR_RESET}"
}

clear_line() {
    [ "$SILENT_MODE" = true ] && return
    printf "\r\033[K"
}

# Function to show live download stats (updates in place)
show_live_stats() {
    [ "$SILENT_MODE" = true ] && {
        # In silent mode, just sleep for the duration
        sleep "$1"
        return
    }

    local duration=$1
    local url=$2
    local elapsed=0
    local start_time=$(date +%s)
    local first_display=true

    # Variables for real-time speed calculation
    local last_bytes=$(get_network_bytes "$NETWORK_INTERFACE")
    local last_time=$start_time
    local realtime_speed=0
    local speed_samples=()  # Array to store recent speed samples for smoothing
    local max_samples=3     # Keep last 3 samples for smoothing

    while [ $elapsed -lt $duration ]; do
        local current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        local remaining=$((duration - elapsed))

        # Get current network traffic from system
        local current_bytes=$(get_network_bytes "$NETWORK_INTERFACE")
        local total_traffic=$((current_bytes - BASELINE_BYTES))
        local cycle_traffic=$((current_bytes - CYCLE_START_BYTES))

        # Calculate real-time speed (bytes downloaded in the last second)
        local time_diff=$((current_time - last_time))
        if [ "$time_diff" -gt 0 ]; then
            local bytes_diff=$((current_bytes - last_bytes))
            local instant_speed=$((bytes_diff / time_diff / 1024))  # KB/s

            # Add to samples array for smoothing
            speed_samples+=($instant_speed)

            # Keep only the last max_samples
            if [ ${#speed_samples[@]} -gt $max_samples ]; then
                speed_samples=("${speed_samples[@]:1}")
            fi

            # Calculate average of samples for smoother display
            local sum=0
            for speed in "${speed_samples[@]}"; do
                sum=$((sum + speed))
            done
            realtime_speed=$((sum / ${#speed_samples[@]}))

            last_bytes=$current_bytes
            last_time=$current_time
        fi

        # Calculate session stats
        local session_duration=$((current_time - SESSION_START))
        local avg_speed=0
        if [ "$session_duration" -gt 0 ] && [ "$total_traffic" -gt 0 ]; then
            avg_speed=$((total_traffic / session_duration / 1024))
        fi

        # Calculate total bytes including historical data
        local total_with_history=$((TOTAL_HISTORICAL_BYTES + total_traffic))
        local month_with_current=$((MONTH_BYTES + total_traffic))

        # For first display, print 3 lines to reserve space
        if [ "$first_display" = true ]; then
            printf "\n\n\n"
            first_display=false
        fi

        # Multi-line display with better organization
        # Move cursor up 3 lines, then update each line
        printf "\033[3A"

        # Line 1: Header
        printf "\r\033[2K${COLOR_BOLD_CYAN}[下载中]${COLOR_RESET}\n"

        # Line 2: Traffic Statistics
        printf "\r\033[2K  ${COLOR_BOLD}流量统计${COLOR_RESET} ${COLOR_GRAY}→${COLOR_RESET} "
        printf "${COLOR_DIM}历史:${COLOR_RESET}${COLOR_GREEN}$(format_bytes $total_with_history)${COLOR_RESET} ${COLOR_GRAY}|${COLOR_RESET} "
        printf "${COLOR_DIM}本月:${COLOR_RESET}${COLOR_CYAN}$(format_bytes $month_with_current)${COLOR_RESET} ${COLOR_GRAY}|${COLOR_RESET} "
        printf "${COLOR_DIM}本周期:${COLOR_RESET}${COLOR_YELLOW}$(format_bytes $cycle_traffic)${COLOR_RESET}\n"

        # Line 3: Speed and Status
        printf "\r\033[2K  ${COLOR_BOLD}运行状态${COLOR_RESET} ${COLOR_GRAY}→${COLOR_RESET} "
        printf "${COLOR_DIM}周期:${COLOR_RESET}${COLOR_BOLD_CYAN}${DOWNLOAD_CYCLES}${COLOR_RESET} ${COLOR_GRAY}|${COLOR_RESET} "
        printf "${COLOR_DIM}实时:${COLOR_RESET}${COLOR_BOLD_YELLOW}${realtime_speed}KB/s${COLOR_RESET} ${COLOR_GRAY}|${COLOR_RESET} "
        printf "${COLOR_DIM}平均:${COLOR_RESET}${COLOR_MAGENTA}${avg_speed}KB/s${COLOR_RESET} ${COLOR_GRAY}|${COLOR_RESET} "
        printf "${COLOR_DIM}倒计时:${COLOR_RESET}${COLOR_YELLOW}${remaining}s${COLOR_RESET} ${COLOR_GRAY}|${COLOR_RESET} "
        printf "${COLOR_DIM}节点:${COLOR_RESET}${COLOR_DIM}#${CURRENT_URL_INDEX}/${TOTAL_URLS}${COLOR_RESET}"

        sleep 1
    done

    # Clear the 3 lines
    printf "\033[3A\r\033[2K\n\033[2K\n\033[2K"
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

# Fetch external URLs on first startup if file doesn't exist
EXTERNAL_URL_FILE="/app/urls/external_urls.txt"
FETCH_SCRIPT="/app/scripts/fetch_urls.sh"

if [ ! -f "$EXTERNAL_URL_FILE" ]; then
    if [ -f "$FETCH_SCRIPT" ]; then
        [ "$SILENT_MODE" != true ] && log_info "首次启动，正在从 llxhq 获取最新测速节点..."
        cd /app
        if bash "$FETCH_SCRIPT" 2>/dev/null; then
            [ "$SILENT_MODE" != true ] && log_success "成功获取测速节点列表"
        else
            [ "$SILENT_MODE" != true ] && log_warning "获取测速节点失败，将使用内置节点列表"
        fi
    else
        [ "$SILENT_MODE" != true ] && log_warning "URL 获取脚本不存在: $FETCH_SCRIPT"
    fi
fi

# Load external URLs from file if available
if [ -f "$EXTERNAL_URL_FILE" ]; then
    [ "$SILENT_MODE" != true ] && echo "Loading external URLs from $EXTERNAL_URL_FILE..."
    EXTERNAL_URLS=$(grep -v '^#' "$EXTERNAL_URL_FILE" | grep -v '^$' || true)
    if [ -n "$EXTERNAL_URLS" ]; then
        EXTERNAL_COUNT=$(echo "$EXTERNAL_URLS" | wc -l)
        [ "$SILENT_MODE" != true ] && echo "Found $EXTERNAL_COUNT external URLs from llxhq"
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

# Silent mode detection
SILENT_MODE=false
if [ "$UI_FLAG" = "silent" ] || [ "$UI_FLAG" = "--silent" ]; then
    SILENT_MODE=true
    UI_FLAG="--no-tui"  # Set default UI flag for tools
fi

# Speed monitoring settings
MIN_SPEED=${min_speed:-200}  # Minimum speed in KB/s (default 200 KB/s)
CHECK_INTERVAL=${check_interval:-300}  # Check speed every 5 minutes (default 300 seconds)
SLOW_THRESHOLD=${slow_threshold:-2}  # Number of consecutive slow detections before switching (default 2 = tolerate 1 fluctuation)
SLOW_COUNT=0  # Counter for consecutive slow speed detections
BENCHMARK_SIZE=5242880  # 5MB for quick speed check (reduced from 10MB)
BENCHMARK_CONCURRENT=${benchmark_concurrent:-5}  # Concurrent benchmark threads (default 5)
MIN_BENCHMARK_SPEED=${min_benchmark_speed:-200}  # Filter out URLs slower than this in KB/s (default 200 KB/s)
TOP_URLS_COUNT=${top_urls:-0}  # Number of fastest URLs to keep (default 0 = no limit, keep all qualifying URLs)
MAX_DISPLAY_URLS=${max_display_urls:-10}  # Maximum number of URLs to display in list (default 10, 0 = show all)

# Sliding window settings for speed smoothing
SPEED_WINDOW_SIZE=${speed_window_size:-3}  # Keep last N speed measurements (default 3)
SPEED_WINDOW_ENABLED=${speed_window_enabled:-true}  # Enable sliding window averaging (default true)
declare -A url_speed_history  # Associative array to store speed history for each URL

# Webhook notification settings
WEBHOOK_URL=${webhook_url:-}  # Webhook URL for notifications (empty = disabled)
WEBHOOK_ENABLED=${webhook_enabled:-true}  # Enable webhook notifications (default true)
WEBHOOK_MIN_INTERVAL=${webhook_min_interval:-3600}  # Minimum interval between notifications in seconds (default 1 hour)
WEBHOOK_LAST_SENT=0  # Timestamp of last webhook sent
WEBHOOK_NOTIFY_SLOW=${webhook_notify_slow:-true}  # Notify when speed is too slow (default true)
WEBHOOK_NOTIFY_NO_NODES=${webhook_notify_no_nodes:-true}  # Notify when no available nodes (default true)

# Traffic statistics variables
SESSION_START=$(date +%s)  # Session start time (会话开始时间)
DOWNLOAD_CYCLES=0  # Number of completed download cycles (下载周期数)
CYCLE_START_BYTES=0  # Bytes at the start of current cycle (当前周期开始时的字节数)

# Persistent traffic storage file
TRAFFIC_DATA_DIR="/app/data"
TRAFFIC_DATA_FILE="${TRAFFIC_DATA_DIR}/traffic_stats.txt"

# Create data directory if it doesn't exist
mkdir -p "$TRAFFIC_DATA_DIR" 2>/dev/null || true

# Initialize traffic statistics
TOTAL_HISTORICAL_BYTES=0  # Total traffic since first run (历史总流量)
MONTH_BYTES=0             # Traffic for current month (本月总流量)
CURRENT_MONTH=$(date +%Y-%m)  # Current month (YYYY-MM format)

# Load historical traffic data
load_traffic_data() {
    if [ -f "$TRAFFIC_DATA_FILE" ]; then
        # Read traffic data from file
        while IFS='=' read -r key value; do
            case "$key" in
                total_bytes)
                    TOTAL_HISTORICAL_BYTES=$value
                    ;;
                month)
                    SAVED_MONTH=$value
                    ;;
                month_bytes)
                    # Check if month has changed
                    if [ "$SAVED_MONTH" = "$CURRENT_MONTH" ]; then
                        MONTH_BYTES=$value
                    else
                        # New month, reset month bytes
                        MONTH_BYTES=0
                    fi
                    ;;
            esac
        done < "$TRAFFIC_DATA_FILE"
    fi
}

# Save traffic data to file
save_traffic_data() {
    local current_bytes=$(get_network_bytes "$NETWORK_INTERFACE")
    local session_traffic=$((current_bytes - BASELINE_BYTES))

    # Update totals
    TOTAL_HISTORICAL_BYTES=$((TOTAL_HISTORICAL_BYTES + session_traffic))
    MONTH_BYTES=$((MONTH_BYTES + session_traffic))

    # Write to file
    cat > "$TRAFFIC_DATA_FILE" <<EOF
total_bytes=$TOTAL_HISTORICAL_BYTES
month=$CURRENT_MONTH
month_bytes=$MONTH_BYTES
EOF
}

# Load existing traffic data
load_traffic_data

# Setup exit handler to save traffic data
cleanup_and_save() {
    if [ "$SILENT_MODE" != true ]; then
        echo ""
        log_info "正在保存流量统计数据..."
    fi
    save_traffic_data
    [ "$SILENT_MODE" != true ] && log_success "流量数据已保存"
    exit 0
}

# Trap signals to ensure data is saved on exit
trap cleanup_and_save EXIT INT TERM

# Get network interface name (usually eth0, could be ens33, etc.)
# Try multiple methods to get the default network interface
NETWORK_INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | sed -n 's/.*dev \([^ ]*\).*/\1/p' | head -1)
if [ -z "$NETWORK_INTERFACE" ]; then
    NETWORK_INTERFACE=$(ip route show default 2>/dev/null | sed -n 's/.*dev \([^ ]*\).*/\1/p' | head -1)
fi
if [ -z "$NETWORK_INTERFACE" ]; then
    NETWORK_INTERFACE="eth0"
fi

# Get initial network traffic baseline from /proc/net/dev
get_network_bytes() {
    local interface=$1
    # Read received bytes (2nd column) from /proc/net/dev
    awk -v iface="$interface:" '$1 == iface {print $2}' /proc/net/dev 2>/dev/null || echo "0"
}

BASELINE_BYTES=$(get_network_bytes "$NETWORK_INTERFACE")

# Bandwidth limiting settings (using trickle)
BANDWIDTH_LIMIT_DOWNLOAD=${bandwidth_limit_download:-}  # Download bandwidth limit in KB/s (empty = no limit)
BANDWIDTH_LIMIT_UPLOAD=${bandwidth_limit_upload:-}  # Upload bandwidth limit in KB/s (empty = no limit)

# Check if trickle is available
TRICKLE_AVAILABLE=false
if command -v trickle >/dev/null 2>&1; then
    TRICKLE_AVAILABLE=true
fi

if [ "$SILENT_MODE" != true ]; then
    log_section "🚀 Network Download Traffic Generator"
    echo ""
    log_info "Configuration"
    echo -e "  ${COLOR_CYAN}Tool:${COLOR_RESET}              ${COLOR_BOLD}$TOOL${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Threads:${COLOR_RESET}           ${COLOR_BOLD}$THREADS${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Duration:${COLOR_RESET}          ${COLOR_BOLD}$DURATION${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Available URLs:${COLOR_RESET}    ${COLOR_BOLD}$URL_COUNT${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Network Interface:${COLOR_RESET} ${COLOR_BOLD}${NETWORK_INTERFACE}${COLOR_RESET} ${COLOR_DIM}(监控流量统计)${COLOR_RESET}"
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
    echo -e "  ${COLOR_CYAN}Slow Threshold:${COLOR_RESET}    ${COLOR_BOLD}${SLOW_THRESHOLD}${COLOR_RESET} ${COLOR_DIM}(tolerate $((SLOW_THRESHOLD - 1)) fluctuation)${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Concurrent Tests:${COLOR_RESET}  ${COLOR_BOLD}${BENCHMARK_CONCURRENT}${COLOR_RESET}"
    if [ "$SPEED_WINDOW_ENABLED" = "true" ]; then
        echo -e "  ${COLOR_CYAN}Speed Window:${COLOR_RESET}      ${COLOR_BOLD_GREEN}Enabled${COLOR_RESET} ${COLOR_DIM}(avg of last ${SPEED_WINDOW_SIZE} measurements)${COLOR_RESET}"
    else
        echo -e "  ${COLOR_CYAN}Speed Window:${COLOR_RESET}      ${COLOR_DIM}Disabled${COLOR_RESET}"
    fi
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
    if [ -n "$WEBHOOK_URL" ] && [ "$WEBHOOK_ENABLED" = "true" ]; then
        log_info "Webhook Notifications: ${COLOR_BOLD_GREEN}Enabled${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}Webhook URL:${COLOR_RESET}      ${COLOR_DIM}${WEBHOOK_URL:0:50}...${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}Min Interval:${COLOR_RESET}     ${COLOR_BOLD}$((WEBHOOK_MIN_INTERVAL / 60)) min${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}Notify Slow Speed:${COLOR_RESET} ${COLOR_BOLD}${WEBHOOK_NOTIFY_SLOW}${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}Notify No Nodes:${COLOR_RESET}   ${COLOR_BOLD}${WEBHOOK_NOTIFY_NO_NODES}${COLOR_RESET}"
    else
        log_info "Webhook Notifications: ${COLOR_DIM}Disabled${COLOR_RESET}"
    fi
    echo ""
    log_info "Traffic Statistics"
    echo -e "  ${COLOR_CYAN}Historical Total:${COLOR_RESET} ${COLOR_BOLD}$(format_bytes $TOTAL_HISTORICAL_BYTES)${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Month Total:${COLOR_RESET}      ${COLOR_BOLD}$(format_bytes $MONTH_BYTES)${COLOR_RESET} ${COLOR_DIM}(${CURRENT_MONTH})${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Data File:${COLOR_RESET}        ${COLOR_DIM}${TRAFFIC_DATA_FILE}${COLOR_RESET}"
    echo ""
fi

# Function to format seconds to human readable duration
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Function to send webhook notification
send_webhook() {
    local title=$1
    local message=$2
    local level=${3:-warning}  # info, warning, error

    # Check if webhook is enabled and configured
    if [ -z "$WEBHOOK_URL" ] || [ "$WEBHOOK_ENABLED" != "true" ]; then
        return 0
    fi

    # Check if enough time has passed since last notification
    local current_time=$(date +%s)
    local time_since_last=$((current_time - WEBHOOK_LAST_SENT))

    if [ "$time_since_last" -lt "$WEBHOOK_MIN_INTERVAL" ]; then
        log_dim "  [Webhook] 跳过通知（距离上次通知仅 $((time_since_last / 60)) 分钟，最小间隔 $((WEBHOOK_MIN_INTERVAL / 60)) 分钟）"
        return 0
    fi

    # Get current traffic stats
    local current_bytes=$(get_network_bytes "$NETWORK_INTERFACE")
    local total_traffic=$((current_bytes - BASELINE_BYTES))
    local session_duration=$((current_time - SESSION_START))
    local avg_speed=0
    if [ "$session_duration" -gt 0 ] && [ "$total_traffic" -gt 0 ]; then
        avg_speed=$((total_traffic / session_duration / 1024))
    fi

    # Prepare JSON payload
    local hostname=$(hostname)
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Build JSON payload (compatible with common webhook formats)
    local json_payload=$(cat <<EOF
{
  "title": "${title}",
  "message": "${message}",
  "level": "${level}",
  "hostname": "${hostname}",
  "timestamp": "${timestamp}",
  "stats": {
    "total_traffic": "$(format_bytes $total_traffic)",
    "avg_speed": "${avg_speed} KB/s",
    "session_duration": "$(format_duration $session_duration)",
    "download_cycles": ${DOWNLOAD_CYCLES},
    "current_node": "${CURRENT_URL_INDEX}/${TOTAL_URLS}"
  }
}
EOF
)

    # Send webhook with curl
    if command -v curl >/dev/null 2>&1; then
        local response=$(curl -s -X POST -H "Content-Type: application/json" \
            -d "$json_payload" \
            --connect-timeout 5 --max-time 10 \
            "$WEBHOOK_URL" 2>&1)

        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_success "Webhook 通知已发送: ${title}"
            WEBHOOK_LAST_SENT=$current_time
        else
            log_warning "Webhook 发送失败 (exit code: $exit_code)"
        fi
    else
        log_warning "Webhook 发送失败: curl 命令不可用"
    fi
}

# Function to display traffic statistics (dynamic, in-place update)
show_stats() {
    [ "$SILENT_MODE" = true ] && return

    local current_time=$(date +%s)
    local session_duration=$((current_time - SESSION_START))

    # Get current network traffic from system
    local current_bytes=$(get_network_bytes "$NETWORK_INTERFACE")
    local total_traffic=$((current_bytes - BASELINE_BYTES))

    local avg_speed=0
    if [ "$session_duration" -gt 0 ] && [ "$total_traffic" -gt 0 ]; then
        avg_speed=$((total_traffic / session_duration / 1024))  # KB/s
    fi

    # Build complete output string first to avoid character truncation
    local output=""
    output+="\r${COLOR_CYAN}📊${COLOR_RESET} "
    output+="${COLOR_BOLD}周期:${DOWNLOAD_CYCLES}${COLOR_RESET} | "
    output+="${COLOR_GREEN}总流量:$(format_bytes $total_traffic)${COLOR_RESET} | "
    output+="${COLOR_YELLOW}时长:$(format_duration $session_duration)${COLOR_RESET} | "
    output+="${COLOR_MAGENTA}平均速度:${avg_speed}KB/s${COLOR_RESET} | "
    output+="${COLOR_CYAN}节点:#${CURRENT_URL_INDEX}/${TOTAL_URLS}${COLOR_RESET}"
    output+="\033[K"

    # Output everything at once using printf for better UTF-8 handling
    printf "%b" "$output"
}

# Function to test if a URL is accessible and return failure reason
test_url_with_reason() {
    local url=$1
    if command -v curl >/dev/null 2>&1; then
        curl -s --connect-timeout 5 --max-time 10 -r 0-1024 "$url" >/dev/null 2>&1
        local exit_code=$?
        case $exit_code in
            0)
                echo "success"
                return 0
                ;;
            6)
                echo "dns_error"  # 无法解析主机（可能被墙或DNS问题）
                return 1
                ;;
            7)
                echo "connection_failed"  # 服务器不可用
                return 1
                ;;
            28)
                echo "timeout"  # 连接超时
                return 1
                ;;
            35|51|60)
                echo "ssl_error"  # SSL/证书错误
                return 1
                ;;
            *)
                echo "other_error"  # 其他错误
                return 1
                ;;
        esac
    elif command -v wget >/dev/null 2>&1; then
        wget -q --timeout=5 --tries=1 --spider "$url" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "success"
            return 0
        else
            echo "connection_failed"
            return 1
        fi
    else
        # If no curl/wget, just assume success
        echo "success"
        return 0
    fi
}

# Function to test if a URL is accessible
test_url() {
    local url=$1
    test_url_with_reason "$url" >/dev/null 2>&1
    return $?
}

# Function to benchmark URL speed (download speed test)
benchmark_url() {
    local url=$1

    if ! command -v curl >/dev/null 2>&1; then
        echo "0"  # No curl, return 0 speed
        return
    fi

    # Download 5MB and measure speed using curl's built-in speed measurement
    # Use curl's -w (write-out) to get accurate speed in bytes/second
    # Increase timeout to 10 seconds to avoid premature timeout on fast connections
    local speed_bytes_per_sec=$(curl -s --connect-timeout 5 --max-time 10 -r 0-$BENCHMARK_SIZE \
        -w "%{speed_download}" -o /dev/null "$url" 2>/dev/null)

    # Check if curl succeeded and returned a valid speed
    if [ -z "$speed_bytes_per_sec" ] || [ "$speed_bytes_per_sec" = "0" ] || [ "$speed_bytes_per_sec" = "0.000" ]; then
        echo "0"
        return
    fi

    # Convert bytes/sec to KB/sec (using awk for floating point arithmetic)
    local speed_kb=$(echo "$speed_bytes_per_sec" | awk '{printf "%.0f", $1 / 1024}')

    # Ensure result is a valid number
    if [ -z "$speed_kb" ] || ! [[ "$speed_kb" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi

    echo "$speed_kb"
}

# Function to benchmark a single URL and save result to file (for concurrent execution)
benchmark_url_to_file() {
    local url=$1
    local result_file=$2
    local failed_file=$3

    # Check if URL is accessible and get failure reason
    local test_result=$(test_url_with_reason "$url")

    if [ "$test_result" = "success" ]; then
        # Measure download speed
        speed=$(benchmark_url "$url")
        echo "${speed} ${url}" >> "$result_file"
    else
        # URL is not accessible, log failure reason
        echo "${test_result}" >> "$failed_file"
    fi
}

# Function to re-benchmark and re-sort all URLs (with concurrent benchmarking)
rebenchmark_urls() {
    log_warning "速度过慢，重新测速所有节点..."

    TEMP_FILE=$(mktemp)
    FAILED_FILE=$(mktemp)
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
        benchmark_url_to_file "$url" "$TEMP_FILE" "$FAILED_FILE" &
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

        # Send webhook notification for no available nodes
        if [ "$WEBHOOK_NOTIFY_NO_NODES" = "true" ]; then
            send_webhook \
                "无可用节点警告" \
                "没有找到满足速度要求的节点 (≥ ${MIN_BENCHMARK_SPEED} KB/s 且 ≥ 平均速度 ${avg_speed} KB/s)。将使用速度最快的节点..." \
                "error"
        fi

        # Fallback: use top N fastest URLs regardless of speed
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}' | head -n "$TOP_URLS_COUNT")
        FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c . || echo "1")
    fi

    # Show filtered results
    log_success "测速完成，保留 ${FILTERED_COUNT} 个最快节点"
    echo ""

    rm -f "$TEMP_FILE" "$FAILED_FILE"

    # Update URL list
    URL_LIST="$SORTED_URLS"
    SLOW_COUNT=0  # Reset slow count
}

# Function to run download with current tool (runs for CHECK_INTERVAL seconds, then returns)
run_download() {
    local url=$1
    local output_file=$(mktemp)

    # Record cycle start bytes
    CYCLE_START_BYTES=$(get_network_bytes "$NETWORK_INTERFACE")

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

    # Increment cycle counter on successful download
    if [ "$exit_code" -eq 0 ]; then
        DOWNLOAD_CYCLES=$((DOWNLOAD_CYCLES + 1))
    fi

    # Show output if not suppressed
    if [ -z "$UI_FLAG" ] || [ "$UI_FLAG" = "" ]; then
        cat "$output_file"
    fi

    rm -f "$output_file"
    return $exit_code
}

# Sliding window functions for speed smoothing
# Update speed history for a URL
update_speed_history() {
    local url=$1
    local speed=$2

    if [ "$SPEED_WINDOW_ENABLED" != "true" ]; then
        echo "$speed"
        return
    fi

    # Get current history
    local history="${url_speed_history[$url]}"

    if [ -z "$history" ]; then
        # First measurement
        url_speed_history[$url]="$speed"
        echo "$speed"
        return
    fi

    # Add new speed to history
    local new_history="$history $speed"

    # Keep only last SPEED_WINDOW_SIZE measurements
    local trimmed_history=$(echo "$new_history" | awk -v size="$SPEED_WINDOW_SIZE" '{
        split($0, arr)
        n = split($0, arr)
        start = (n > size) ? n - size + 1 : 1
        for (i=start; i<=n; i++) {
            if (i > start) printf " "
            printf "%s", arr[i]
        }
    }')

    url_speed_history[$url]="$trimmed_history"

    # Calculate and return average
    echo "$trimmed_history" | awk '{
        sum=0
        for(i=1; i<=NF; i++) sum+=$i
        printf "%.0f", sum/NF
    }'
}

# Get average speed from history
get_average_speed() {
    local url=$1
    local history="${url_speed_history[$url]}"

    if [ -z "$history" ]; then
        echo "0"
        return
    fi

    echo "$history" | awk '{
        sum=0
        for(i=1; i<=NF; i++) sum+=$i
        printf "%.0f", sum/NF
    }'
}

# Get speed history count
get_speed_history_count() {
    local url=$1
    local history="${url_speed_history[$url]}"

    if [ -z "$history" ]; then
        echo "0"
        return
    fi

    echo "$history" | wc -w
}

# Function to check current download speed
check_current_speed() {
    local url=$1

    # Measure current speed
    local current_speed=$(benchmark_url "$url")

    # If speed measurement failed (0), try to use previous average
    if [ "$current_speed" -eq 0 ] 2>/dev/null; then
        # Get previous average if available
        local prev_avg=$(get_average_speed "$url")
        if [ "$prev_avg" -gt 0 ] 2>/dev/null; then
            log_dim "  测速暂时失败，使用之前的平均速度 (${prev_avg} KB/s)"
            current_speed=$prev_avg
        else
            # No previous data, skip this check
            log_dim "  测速失败，跳过本次检查"
            return 0
        fi
    fi

    # Update speed history and get smoothed average
    local avg_speed=$(update_speed_history "$url" "$current_speed")
    local history_count=$(get_speed_history_count "$url")

    # Ensure avg_speed is valid
    if [ -z "$avg_speed" ] || [ "$avg_speed" -eq 0 ] 2>/dev/null; then
        avg_speed=$current_speed
    fi

    # Use smoothed average if window is enabled, otherwise use current speed
    local speed_to_check="$avg_speed"

    # Optional: Log speed info for debugging (silent by default)
    if [ -n "$DEBUG_SPEED" ]; then
        log_dim "  [Speed Check] Current: ${current_speed} KB/s | Avg (${history_count}): ${avg_speed} KB/s | Threshold: ${MIN_SPEED} KB/s"
    fi

    if [ "$speed_to_check" -lt "$MIN_SPEED" ] 2>/dev/null; then
        SLOW_COUNT=$((SLOW_COUNT + 1))

        if [ "$SLOW_COUNT" -ge "$SLOW_THRESHOLD" ]; then
            # Log slow speed detection with details
            if [ "$SPEED_WINDOW_ENABLED" = "true" ]; then
                log_warning "节点速度持续过慢 (平均 ${avg_speed} KB/s < ${MIN_SPEED} KB/s，连续 ${SLOW_COUNT} 次)"
            else
                log_warning "节点速度过慢 (${current_speed} KB/s < ${MIN_SPEED} KB/s，连续 ${SLOW_COUNT} 次)"
            fi

            # Send webhook notification for slow speed
            if [ "$WEBHOOK_NOTIFY_SLOW" = "true" ]; then
                send_webhook \
                    "下载速度过慢警告" \
                    "节点速度持续低于阈值 (平均 ${avg_speed} KB/s < ${MIN_SPEED} KB/s)，已连续检测 ${SLOW_COUNT} 次。正在尝试切换节点..." \
                    "warning"
            fi

            # Count remaining URLs in list
            local url_count=$(echo "$URL_LIST" | wc -w)

            if [ "$url_count" -gt 1 ]; then
                SLOW_COUNT=0  # Reset counter for next URL
                log_info "切换到下一个节点..."
                return 1  # Trigger URL switch to next in list
            else
                # Need to rebenchmark all URLs
                rebenchmark_urls
                return 1  # Trigger URL switch
            fi
        else
            # Still counting slow detections
            if [ "$SPEED_WINDOW_ENABLED" = "true" ]; then
                log_dim "  速度偏慢 (平均 ${avg_speed} KB/s)，继续观察 [${SLOW_COUNT}/${SLOW_THRESHOLD}]"
            else
                log_dim "  速度偏慢 (${current_speed} KB/s)，继续观察 [${SLOW_COUNT}/${SLOW_THRESHOLD}]"
            fi
        fi
        return 0  # Continue with current URL for now
    else
        # Speed is good, reset counter
        if [ "$SLOW_COUNT" -gt 0 ]; then
            log_dim "  速度恢复正常 (${avg_speed} KB/s)，重置计数器"
        fi
        SLOW_COUNT=0
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
    FAILED_FILE=$(mktemp)
    pids=()
    count=0
    tested=0

    for url in $URL_LIST; do
        tested=$((tested + 1))
        log_progress "测速进度: ${tested}/${URL_COUNT}"

        # Launch benchmark in background
        benchmark_url_to_file "$url" "$TEMP_FILE" "$FAILED_FILE" &
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
    TOTAL_TESTED=$(wc -l < "$TEMP_FILE" | tr -d '[:space:]')

    if [ "$FILTERED_COUNT" -eq 0 ]; then
        log_warning "没有找到同时满足以下条件的节点："
        log_dim "  1. 速度 ≥ ${MIN_BENCHMARK_SPEED} KB/s"
        log_dim "  2. 速度 ≥ 平均速度 (${avg_speed} KB/s)"
        log_dim "  → 降低筛选条件，使用速度最快的节点"

        # Send webhook notification for no available nodes at startup
        if [ "$WEBHOOK_NOTIFY_NO_NODES" = "true" ]; then
            send_webhook \
                "启动警告：无满足条件的节点" \
                "初始测速完成，但没有找到满足速度要求的节点 (≥ ${MIN_BENCHMARK_SPEED} KB/s 且 ≥ 平均速度 ${avg_speed} KB/s)。将使用速度最快的节点..." \
                "warning"
        fi

        # Fallback: use top N fastest URLs regardless of thresholds
        SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}' | head -n "$TOP_URLS_COUNT")
        FILTERED_COUNT=$(echo "$SORTED_URLS" | grep -c . || echo "1")
    fi

    # Show filtered results
    log_success "测速完成"
    echo ""
    log_info "测速结果汇总"

    # Calculate failure statistics
    dns_errors=0
    connection_failures=0
    timeouts=0
    ssl_errors=0
    other_errors=0
    success_count="${TOTAL_TESTED:-0}"

    # Ensure success_count is a valid number
    if [ -z "$success_count" ] || ! [[ "$success_count" =~ ^[0-9]+$ ]]; then
        success_count="0"
    fi

    if [ -f "$FAILED_FILE" ] && [ -s "$FAILED_FILE" ]; then
        dns_errors=$(grep -c "dns_error" "$FAILED_FILE" 2>/dev/null || echo "0")
        connection_failures=$(grep -c "connection_failed" "$FAILED_FILE" 2>/dev/null || echo "0")
        timeouts=$(grep -c "timeout" "$FAILED_FILE" 2>/dev/null || echo "0")
        ssl_errors=$(grep -c "ssl_error" "$FAILED_FILE" 2>/dev/null || echo "0")
        other_errors=$(grep -c "other_error" "$FAILED_FILE" 2>/dev/null || echo "0")
    fi

    # Remove any whitespace from numbers
    dns_errors=$(echo "$dns_errors" | tr -d '[:space:]')
    connection_failures=$(echo "$connection_failures" | tr -d '[:space:]')
    timeouts=$(echo "$timeouts" | tr -d '[:space:]')
    ssl_errors=$(echo "$ssl_errors" | tr -d '[:space:]')
    other_errors=$(echo "$other_errors" | tr -d '[:space:]')
    success_count=$(echo "$success_count" | tr -d '[:space:]')

    # Ensure all variables are valid numbers
    [ -z "$dns_errors" ] && dns_errors="0"
    [ -z "$connection_failures" ] && connection_failures="0"
    [ -z "$timeouts" ] && timeouts="0"
    [ -z "$ssl_errors" ] && ssl_errors="0"
    [ -z "$other_errors" ] && other_errors="0"
    [ -z "$success_count" ] && success_count="0"

    printf "  ${COLOR_CYAN}总测试节点:${COLOR_RESET}       ${COLOR_BOLD}%s 个${COLOR_RESET}\n" "$URL_COUNT"
    printf "  ${COLOR_CYAN}测速成功:${COLOR_RESET}          ${COLOR_BOLD}%s 个${COLOR_RESET}\n" "$success_count"
    [ "$dns_errors" -gt 0 ] 2>/dev/null && printf "  ${COLOR_CYAN}DNS解析失败/被墙:${COLOR_RESET} ${COLOR_YELLOW}%s 个${COLOR_RESET}\n" "$dns_errors"
    [ "$connection_failures" -gt 0 ] 2>/dev/null && printf "  ${COLOR_CYAN}服务器不可用:${COLOR_RESET}     ${COLOR_YELLOW}%s 个${COLOR_RESET}\n" "$connection_failures"
    [ "$timeouts" -gt 0 ] 2>/dev/null && printf "  ${COLOR_CYAN}连接超时:${COLOR_RESET}         ${COLOR_YELLOW}%s 个${COLOR_RESET}\n" "$timeouts"
    [ "$ssl_errors" -gt 0 ] 2>/dev/null && printf "  ${COLOR_CYAN}SSL/证书错误:${COLOR_RESET}     ${COLOR_YELLOW}%s 个${COLOR_RESET}\n" "$ssl_errors"
    [ "$other_errors" -gt 0 ] 2>/dev/null && printf "  ${COLOR_CYAN}其他错误:${COLOR_RESET}         ${COLOR_YELLOW}%s 个${COLOR_RESET}\n" "$other_errors"
    printf "  ${COLOR_CYAN}平均速度:${COLOR_RESET}         ${COLOR_BOLD}%s KB/s${COLOR_RESET}\n" "$avg_speed"
    printf "  ${COLOR_CYAN}过滤阈值:${COLOR_RESET}         ${COLOR_BOLD}%s KB/s${COLOR_RESET} ${COLOR_DIM}(min_benchmark_speed)${COLOR_RESET}\n" "$MIN_BENCHMARK_SPEED"
    printf "  ${COLOR_CYAN}过滤后保留:${COLOR_RESET}       ${COLOR_BOLD}%s 个${COLOR_RESET} ${COLOR_DIM}(速度 ≥ max(${MIN_BENCHMARK_SPEED}, ${avg_speed}) KB/s)${COLOR_RESET}\n" "$FILTERED_COUNT"
    echo ""

    # Clean up temp files after displaying results
    rm -f "$TEMP_FILE" "$FAILED_FILE"

    # Use sorted URLs
    URL_LIST="$SORTED_URLS"
fi

# 启动后台 URL 定时更新任务
start_url_updater() {
    if [ "$URL_UPDATE_ENABLED" != "true" ]; then
        log_info "URL 自动更新已禁用 (url_update_enabled=$URL_UPDATE_ENABLED)"
        return
    fi

    local update_script="/app/scripts/update_urls_runtime.sh"
    if [ ! -f "$update_script" ]; then
        log_warning "URL 更新脚本不存在: $update_script"
        return
    fi

    log_info "启动 URL 定时更新任务 (每 ${URL_UPDATE_INTERVAL_DAYS} 天)"

    # 后台定时任务
    (
        while true; do
            # 转换天数为秒
            local sleep_seconds=$((URL_UPDATE_INTERVAL_DAYS * 86400))
            sleep "$sleep_seconds"

            # 运行更新脚本
            if bash "$update_script"; then
                log_info "URL 列表已更新，将在下次周期重新测速"
            else
                log_warning "URL 更新失败"
            fi
        done
    ) &

    URL_UPDATER_PID=$!
    log_dim "  后台更新进程 PID: $URL_UPDATER_PID"
}

# 启动 URL 更新器
start_url_updater

# Main loop: use fastest URLs, only switch when speed degrades or download fails
# Main loop: use fastest URLs, only switch when speed degrades or download fails
# Initialize URL index
CURRENT_URL_INDEX=1
URL_ARRAY=($URL_LIST)  # Convert to array for indexed access
TOTAL_URLS=${#URL_ARRAY[@]}

log_section "🚀 开始下载流量"
echo ""

while true; do
    # 检查 URL 是否已更新
    if [ -f /tmp/url_updated_flag ]; then
        rm -f /tmp/url_updated_flag
        log_section "🔄 检测到 URL 列表已更新，重新加载并测速"
        echo ""

        # 重新读取 URL 文件
        if [ -f "$EXTERNAL_URL_FILE" ]; then
            EXTERNAL_URLS=$(grep -v '^#' "$EXTERNAL_URL_FILE" | grep -v '^$' || true)
            if [ -n "$EXTERNAL_URLS" ]; then
                FULL_URL_LIST="$URLS
$EXTERNAL_URLS"
            fi
        fi

        # 重新测速所有 URL
        rebenchmark_urls

        # 更新 URL 数组
        URL_ARRAY=($URL_LIST)
        TOTAL_URLS=${#URL_ARRAY[@]}
        CURRENT_URL_INDEX=1

        log_section "🚀 继续下载流量"
        echo ""
    fi

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
