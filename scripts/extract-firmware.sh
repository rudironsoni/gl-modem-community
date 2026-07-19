#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

test -f "$FIRMWARE_PATH"
rm_target="$WORK_DIR/extraction-new"
rm -rf "$rm_target"
mkdir -p "$rm_target/outer" "$rm_target/rootfs" "$rm_target/fit"
tar -xf "$FIRMWARE_PATH" -C "$rm_target/outer"
root_image=$(find "$rm_target/outer" -type f -name root -print | head -n 1)
kernel_image=$(find "$rm_target/outer" -type f -name kernel -print | head -n 1)
test -n "$root_image"
test -n "$kernel_image"

# Host filesystems may be case-insensitive, while the image is not. Extract in
# Docker tmpfs and archive the result to preserve both xt_DSCP.ko and xt_dscp.ko.
in_container sh -c '
set -eu
mkdir -p /case-root /repo/work/extraction-new/rootfs
unsquashfs -no-progress -d /case-root '"$(printf '%s' "$root_image" | sed "s#^$REPO_DIR#/repo#")"'
tar -C /case-root -cf /repo/work/extraction-new/rootfs.tar .
dumpimage -l '"$(printf '%s' "$kernel_image" | sed "s#^$REPO_DIR#/repo#")"' > /repo/analysis/reports/fit-list.txt
'

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR/rootfs"
# Device nodes cannot be recreated inside the macOS workspace sandbox. Their
# metadata remains in rootfs.tar and the generated manifest; omit them here.
tar --exclude='./dev/*' -xf "$rm_target/rootfs.tar" -C "$EXTRACT_DIR/rootfs"
cp -R "$rm_target/outer" "$EXTRACT_DIR/outer"
printf '%s\n' "$root_image" > "$ANALYSIS_DIR/reports/root-image-source.txt"
printf '%s\n' "$kernel_image" > "$ANALYSIS_DIR/reports/kernel-image-source.txt"
