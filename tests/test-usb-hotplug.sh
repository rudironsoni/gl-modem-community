#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
hotplug=$repo_dir/package/gl-modem-community/files/etc/hotplug.d/usb/99-gl-modem-community
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-usb-hotplug.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

sys_usb=$tmp/sys/bus/usb
mkdir -p "$tmp/bin" "$tmp/runtime" "$sys_usb/devices/2-1" \
	"$sys_usb/devices/2-2"
: >"$tmp/log"
: >"$tmp/runtime/stack"
printf '%s\n' 05c6 >"$sys_usb/devices/2-1/idVendor"
printf '%s\n' 9064 >"$sys_usb/devices/2-1/idProduct"
printf '%s\n' 0e8d >"$sys_usb/devices/2-2/idVendor"
printf '%s\n' 7127 >"$sys_usb/devices/2-2/idProduct"

cat >"$tmp/bin/runtime-stack" <<'EOF'
#!/bin/sh
printf '%s\n' "${STACK_TEST_VALUE:?}"
EOF

for helper in ensure-option-ids legacy-bus vos5g-qmi; do
cat >"$tmp/bin/$helper" <<'EOF'
#!/bin/sh
if [ "$#" -eq 0 ]; then
	printf '%s\n' "${0##*/}" >>"${HOTPLUG_TEST_LOG:?}"
else
	printf '%s %s\n' "${0##*/}" "$*" >>"${HOTPLUG_TEST_LOG:?}"
fi
EOF
done
chmod +x "$tmp/bin/"*

run_hotplug() {
	RUNTIME_STACK="$tmp/bin/runtime-stack" \
	STACK_FILE="$tmp/runtime/stack" \
	ENSURE_OPTION_IDS="$tmp/bin/ensure-option-ids" \
	LEGACY_BUS="$tmp/bin/legacy-bus" \
	VOS5G_QMI="$tmp/bin/vos5g-qmi" \
	SYS_USB="$sys_usb" \
	HOTPLUG_TEST_LOG="$tmp/log" \
	STACK_TEST_VALUE="$1" ACTION="$2" DEVTYPE="$3" DEVPATH="$4" \
	PRODUCT="${5:-}" \
		"$hotplug"
}

# VOS is supported by the modern stack and interface bind paths must be
# normalized from 2-1:1.x to the parent USB bus 2-1.
run_hotplug modern bind usb_interface /devices/platform/usb/2-1/2-1:1.3
grep -Fx 'vos5g-qmi prepare 2-1' "$tmp/log" >/dev/null

# The same event must not run before the package service owns the runtime.
: >"$tmp/log"
rm -f "$tmp/runtime/stack"
run_hotplug modern bind usb_interface /devices/platform/usb/2-1/2-1:1.3
test ! -s "$tmp/log"

# Legacy MediaTek refresh remains restricted to the legacy stack.
: >"$tmp/runtime/stack"
run_hotplug modern bind usb_device /devices/platform/usb/2-2 0e8d/7127/0000
test ! -s "$tmp/log"
rm -rf "$sys_usb/devices/2-2"
run_hotplug legacy bind usb_device /devices/platform/usb/2-2 0e8d/7127/0000
cat >"$tmp/expected" <<'EOF'
ensure-option-ids
legacy-bus refresh
EOF
cmp "$tmp/expected" "$tmp/log"
