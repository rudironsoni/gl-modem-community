#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

ROOT="$EXTRACT_DIR/rootfs"
mkdir -p "$ANALYSIS_DIR/strings"
{
    printf '%s\n' usr/bin/gl_modem usr/bin/cellular_manager usr/bin/modem_AT usr/bin/qcm usr/bin/process_modem_network usr/bin/modem_signal usr/lib/oui-httpd/rpc/modem.so
    find "$ROOT/usr/lib" -maxdepth 1 -type f -name 'libcm*.so' -print | sed "s#^$ROOT/##"
} | LC_ALL=C sort -u | while IFS= read -r rel; do
    test -f "$ROOT/$rel" || continue
    key=$(printf '%s' "$rel" | tr '/' '_')
    in_container sh -c 'strings -a -t x -n 4 /repo/extracted/rootfs/'"$rel"' | LC_ALL=C sort -k1,1 > /repo/analysis/strings/'"$key"'.txt'
done

printf 'source\toffset_and_string\n' > "$ANALYSIS_DIR/strings/at-command-catalog.tsv"
for report in "$ANALYSIS_DIR"/strings/*.txt; do
    test -f "$report" || continue
    source=$(basename "$report" .txt)
    grep -E '(^|[[:space:]])AT([+^$!&]|I([^[:alnum:]]|$))' "$report" 2>/dev/null | while IFS= read -r line; do
        printf '%s\t%s\n' "$source" "$line"
    done
done
