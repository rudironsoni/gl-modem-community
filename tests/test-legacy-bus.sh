#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/legacy-bus"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-legacy-bus.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

usb_root="$tmp/usb"
extern_bus="$tmp/modem/extern_modem_bus"
owner="$tmp/runtime/legacy-bus"
mkdir -p "$usb_root/2-1.3"
printf '%s\n' 0e8d >"$usb_root/2-1.3/idVendor"
printf '%s\n' 7126 >"$usb_root/2-1.3/idProduct"

USB_DEVICES_ROOT="$usb_root" \
EXTERN_BUS_FILE="$extern_bus" \
OWNER_FILE="$owner" \
LOGGER_BIN=true \
"$helper" refresh

test "$(cat "$extern_bus")" = 2-1.3
test "$(cat "$owner")" = 2-1.3

USB_DEVICES_ROOT="$usb_root" \
EXTERN_BUS_FILE="$extern_bus" \
OWNER_FILE="$owner" \
LOGGER_BIN=true \
"$helper" restore

test ! -e "$extern_bus"
test ! -e "$owner"

mkdir -p "$(dirname "$extern_bus")"
printf '%s\n' stock-bus >"$extern_bus"
USB_DEVICES_ROOT="$usb_root" \
EXTERN_BUS_FILE="$extern_bus" \
OWNER_FILE="$owner" \
LOGGER_BIN=true \
"$helper" refresh

test "$(cat "$extern_bus")" = stock-bus
test ! -e "$owner"
