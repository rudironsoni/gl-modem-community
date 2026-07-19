#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

ROOT="$EXTRACT_DIR/rootfs"
LIST="$ANALYSIS_DIR/manifests/elf-paths.txt"
test -f "$LIST"
mkdir -p "$ANALYSIS_DIR/elf"

while IFS= read -r rel; do
    rel=${rel#./}
    case "$rel" in
        usr/bin/gl_modem|usr/bin/cellular_manager|usr/bin/modem_AT|usr/bin/qcm|usr/bin/process_modem_network|usr/bin/modem_signal|usr/lib/libcm*.so|usr/lib/oui-httpd/rpc/modem.so)
            key=$(printf '%s' "$rel" | tr '/' '_')
            out="$ANALYSIS_DIR/elf/$key.txt"
            sha=$(shasum -a 256 "$ROOT/$rel" | awk '{print $1}')
            {
                printf 'path: /%s\nsha256: %s\n\n' "$rel" "$sha"
                file "$ROOT/$rel"
            } > "$out"
            in_container sh -c '
f=/repo/extracted/rootfs/'"$rel"'
o=/repo/analysis/elf/'"$key"'.txt
{ echo; echo "## readelf -h -l -d -n -s"; readelf -W -h -l -d -n -s "$f" 2>&1 || true; echo; echo "## objdump -p -T"; objdump -p -T "$f" 2>&1 || true; echo; echo "## nm -D"; nm -D "$f" 2>&1 || true; } >> "$o"
'
            ;;
    esac
done < "$LIST"

printf 'path\tsha256\tfile\n' > "$ANALYSIS_DIR/elf/index.tsv"
for report in "$ANALYSIS_DIR"/elf/*.txt; do
    test -f "$report" || continue
    path=$(sed -n 's/^path: //p' "$report" | head -n 1)
    sha=$(sed -n 's/^sha256: //p' "$report" | head -n 1)
    description=$(sed -n '4p' "$report")
    printf '%s\t%s\t%s\n' "$path" "$sha" "$description" >> "$ANALYSIS_DIR/elf/index.tsv"
done
