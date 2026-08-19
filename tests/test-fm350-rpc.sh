#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
modem="$repo_dir/package/gl-modem-community/files/usr/lib/oui-httpd/rpc/modem"
driver="$repo_dir/package/gl-modem-community/files/usr/share/gl-modem-community/rpc-drivers/fm350.lua"
harness="$repo_dir/tests/lib/fm350-rpc-harness.lua"
fixtures="$repo_dir/tests/fixtures/fm350"
json="$repo_dir/package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/fm350.json"

grep -F '"get_info", "get_status"' "$modem" >/dev/null
grep -F 'find_fm350_bus' "$modem" >/dev/null
grep -F 'set_slot_config' "$modem" >/dev/null
grep -F 'get_info = get_info' "$driver" >/dev/null
grep -F 'get_status = get_status' "$driver" >/dev/null
grep -F 'set_connect = set_connect' "$driver" >/dev/null
grep -F 'get_sim_config = get_sim_config' "$driver" >/dev/null
grep -F 'get_slot_config = get_slot_config' "$driver" >/dev/null
grep -F 'set_slot_config = set_slot_config' "$driver" >/dev/null
grep -F 'modems =' "$driver" >/dev/null
grep -F 'args.config' "$driver" >/dev/null
grep -F 'AT+GTDUALSIM' "$driver" >/dev/null
! grep -F 'NR5G-NSA' "$driver" >/dev/null
jq -e '.modems[] | select(.vid=="0e8d" and .pid=="7126") | .sim_slot_num == 1' "$json" >/dev/null
jq -e '.modems[] | select(.vid=="0e8d" and .pid=="7127") | .sim_slot_num == 2' "$json" >/dev/null
jq -e '.modems[] | select(.vid=="0e8d" and .pid=="7127") | has("supports_esim") | not' "$json" >/dev/null

if command -v luac5.1 >/dev/null 2>&1; then
	luac5.1 -p "$modem"
	luac5.1 -p "$driver"
	luac5.1 -p "$harness"
fi

# shellcheck disable=SC1091
. "$repo_dir/tests/lib/run-lua.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-fm350-rpc.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/sys/2-1"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"

run_harness() {
	expect=$1
	gtcc=${2:-gtccinfo-lte}
	cops=${3:-cops-lte}
	FM350_DRIVER="$driver" \
	FM350_FIXTURE_DIR="$fixtures" \
	USB_DEVICES_ROOT="$tmp/sys" \
	FM350_EXPECT="$expect" \
	FM350_GTCCINFO="$gtcc" \
	FM350_COPS="$cops" \
	RUN_LUA_BIND="$tmp" \
		run_lua "$harness"
}

run_harness lte-mode gtccinfo-lte
run_harness nsa-mode gtccinfo-nsa
run_harness sa-mode gtccinfo-sa
run_harness cops-fallback gtccinfo-empty cops-nr
run_harness set-sim-nested
run_harness set-slot
