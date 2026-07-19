#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
FIRMWARE_URL='https://fw.gl-inet.com/firmware/mt3000-open/testing/mt3000-op-4.9.1-op25_beta1-1032-0707-1783421663.bin'
FIRMWARE_NAME='mt3000-op-4.9.1-op25_beta1-1032-0707-1783421663.bin'
FIRMWARE_DIR="$REPO_DIR/firmware"
FIRMWARE_PATH="$FIRMWARE_DIR/$FIRMWARE_NAME"
WORK_DIR="$REPO_DIR/work"
EXTRACT_DIR="$REPO_DIR/extracted"
ANALYSIS_DIR="$REPO_DIR/analysis"
IMAGE='mt3000-modem-analysis:2026-07-19'

mkdir -p "$FIRMWARE_DIR" "$WORK_DIR" "$ANALYSIS_DIR"

in_container() {
    docker run --rm \
        --mount "type=bind,src=$REPO_DIR,dst=/repo" \
        "$IMAGE" "$@"
}
