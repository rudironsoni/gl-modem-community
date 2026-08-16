#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-port"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-fm350-port.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin"
cat >"$tmp/bin/readlink" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = -f ]
readlink "$2"
EOF
chmod +x "$tmp/bin/readlink"

# Dell DW5931e: if 5 is ADB (ttyUSB3), if 6 is AT (ttyUSB4), RNDIS net is eth2.
mkdir -p \
	"$tmp/usb/2-1/2-1:1.5" \
	"$tmp/usb/2-1/2-1:1.6" \
	"$tmp/usb/2-1/2-1:1.0/net/eth2" \
	"$tmp/tty/ttyUSB3" \
	"$tmp/tty/ttyUSB4"
printf '%s\n' 0e8d >"$tmp/usb/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/usb/2-1/idProduct"
printf '%s\n' 05 >"$tmp/usb/2-1/2-1:1.5/bInterfaceNumber"
printf '%s\n' 42 >"$tmp/usb/2-1/2-1:1.5/bInterfaceSubClass"
printf '%s\n' 06 >"$tmp/usb/2-1/2-1:1.6/bInterfaceNumber"
printf '%s\n' 00 >"$tmp/usb/2-1/2-1:1.6/bInterfaceSubClass"
ln -s "$tmp/usb/2-1/2-1:1.5" "$tmp/tty/ttyUSB3/device"
ln -s "$tmp/usb/2-1/2-1:1.6" "$tmp/tty/ttyUSB4/device"

run_port() {
	USB_DEVICES_ROOT="$tmp/usb" \
	SYS_TTY_ROOT="$tmp/tty" \
	READLINK_BIN="$tmp/bin/readlink" \
		"$helper" "$@"
}

test "$(run_port at 2-1)" = /dev/ttyUSB4
test "$(run_port data 2-1)" = eth2
run_port ready 2-1

# Path compare must use the resolved USB device, not /sys/bus/usb/devices.
# A padded :1.05 match must not steal the ADB interface.
mkdir -p "$tmp/usb/2-1/2-1:1.05"
printf '%s\n' 05 >"$tmp/usb/2-1/2-1:1.05/bInterfaceNumber"
printf '%s\n' 42 >"$tmp/usb/2-1/2-1:1.05/bInterfaceSubClass"
test "$(run_port at 2-1)" = /dev/ttyUSB4

# 7126 prefers interface 04 / ttyUSB2.
mkdir -p \
	"$tmp/usb/1-1/1-1:1.4" \
	"$tmp/usb/1-1/1-1:1.0/net/wwan0" \
	"$tmp/tty/ttyUSB2"
printf '%s\n' 0e8d >"$tmp/usb/1-1/idVendor"
printf '%s\n' 7126 >"$tmp/usb/1-1/idProduct"
printf '%s\n' 04 >"$tmp/usb/1-1/1-1:1.4/bInterfaceNumber"
printf '%s\n' 00 >"$tmp/usb/1-1/1-1:1.4/bInterfaceSubClass"
ln -s "$tmp/usb/1-1/1-1:1.4" "$tmp/tty/ttyUSB2/device"
test "$(run_port at 1-1)" = /dev/ttyUSB2
test "$(run_port data 1-1)" = wwan0

# Non-FM350 is rejected.
mkdir -p "$tmp/usb/3-1"
printf '%s\n' 2c7c >"$tmp/usb/3-1/idVendor"
printf '%s\n' 0801 >"$tmp/usb/3-1/idProduct"
if run_port at 3-1 >/dev/null 2>&1; then
	echo 'Non-FM350 USB ID unexpectedly resolved an AT port' >&2
	exit 1
fi
