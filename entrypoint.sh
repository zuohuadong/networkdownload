#!/bin/sh
# Network download traffic generator with multiple fallback URLs

# Stable large file URLs (100MB+ each)
URLS="
https://speed.cloudflare.com/__down?bytes=100000000
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
THREADS=${th:-2}
DURATION=${time:-2147483647sec}
UI_FLAG=${ui:---no-tui}
TOOL=${tool:-oha}

echo "Network Download Traffic Generator"
echo "===================================="
echo "Tool: $TOOL"
echo "Threads: $THREADS"
echo "Duration: $DURATION"
echo "Available URLs: $URL_COUNT"
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

# Function to run download with current tool
run_download() {
    local url=$1

    case "$TOOL" in
        oha)
            /bin/oha -z "$DURATION" -c "$THREADS" "$url" $UI_FLAG
            ;;
        autocannon)
            autocannon $UI_FLAG -c "$THREADS" -f "$url"
            ;;
        *)
            echo "Unknown tool: $TOOL"
            exit 1
            ;;
    esac

    return $?
}

# Main loop: try URLs in order, retry on failure
while true; do
    for url in $URL_LIST; do
        # Skip custom URL check if user provided one
        if [ -n "$url_custom" ]; then
            echo "Using custom URL: $url_custom"
            run_download "$url_custom"
            sleep 5
            continue 2  # Continue outer while loop
        fi

        # Test URL first (skip if no curl/wget available)
        if test_url "$url"; then
            echo "Starting download from: $url"
            echo "-----------------------------------"

            # Run the download
            if run_download "$url"; then
                # Success - restart with same URL
                echo "Download completed successfully. Restarting..."
                sleep 2
            else
                # Failed - try next URL
                echo "Download failed with exit code $?. Trying next URL..."
                sleep 3
                break
            fi
        else
            echo "URL not accessible, trying next..."
            sleep 1
        fi
    done

    # If we exhausted all URLs, wait a bit before retrying
    echo "All URLs attempted. Waiting 30 seconds before retry..."
    sleep 30
done
