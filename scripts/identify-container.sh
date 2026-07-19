#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

test -f "$FIRMWARE_PATH"
mkdir -p "$ANALYSIS_DIR/reports" "$WORK_DIR/identify"
tar -tvf "$FIRMWARE_PATH" > "$ANALYSIS_DIR/reports/outer-tar-list.txt"
in_container sh -c 'binwalk /repo/firmware/'"$FIRMWARE_NAME"' > /repo/analysis/reports/binwalk.txt 2>&1 || true'
tar -xf "$FIRMWARE_PATH" -C "$WORK_DIR/identify"
in_container sh -c 'find /repo/work/identify -type f -exec file {} \; | sort > /repo/analysis/reports/container-files.txt'

