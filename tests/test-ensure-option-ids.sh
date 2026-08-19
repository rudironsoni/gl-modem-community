#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/ensure-option-ids"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-ensure-option.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p \
	"$tmp/usb/devices/2-1/2-1:1.2" \
	"$tmp/usb/devices/2-1/2-1:1.3" \
	"$tmp/usb/devices/2-1/2-1:1.4" \
	"$tmp/usb/devices/2-1/2-1:1.5" \
	"$tmp/usb/devices/2-1/2-1:1.6" \
	"$tmp/usb/devices/2-1/2-1:1.7" \
	"$tmp/usb/devices/2-1/2-1:1.8" \
	"$tmp/usb/devices/2-1/2-1:1.9" \
	"$tmp/usb/devices/2-1/2-1:1.0/net/eth2" \
	"$tmp/usb/drivers/option" \
	"$tmp/tty" \
	"$tmp/bin"
printf '%s\n' 0e8d >"$tmp/usb/devices/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/usb/devices/2-1/idProduct"
printf '%s\n' ff >"$tmp/usb/devices/2-1/2-1:1.6/bInterfaceClass"
ln -s "$tmp/usb/drivers/option" "$tmp/usb/devices/2-1/2-1:1.6/driver"
printf '%s\n' 06 >"$tmp/usb/devices/2-1/2-1:1.6/bInterfaceNumber"
printf '%s\n' 00 >"$tmp/usb/devices/2-1/2-1:1.6/bInterfaceSubClass"

# Unresolved bus path vs resolved ttyUSB path, the field-test race.
mkdir -p "$tmp/real/2-1"
ln -s "$tmp/real/2-1" "$tmp/usb/devices/2-1-real-link" 2>/dev/null || true
i=0
while [ "$i" -lt 8 ]; do
	mkdir -p "$tmp/real/2-1/2-1:1.$((i + 2))" "$tmp/tty/ttyUSB$i"
	ln -s "$tmp/usb/devices/2-1/2-1:1.$((i + 2))" "$tmp/tty/ttyUSB$i/device"
	i=$((i + 1))
done
# Point ttyUSB nodes at the resolved USB tree so a naive /sys/bus compare fails.
rm -f "$tmp/tty"/ttyUSB*/device
i=0
while [ "$i" -lt 8 ]; do
	mkdir -p "$tmp/platform/usb/2-1/2-1:1.$((i + 2))"
	printf '%s\n' "0$((i + 2))" >"$tmp/platform/usb/2-1/2-1:1.$((i + 2))/bInterfaceNumber"
	printf '%s\n' 00 >"$tmp/platform/usb/2-1/2-1:1.$((i + 2))/bInterfaceSubClass"
	ln -s "$tmp/platform/usb/2-1/2-1:1.$((i + 2))" "$tmp/tty/ttyUSB$i/device"
	i=$((i + 1))
done
rm -rf "$tmp/usb/devices/2-1"
mkdir -p "$tmp/platform/usb/2-1/2-1:1.0/net/eth2" "$tmp/platform/usb/2-1/2-1:1.6"
printf '%s\n' 0e8d >"$tmp/platform/usb/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/platform/usb/2-1/idProduct"
printf '%s\n' 06 >"$tmp/platform/usb/2-1/2-1:1.6/bInterfaceNumber"
printf '%s\n' 00 >"$tmp/platform/usb/2-1/2-1:1.6/bInterfaceSubClass"
printf '%s\n' ff >"$tmp/platform/usb/2-1/2-1:1.6/bInterfaceClass"
ln -s "$tmp/usb/drivers/option" "$tmp/platform/usb/2-1/2-1:1.6/driver"
ln -s "$tmp/platform/usb/2-1" "$tmp/usb/devices/2-1"

cat >"$tmp/bin/readlink" <<'EOF'
#!/bin/sh
[ "$1" = -f ]
readlink -f "$2"
EOF
cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${ENSURE_LOG:?}"
EOF
chmod +x "$tmp/bin/"*
: >"$tmp/ensure.log"

port_bin="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-port"

SYS_USB="$tmp/usb" \
SYS_USB_SERIAL="$tmp/usb-serial" \
SYS_TTY="$tmp/tty" \
FM350_PORT_BIN="$port_bin" \
READLINK_BIN=readlink \
ENUM_TIMEOUT=3 \
ENUM_STABLE_SECONDS=1 \
EXPECTED_TTY=8 \
LOGGER_BIN="$tmp/bin/logger" \
ENSURE_LOG="$tmp/ensure.log" \
	"$helper" --wait-ready

grep -F 'stable' "$tmp/ensure.log" >/dev/null
