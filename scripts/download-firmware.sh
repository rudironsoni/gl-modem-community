#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

mkdir -p "$ANALYSIS_DIR/hashes" "$ANALYSIS_DIR/reports"
tmp="$FIRMWARE_PATH.partial"
headers="$ANALYSIS_DIR/reports/firmware-http-headers.txt"

curl --fail --location --retry 2 --connect-timeout 20 \
    --user-agent 'Mozilla/5.0 mt3000-gl-modem-research/1.0' \
    --dump-header "$headers" --output "$tmp" "$FIRMWARE_URL"
mv "$tmp" "$FIRMWARE_PATH"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$ANALYSIS_DIR/reports/firmware-retrieved-utc.txt"
printf '%s\n' "$FIRMWARE_URL" > "$ANALYSIS_DIR/reports/firmware-url.txt"

