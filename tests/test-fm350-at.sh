#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-at"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-fm350-at.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/usb/2-1/2-1:1.04" "$tmp/tty/ttyUSB2"
printf '%s\n' 0e8d >"$tmp/usb/2-1/idVendor"
printf '%s\n' 7126 >"$tmp/usb/2-1/idProduct"
printf '%s\n' 04 >"$tmp/usb/2-1/2-1:1.04/bInterfaceNumber"
printf '%s\n' 00 >"$tmp/usb/2-1/2-1:1.04/bInterfaceSubClass"
ln -s "$tmp/usb/2-1/2-1:1.04" "$tmp/tty/ttyUSB2/device"

cat >"$tmp/bin/comgt" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >"${COMGT_TEST_LOG:?}"
printf '%s\n' "${AT_COMMAND:?}" OK
EOF
cat >"$tmp/bin/flock" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/readlink" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = -f ]
readlink "$2"
EOF
chmod +x "$tmp/bin/comgt" "$tmp/bin/flock" "$tmp/bin/readlink"

output=$(
	USB_DEVICES_ROOT="$tmp/usb" \
	SYS_TTY_ROOT="$tmp/tty" \
	COMGT_BIN="$tmp/bin/comgt" \
	FLOCK_BIN="$tmp/bin/flock" \
	READLINK_BIN="$tmp/bin/readlink" \
	FM350_PORT_BIN="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-port" \
	GCOM_SCRIPT="$tmp/fm350-at.gcom" \
	LOCK_FILE="$tmp/at.lock" \
	COMGT_TEST_LOG="$tmp/comgt.log" \
	"$helper" 2-1 'AT+CGPADDR=1'
)

test "$(cat "$tmp/comgt.log")" = "-d /dev/ttyUSB2 -s $tmp/fm350-at.gcom"
printf '%s\n' "$output" | grep -F 'AT+CGPADDR=1' >/dev/null
printf '%s\n' "$output" | grep -F 'OK' >/dev/null

printf '%s\n' 2c7c >"$tmp/usb/2-1/idVendor"
if USB_DEVICES_ROOT="$tmp/usb" SYS_TTY_ROOT="$tmp/tty" \
	COMGT_BIN="$tmp/bin/comgt" FLOCK_BIN="$tmp/bin/flock" \
	READLINK_BIN="$tmp/bin/readlink" \
	FM350_PORT_BIN="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-port" \
	LOCK_FILE="$tmp/at.lock" "$helper" 2-1 AT >/dev/null 2>&1; then
	echo 'Non-FM350 USB ID unexpectedly used the explicit AT transport' >&2
	exit 1
fi

# Dell DW5931e: skip ADB if 5 and use if 6 / ttyUSB4.
rm -rf "$tmp/usb/2-1" "$tmp/tty"
mkdir -p \
	"$tmp/usb/2-1/2-1:1.5" \
	"$tmp/usb/2-1/2-1:1.6" \
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
: >"$tmp/comgt.log"
USB_DEVICES_ROOT="$tmp/usb" \
SYS_TTY_ROOT="$tmp/tty" \
COMGT_BIN="$tmp/bin/comgt" \
FLOCK_BIN="$tmp/bin/flock" \
READLINK_BIN="$tmp/bin/readlink" \
FM350_PORT_BIN="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-port" \
GCOM_SCRIPT="$tmp/fm350-at.gcom" \
LOCK_FILE="$tmp/at.lock" \
COMGT_TEST_LOG="$tmp/comgt.log" \
	"$helper" 2-1 AT >/dev/null
test "$(cat "$tmp/comgt.log")" = "-d /dev/ttyUSB4 -s $tmp/fm350-at.gcom"
