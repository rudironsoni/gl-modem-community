#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-band-monitor
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-vos5g-band.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

sys_usb=$tmp/sys/bus/usb
bin_dir=$tmp/bin
runtime=$tmp/run
mkdir -p "$sys_usb/devices/2-1" "$sys_usb/devices/2-1:1.3/usbmisc" \
	"$tmp/dev" "$bin_dir" "$runtime"
printf '%s\n' 05c6 >"$sys_usb/devices/2-1/idVendor"
printf '%s\n' 9064 >"$sys_usb/devices/2-1/idProduct"
: >"$sys_usb/devices/2-1:1.3/usbmisc/cdc-wdm0"
: >"$tmp/dev/cdc-wdm0"
: >"$tmp/uqmi.log"

cat >"$bin_dir/timeout" <<'EOF'
#!/bin/sh
shift
exec "$@"
EOF
cat >"$bin_dir/uqmi" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$tmp/uqmi.log"
case "\$*" in
*--get-client-id\ nas*) printf '%s\n' 7 ;;
*) exit 0 ;;
esac
EOF
cat >"$bin_dir/rf-band-reader" <<'EOF'
#!/bin/sh
test "$2" = 7
printf '%s\n' n71+B2
EOF
cat >"$bin_dir/system-mode-reader" <<'EOF'
#!/bin/sh
test "$1" = "${TEST_QMI_DEVICE:?}"
printf '%s\n' SA
EOF
cat >"$bin_dir/device-test" <<'EOF'
#!/bin/sh
test "$1" = -c
exit 0
EOF
chmod +x "$bin_dir/"*

TEST_QMI_DEVICE=$tmp/dev/cdc-wdm0
export TEST_QMI_DEVICE
SYS_USB=$sys_usb DEV_ROOT=$tmp/dev RUNTIME_DIR=$runtime \
	LOCK_ROOT=$tmp/lock UQMI_BIN=$bin_dir/uqmi \
	TIMEOUT_BIN=$bin_dir/timeout FLOCK_BIN=true LOGGER_BIN=true \
	RF_BAND_READER=$bin_dir/rf-band-reader \
	SYSTEM_MODE_READER=$bin_dir/system-mode-reader \
	DEVICE_TEST_BIN=$bin_dir/device-test \
	"$script" refresh 2-1

test "$(cat "$runtime/vos5g-band-2-1")" = n71+B2
test "$(cat "$runtime/vos5g-mode-2-1")" = SA
grep -F -- '--get-client-id nas' "$tmp/uqmi.log" >/dev/null
grep -F -- '--set-client-id nas,7 --release-client-id nas' "$tmp/uqmi.log" >/dev/null

if SYS_USB=$sys_usb DEV_ROOT=$tmp/dev RUNTIME_DIR=$runtime \
	LOCK_ROOT=$tmp/lock UQMI_BIN=$bin_dir/uqmi \
	TIMEOUT_BIN=$bin_dir/timeout FLOCK_BIN=true LOGGER_BIN=true \
	RF_BAND_READER=$bin_dir/rf-band-reader \
	SYSTEM_MODE_READER=$bin_dir/system-mode-reader \
	DEVICE_TEST_BIN=$bin_dir/device-test \
	"$script" refresh '../2-1'; then
	echo 'invalid USB bus name unexpectedly accepted' >&2
	exit 1
fi
