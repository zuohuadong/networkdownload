#!/bin/sh
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
SLOW_THRESHOLD=3  # Number of consecutive slow detections before re-benchmarking (3 times = ~15 minutes)
SLOW_COUNT=0  # Counter for consecutive slow speed detections
BENCHMARK_SIZE=5242880  # 5MB for quick speed check (reduced from 10MB)

echo "Network Download Traffic Generator"
echo "===================================="
echo "Tool: $TOOL"
echo "Threads: $THREADS"
echo "Duration: $DURATION"
echo "Available URLs: $URL_COUNT"
echo "Min Speed Threshold: ${MIN_SPEED} KB/s"
echo "Speed Check Interval: ${CHECK_INTERVAL}s (every $((CHECK_INTERVAL / 60)) minutes)"
echo "Slow Detection Threshold: ${SLOW_THRESHOLD} consecutive times"
echo ""

# Function to test if a URL is accessible
test_url() {
    local url=$1
    echo "Testing: $url"
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

# Function to re-benchmark and re-sort all URLs
rebenchmark_urls() {
    echo ""
    echo "=========================================="
    echo "Speed too slow! Re-benchmarking all URLs..."
    echo "=========================================="

    TEMP_FILE=$(mktemp)

    for url in $URL_LIST; do
        echo "Testing: $url"

        # Check if URL is accessible
        if test_url "$url" >/dev/null 2>&1; then
            # Measure download speed
            speed=$(benchmark_url "$url")
            echo "  Speed: ${speed} KB/s"
            echo "${speed} ${url}" >> "$TEMP_FILE"
        else
            echo "  Not accessible, skipping..."
        fi
    done

    echo ""
    echo "Re-sorting URLs by speed..."

    # Sort by speed (descending) and extract URLs
    SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}')
    rm -f "$TEMP_FILE"

    # Show sorted results
    echo "Updated URL priority order:"
    local index=1
    for url in $SORTED_URLS; do
        echo "  $index. $url"
        index=$((index + 1))
    done
    echo ""

    # Update URL list
    URL_LIST="$SORTED_URLS"
    SLOW_COUNT=0  # Reset slow count
}

# Function to run download with current tool (runs for CHECK_INTERVAL seconds, then returns)
run_download() {
    local url=$1
    local output_file=$(mktemp)

    case "$TOOL" in
        oha)
            # Run for CHECK_INTERVAL seconds - continuous download during this period
            /bin/oha -z "${CHECK_INTERVAL}sec" -c "$THREADS" "$url" $UI_FLAG > "$output_file" 2>&1 &
            local pid=$!
            ;;
        autocannon)
            autocannon $UI_FLAG -c "$THREADS" -d $CHECK_INTERVAL "$url" > "$output_file" 2>&1 &
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

    echo "Checking current speed for: $url"
    local current_speed=$(benchmark_url "$url")
    echo "Current speed: ${current_speed} KB/s (threshold: ${MIN_SPEED} KB/s)"

    if [ "$current_speed" -lt "$MIN_SPEED" ]; then
        SLOW_COUNT=$((SLOW_COUNT + 1))
        echo "⚠️  Speed below threshold! (${SLOW_COUNT}/${SLOW_THRESHOLD})"

        if [ "$SLOW_COUNT" -ge "$SLOW_THRESHOLD" ]; then
            echo "Speed has been slow for $((SLOW_THRESHOLD * CHECK_INTERVAL / 60)) minutes. Triggering re-benchmark..."
            rebenchmark_urls
            return 1  # Trigger URL switch
        else
            echo "Will re-benchmark if speed remains slow for $((SLOW_THRESHOLD - SLOW_COUNT)) more check(s)"
        fi
    else
        if [ "$SLOW_COUNT" -gt 0 ]; then
            echo "Speed recovered. Resetting slow count from $SLOW_COUNT to 0."
        fi
        SLOW_COUNT=0  # Reset counter if speed is good
        echo "✓ Speed is acceptable"
    fi

    return 0
}

# Benchmark all URLs and sort by speed (only run once at startup)
if [ -z "$SORTED_URLS" ]; then
    echo "Benchmarking URLs to find the fastest..."
    echo "========================================"

    TEMP_FILE=$(mktemp)

    for url in $URL_LIST; do
        echo "Testing: $url"

        # First check if URL is accessible
        if test_url "$url" >/dev/null 2>&1; then
            # Measure download speed
            speed=$(benchmark_url "$url")
            echo "  Speed: ${speed} KB/s"
            echo "${speed} ${url}" >> "$TEMP_FILE"
        else
            echo "  Not accessible, skipping..."
        fi
    done

    echo ""
    echo "Sorting URLs by speed (fastest first)..."
    echo "========================================"

    # Sort by speed (descending) and extract URLs
    SORTED_URLS=$(sort -rn "$TEMP_FILE" | awk '{print $2}')
    rm -f "$TEMP_FILE"

    # Show sorted results
    echo "URL priority order:"
    local index=1
    for url in $SORTED_URLS; do
        echo "  $index. $url"
        index=$((index + 1))
    done
    echo ""

    # Use sorted URLs
    URL_LIST="$SORTED_URLS"
fi

# Main loop: try URLs in order, monitor speed periodically, and retry on failure
while true; do
    for url in $URL_LIST; do
        # Skip custom URL check if user provided one
        if [ -n "$url_custom" ]; then
            echo "Using custom URL: $url_custom"
            run_download "$url_custom"

            # Check speed after download cycle (every CHECK_INTERVAL seconds)
            if ! check_current_speed "$url_custom"; then
                echo "Switching to faster URL..."
                break
            fi

            continue 2  # Continue outer while loop
        fi

        # URLs are already tested and sorted, use directly
        echo "Starting download from: $url"
        echo "-----------------------------------"

        # Run the download for CHECK_INTERVAL seconds (continuous downloading)
        if run_download "$url"; then
            # Download cycle completed, check if speed is acceptable
            echo ""
            echo "Download cycle completed. Checking speed..."

            if ! check_current_speed "$url"; then
                # Speed has been slow for too long, rebenchmark was triggered
                echo "Switching to newly identified fastest URL..."
                break  # Break to use the re-sorted URL list
            fi

            # Speed is good or hasn't been slow long enough, continue with same URL
            echo "Continuing with current URL..."
        else
            # Download failed - try next URL
            echo "Download failed with exit code $?. Trying next URL..."
            sleep 3
            break
        fi
    done

    # Small delay before next iteration
    sleep 1
done
