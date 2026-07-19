#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

mkdir -p "$ANALYSIS_DIR/reports"
{
    printf '# Generated evidence index\n\n'
    printf 'Generated UTC: %s\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    find "$ANALYSIS_DIR" -type f ! -path '*/reports/generated-index.md' -print | sed "s#^$REPO_DIR/##" | LC_ALL=C sort | sed 's/^/- `&`/'
} > "$ANALYSIS_DIR/reports/generated-index.md"

