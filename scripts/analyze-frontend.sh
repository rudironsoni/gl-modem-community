#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

ROOT="$EXTRACT_DIR/rootfs"
mkdir -p "$ANALYSIS_DIR/frontend/original" "$ANALYSIS_DIR/frontend/beautified" "$ANALYSIS_DIR/frontend"

find "$ROOT/www" -type f \( -name '*.js' -o -name '*.js.gz' \) -print | LC_ALL=C sort > "$ANALYSIS_DIR/frontend/javascript-paths.txt"

: > "$ANALYSIS_DIR/frontend/bundle-sha256.tsv"
while IFS= read -r js; do
    rel=${js#"$ROOT/"}
    key=$(printf '%s' "$rel" | tr '/' '_')
	case "$js" in
		*.gz) gzip -dc "$js" > "$ANALYSIS_DIR/frontend/original/${key%.gz}" ;;
		*) cp "$js" "$ANALYSIS_DIR/frontend/original/$key" ;;
	esac
	sha256sum "$ANALYSIS_DIR/frontend/original/${key%.gz}" |
		awk -v path="$rel" '{ print path "\t" $1 }' >> "$ANALYSIS_DIR/frontend/bundle-sha256.tsv"
done < "$ANALYSIS_DIR/frontend/javascript-paths.txt"

in_container sh -c '
set -eu
for f in /repo/analysis/frontend/original/*.js; do
    test -f "$f" || continue
    js-beautify "$f" > "/repo/analysis/frontend/beautified/$(basename "$f")"
done
	grep -rhoE "(/rpc|/ws|cellular\\.[A-Za-z0-9_.-]+|unsupportedModem|currentModemType|send_at_command|get_[A-Za-z0-9_]+|set_[A-Za-z0-9_]+|scan_[A-Za-z0-9_]+|remove_profile|disconnect)" /repo/analysis/frontend/beautified 2>/dev/null |
		LC_ALL=C sort -u > /repo/analysis/frontend/api-hits.txt || true
'
