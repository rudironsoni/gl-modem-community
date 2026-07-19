#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

test -f "$FIRMWARE_PATH"
mkdir -p "$ANALYSIS_DIR/hashes" "$ANALYSIS_DIR/reports"

wc -c < "$FIRMWARE_PATH" | tr -d ' ' > "$ANALYSIS_DIR/hashes/firmware.size"
shasum -a 256 "$FIRMWARE_PATH" > "$ANALYSIS_DIR/hashes/firmware.sha256"
shasum -a 512 "$FIRMWARE_PATH" > "$ANALYSIS_DIR/hashes/firmware.sha512"
in_container sh -c 'b2sum /repo/firmware/'"$FIRMWARE_NAME"' > /repo/analysis/hashes/firmware.blake2b512'
file "$FIRMWARE_PATH" > "$ANALYSIS_DIR/reports/firmware-file.txt"

