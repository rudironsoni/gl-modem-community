#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-esim-sdk"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-esim-sdk.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys"
command -v jq >/dev/null 2>&1 || {
	echo 'jq is required for esim sdk tests' >&2
	exit 1
}

export USB_DEVICES_ROOT="$tmp/sys"
export JQ_BIN=jq
export LPAC_BIN="$tmp/missing-lpac"

status=$("$helper" '{"method":"status","env":1}')
printf '%s\n' "$status" | jq -e '.code == 200' >/dev/null
printf '%s\n' "$status" | jq -e '.data | has("eid")' >/dev/null
printf '%s\n' "$status" | jq -e '.data | has("profile_list")' >/dev/null

info=$("$helper" '{"method":"info2","env":1}')
printf '%s\n' "$info" | jq -e '.code == 200' >/dev/null
printf '%s\n' "$info" | jq -e '.data.extCardResource | contains("non_volatile_mem")' >/dev/null

install=$("$helper" '{"method":"install","activationCode":"LPA:1$example$secret"}')
printf '%s\n' "$install" | jq -e '.code == 600' >/dev/null
if printf '%s\n' "$install" | grep -F secret >/dev/null; then
	echo 'activation code leaked from esim sdk' >&2
	exit 1
fi
