#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 PRIVATE_KEY PUBLIC_KEY" >&2
    exit 2
fi

private_key=$1
public_key=$2
test -s "$private_key"
test -s "$public_key"

tmp=$(mktemp "${TMPDIR:-/tmp}/gl-modem-public-key.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM
openssl pkey -in "$private_key" -pubout -out "$tmp"

if ! cmp -s "$tmp" "$public_key"; then
    echo "APK signing private key does not match $public_key" >&2
    exit 1
fi
