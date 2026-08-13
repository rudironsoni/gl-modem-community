#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-qmi
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-vos5g-qmi.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

sys_usb=$tmp/sys/bus/usb
bin_dir=$tmp/bin
qcmap_state=$tmp/qcmap.state
uqmi_log=$tmp/uqmi.log
mkdir -p "$sys_usb/devices/2-1" "$sys_usb/devices/2-1:1.2" \
	"$sys_usb/devices/2-1:1.3/usbmisc" "$sys_usb/drivers/option" \
	"$sys_usb/drivers/qmi_wwan" "$tmp/dev" "$bin_dir"
printf '%s\n' 05c6 >"$sys_usb/devices/2-1/idVendor"
printf '%s\n' 9064 >"$sys_usb/devices/2-1/idProduct"
printf '%s\n' 2 >"$sys_usb/devices/2-1/bConfigurationValue"
printf '%s\n' testserial >"$sys_usb/devices/2-1/serial"
printf '%s\n' active >"$qcmap_state"
: >"$sys_usb/devices/2-1:1.3/usbmisc/cdc-wdm0"
: >"$tmp/dev/cdc-wdm0"
: >"$uqmi_log"
ln -s "$sys_usb/drivers/qmi_wwan" "$sys_usb/devices/2-1:1.3/driver"
ln -s "$sys_usb/drivers/option" "$sys_usb/devices/2-1:1.2/driver"

cat >"$bin_dir/timeout" <<'EOF'
#!/bin/sh
shift
exec "$@"
EOF
cat >"$bin_dir/adb" <<EOF
#!/bin/sh
case "\$*" in
start-server|*-s\ testserial\ wait-for-device) exit 0 ;;
*-s\ testserial\ shell\ systemctl\ is-active*) cat "$qcmap_state" ;;
*-s\ testserial\ shell\ systemctl\ stop*) printf '%s\\n' inactive >"$qcmap_state" ;;
*) exit 1 ;;
esac
EOF
cat >"$bin_dir/uqmi" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >>"$uqmi_log"
case "\$*" in
*--get-client-id\ wds*) printf '%s\\n' 7 ;;
*) exit 0 ;;
esac
EOF
chmod +x "$bin_dir/"*

run_vos5g() {
	SYS_USB=$sys_usb LOGGER_BIN=true WAIT_LOOPS=1 \
		ADB_BIN=$bin_dir/adb TIMEOUT_BIN=$bin_dir/timeout \
		UQMI_BIN=$bin_dir/uqmi DEV_ROOT=$tmp/dev \
		FLOCK_BIN=true LOCK_ROOT=$tmp/lock \
		QCMAP_SETTLE_LOOPS=0 QMI_RELEASE_WAIT_SECS=0 \
		"$script" "$@"
}

run_vos5g prepare 2-1
test "$(cat "$sys_usb/devices/2-1/bConfigurationValue")" = 1
test "$(cat "$qcmap_state")" = inactive
test "$(basename "$(readlink "$sys_usb/devices/2-1:1.3/driver")")" = qmi_wwan
test "$(basename "$(readlink "$sys_usb/devices/2-1:1.2/driver")")" = option
grep -F -- '--set-client-id wds,7 --set-autoconnect disabled' "$uqmi_log" >/dev/null
grep -F -- '--set-client-id wds,7 --release-client-id wds' "$uqmi_log" >/dev/null

# Preparation is idempotent while QMI already owns the modem.
run_vos5g prepare 2-1
test "$(cat "$sys_usb/devices/2-1/bConfigurationValue")" = 1
test "$(cat "$qcmap_state")" = inactive

mkdir -p "$sys_usb/devices/3-1"
printf '%s\n' 1234 >"$sys_usb/devices/3-1/idVendor"
printf '%s\n' 9064 >"$sys_usb/devices/3-1/idProduct"
printf '%s\n' 2 >"$sys_usb/devices/3-1/bConfigurationValue"
run_vos5g prepare 3-1
test "$(cat "$sys_usb/devices/3-1/bConfigurationValue")" = 2

if run_vos5g prepare '../2-1'; then
	echo 'invalid USB bus name unexpectedly accepted' >&2
	exit 1
fi
