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
printf '%s\n' 5 >"$sys_usb/devices/2-1/devnum"
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
cat >"$bin_dir/flock" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >>"$tmp/flock.log"
EOF
chmod +x "$bin_dir/"*

run_vos5g() {
	SYS_USB=$sys_usb LOGGER_BIN=true WAIT_LOOPS=1 \
		ADB_BIN=$bin_dir/adb TIMEOUT_BIN=$bin_dir/timeout \
		UQMI_BIN=$bin_dir/uqmi DEV_ROOT=$tmp/dev \
		FLOCK_BIN=$bin_dir/flock LOCK_ROOT=$tmp/lock \
		RUNTIME_DIR=$tmp/runtime \
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

# Contention must block until the winning prepare finishes, never report an
# unverified success, so the lock is taken without the non-blocking flag.
grep -Fx 9 "$tmp/flock.log" >/dev/null
if grep -F -- '-n' "$tmp/flock.log" >/dev/null; then
	echo 'prepare unexpectedly used a non-blocking lock' >&2
	exit 1
fi

# A completed preparation is recorded against the current USB connection.
test "$(cat "$tmp/runtime/vos5g-prepared-2-1")" = 5

# Preparation is idempotent while QMI already owns the modem, and a repeat
# call for the same USB connection short-circuits on the recorded stamp
# instead of repeating the QCMAP settle window and WDS client allocation.
: >"$uqmi_log"
run_vos5g prepare 2-1
test "$(cat "$sys_usb/devices/2-1/bConfigurationValue")" = 1
test "$(cat "$qcmap_state")" = inactive
test ! -s "$uqmi_log"

# A physical detach/attach assigns a new devnum, which invalidates the stamp
# and forces a full preparation for the new connection.
printf '%s\n' 6 >"$sys_usb/devices/2-1/devnum"
run_vos5g prepare 2-1
grep -F -- '--get-client-id wds' "$uqmi_log" >/dev/null
test "$(cat "$tmp/runtime/vos5g-prepared-2-1")" = 6

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
