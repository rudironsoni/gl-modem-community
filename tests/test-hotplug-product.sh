#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
script="$repo_dir/package/gl-modem-community/files/etc/hotplug.d/usb/99-gl-modem-community"

grep -F '0e8d/7126/*|0e8d/7127/*|e8d/7126/*|e8d/7127/*' "$script" >/dev/null
grep -F 'fm350-fcc-unlock' "$script" >/dev/null
grep -F 'fm350-network-repair --available' "$script" >/dev/null
