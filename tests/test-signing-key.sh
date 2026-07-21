#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-key-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 -out "$tmp/private-a.pem" 2>/dev/null
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 -out "$tmp/private-b.pem" 2>/dev/null
openssl pkey -in "$tmp/private-a.pem" -pubout -out "$tmp/public-a.pem" 2>/dev/null

"$REPO_DIR/scripts/verify-signing-key.sh" "$tmp/private-a.pem" "$tmp/public-a.pem"
if "$REPO_DIR/scripts/verify-signing-key.sh" "$tmp/private-b.pem" "$tmp/public-a.pem" >"$tmp/mismatch.log" 2>&1; then
    echo 'Mismatched signing key unexpectedly passed validation' >&2
    exit 1
fi
grep -Fq 'APK signing private key does not match' "$tmp/mismatch.log"
