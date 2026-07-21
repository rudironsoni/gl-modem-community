#!/bin/sh
set -eu

if [ "$#" -ne 6 ]; then
    echo "usage: $0 SDK_DIR PRIVATE_KEY PUBLIC_KEY APK OUTPUT_INDEX OUTPUT_METADATA" >&2
    exit 2
fi

SDK_DIR=$1
PRIVATE_KEY=$2
PUBLIC_KEY=$3
APK=$4
OUTPUT_INDEX=$5
OUTPUT_METADATA=$6
APK_TOOL="$SDK_DIR/staging_dir/host/bin/apk"

test -x "$APK_TOOL"
test -s "$PRIVATE_KEY"
test -s "$PUBLIC_KEY"
test -s "$APK"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-signing.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

"$(dirname "$0")/verify-signing-key.sh" "$PRIVATE_KEY" "$PUBLIC_KEY"

"$APK_TOOL" adbsign \
    --allow-untrusted \
    --reset-signatures \
    --sign-key "$PRIVATE_KEY" \
    "$APK"

apk_dir=$(cd "$(dirname "$APK")" && pwd)
apk_name=$(basename "$APK")
index_dir=$(dirname "$OUTPUT_INDEX")
mkdir -p "$index_dir"
index_dir=$(cd "$index_dir" && pwd)
index_name=$(basename "$OUTPUT_INDEX")
public_keys=$(dirname "$PUBLIC_KEY")

(
    cd "$apk_dir"
    "$APK_TOOL" mkndx \
        --description "gl-modem-community signed package feed" \
        --keys-dir "$public_keys" \
        --output "$index_dir/$index_name" \
        --sign-key "$PRIVATE_KEY" \
        "$apk_name"
)

"$APK_TOOL" verify --keys-dir "$public_keys" "$APK"
"$APK_TOOL" verify --keys-dir "$public_keys" "$OUTPUT_INDEX"

mkdir "$tmp/empty-keys"
for signed_file in "$APK" "$OUTPUT_INDEX"; do
    if "$APK_TOOL" verify --keys-dir "$tmp/empty-keys" "$signed_file" >"$tmp/untrusted.log" 2>&1; then
        echo "Verification unexpectedly trusted $signed_file without the public key" >&2
        exit 1
    fi
    grep -Fq 'UNTRUSTED' "$tmp/untrusted.log"
done

"$APK_TOOL" adbdump --format json "$APK" > "$OUTPUT_METADATA"
