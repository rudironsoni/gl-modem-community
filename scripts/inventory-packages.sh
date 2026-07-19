#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

ROOT="$EXTRACT_DIR/rootfs"
test -d "$ROOT"
mkdir -p "$ANALYSIS_DIR/manifests"

if test -f "$ROOT/lib/apk/db/installed"; then
    cp "$ROOT/lib/apk/db/installed" "$ANALYSIS_DIR/manifests/apk-installed.txt"
    awk -F: '/^P:/{print $2}' "$ROOT/lib/apk/db/installed" | sed 's/^ //' | LC_ALL=C sort > "$ANALYSIS_DIR/manifests/package-names.txt"
else
    : > "$ANALYSIS_DIR/manifests/apk-installed.txt"
fi

if test -d "$ROOT/usr/lib/opkg/info"; then
    find "$ROOT/usr/lib/opkg/info" -type f | LC_ALL=C sort > "$ANALYSIS_DIR/manifests/opkg-metadata-paths.txt"
else
    printf '%s\n' 'No opkg metadata directory found.' > "$ANALYSIS_DIR/manifests/opkg-metadata-paths.txt"
fi

find "$ROOT/lib/apk/packages" -type f -name '*.list' -print | sed 's#.*/##;s/\.list$//' | LC_ALL=C sort > "$ANALYSIS_DIR/manifests/apk-package-list-files.txt"

