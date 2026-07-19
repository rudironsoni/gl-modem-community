#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

ROOT="$EXTRACT_DIR/rootfs"
test -d "$ROOT"
mkdir -p "$ANALYSIS_DIR/manifests" "$ANALYSIS_DIR/configs"

in_container sh -c '
set -eu
cd /repo/extracted/rootfs
find . -printf "%M\t%U\t%G\t%s\t%y\t%p\t%l\n" | LC_ALL=C sort > /repo/analysis/manifests/filesystem.tsv
find . -type f -exec file {} + | LC_ALL=C sort > /repo/analysis/manifests/file-types.txt
find . -type f -exec sh -c '\''for f do file "$f" | grep -q "ELF" && printf "%s\n" "$f"; done'\'' sh {} + | LC_ALL=C sort > /repo/analysis/manifests/elf-paths.txt
find . -type f \( -name "*.sh" -o -name "*.lua" -o -name "*.uc" -o -name "*.js" -o -name "*.json" \) | LC_ALL=C sort > /repo/analysis/manifests/source-like-paths.txt
'

for path in etc/openwrt_release etc/os-release etc/config/cellular etc/config/glmodem lib/modem_data/modem_list.json; do
    if test -f "$ROOT/$path"; then
        dest=$(printf '%s' "$path" | tr '/' '_')
        cp "$ROOT/$path" "$ANALYSIS_DIR/configs/$dest"
    fi
done

