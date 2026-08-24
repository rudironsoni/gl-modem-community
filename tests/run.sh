#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=mt3000-modem-analysis:2026-07-19
PACKAGE="$REPO_DIR/package/gl-modem-community"

echo "Running container tests..."
docker run --rm --mount "type=bind,src=$REPO_DIR,dst=/repo" "$IMAGE" sh -c '
set -eu
find /repo/tests /repo/package/gl-modem-community/files -type f -perm /111 \
        ! -name "*.lua" ! -name "vos5g-qmi-rf-band" \
        ! -name "vos5g-qmi-system-mode" -exec sh -n {} \;
find /repo/package/gl-modem-community/files -type f -name "*.lua" -exec luac5.1 -p {} \;
    luac5.1 -p \
        /repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-qmi-rf-band \
        /repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-qmi-system-mode
shellcheck -S warning -e SC1091,SC2034,SC3043 /repo/tests/*.sh \
		/repo/tools/assemble-release-feeds \
		/repo/tools/generate-feed-index \
		/repo/package/gl-modem-community/files/etc/init.d/gl_modem_community \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/merge-models \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/modem_AT-wrapper \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-network-repair \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/runtime-stack \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/legacy-bus \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-at \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-port \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-fcc-unlock \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-esim-sdk \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/ensure-option-ids \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/tethering-overlay \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-boot-restore \
		/repo/package/gl-modem-community/files/usr/share/gl-modem-community/esim-http/sdk/v1 \
		/repo/tests/lib/run-lua.sh \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-qmi \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-band-monitor \
		/repo/package/gl-modem-community/files/etc/hotplug.d/usb/99-gl-modem-community \
		/repo/package/gl-modem-community/files/lib/netifd/proto/xmm.sh
    actionlint /repo/.github/workflows/*.yml
    jq -e ".modems | length == 2" /repo/package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/fm350.json >/dev/null
    jq -e ".modems | length == 1" /repo/package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/vos5g.json >/dev/null
    lua5.1 /repo/tests/test-vos5g-rpc.lua /repo
    lua5.1 /repo/tests/test-vos5g-qmi-rf-band.lua /repo
    lua5.1 /repo/tests/test-vos5g-qmi-system-mode.lua /repo
    GL_MODEM_COMMUNITY_RPC_DRIVER_DIR=/repo/package/gl-modem-community/files/usr/share/gl-modem-community/rpc-drivers \
        GL_MODEM_COMMUNITY_SYSFS_USB_ROOT=/tmp/gl-modem-community-rpc-sysfs \
        GL_MODEM_COMMUNITY_RUNTIME_DIR=/tmp/gl-modem-community-rpc-runtime \
        lua5.1 /repo/tests/test-rpc-dispatcher.lua /repo
    /repo/tests/test-sbom.sh
    /repo/tests/test-signing-key.sh
'
echo "Container tests passed"

run_test() {
	echo "Running $1..."
	"$1"
	echo "$1 passed"
}

run_test "$REPO_DIR/tests/test-fm350-at-compat.sh"
run_test "$REPO_DIR/tests/test-vos5g-at-compat.sh"
run_test "$REPO_DIR/tests/test-vos5g-modem-at-wrapper.sh"
run_test "$REPO_DIR/tests/test-hardware-evidence.sh"
run_test "$REPO_DIR/tests/test-xmm-proto.sh"
run_test "$REPO_DIR/tests/test-network-repair.sh"
run_test "$REPO_DIR/tests/test-network-ownership.sh"
run_test "$REPO_DIR/tests/test-network-reenumeration.sh"
run_test "$REPO_DIR/tests/test-package-lifecycle.sh"
run_test "$REPO_DIR/tests/test-service-lifecycle.sh"
run_test "$REPO_DIR/tests/test-release-config.sh"
run_test "$REPO_DIR/tests/test-feed-index.sh"
run_test "$REPO_DIR/tests/test-assemble-release-feeds.sh"
run_test "$REPO_DIR/tests/test-firmware-channels.sh"
run_test "$REPO_DIR/tests/test-runtime-stack.sh"
run_test "$REPO_DIR/tests/test-legacy-bus.sh"
run_test "$REPO_DIR/tests/test-usb-hotplug.sh"
run_test "$REPO_DIR/tests/test-fm350-at.sh"
run_test "$REPO_DIR/tests/test-fm350-port.sh"
run_test "$REPO_DIR/tests/test-hotplug-product.sh"
run_test "$REPO_DIR/tests/test-fm350-fcc-unlock.sh"
run_test "$REPO_DIR/tests/test-xmm-available.sh"
run_test "$REPO_DIR/tests/test-fm350-gcom.sh"
run_test "$REPO_DIR/tests/test-fm350-rpc.sh"
run_test "$REPO_DIR/tests/test-fm350-esim-sdk.sh"
run_test "$REPO_DIR/tests/test-fm350-esim-http.sh"
run_test "$REPO_DIR/tests/test-fm350-esim-gate.sh"
run_test "$REPO_DIR/tests/test-fm350-esim-menu.sh"
run_test "$REPO_DIR/tests/test-tethering-overlay.sh"
run_test "$REPO_DIR/tests/test-ensure-option-ids.sh"
run_test "$REPO_DIR/tests/test-fm350-boot-restore.sh"
run_test "$REPO_DIR/tests/test-vos5g-qmi.sh"
run_test "$REPO_DIR/tests/test-vos5g-band-monitor.sh"
run_test "$REPO_DIR/tests/test-unified-channels.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-community-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
printf '%s\n' '{"modems":[{"bus_type":"USB","vid":"2c7c","pid":"0801","name":"stock"}]}' > "$tmp/base.json"
"$PACKAGE/files/usr/libexec/gl-modem-community/merge-models" \
	"$tmp/base.json" "$PACKAGE/files/usr/share/gl-modem-community/drivers.d" "$tmp/merged.json"
jq -e '.modems | length == 4' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "0e8d" and .pid == "7126") | .supports_proto == ["xmm"]' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "0e8d" and .pid == "7126") | .supports_port == [{"port_type":"USB","port_name":"ttyUSB","port_offset_at":2}]' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "0e8d" and .pid == "7127") | .supports_port == [{"port_type":"USB","port_name":"ttyUSB","port_offset_at":3}]' "$tmp/merged.json" >/dev/null
! grep -R "ttyACM" "$PACKAGE/files/usr/share/gl-modem-community/drivers.d"
jq -e '.modems[] | select(.vid == "2c7c" and .pid == "0801") | .name == "stock"' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "05c6" and .pid == "9064") | .supports_proto == ["qmi"]' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "05c6" and .pid == "9064") | .supports_port == [{"port_type":"USB","port_name":"ttyUSB","port_offset_at":2},{"port_type":"WDM","port_name":"cdc-wdm","port_offset_qmi":0}]' "$tmp/merged.json" >/dev/null

printf '%s\n' 'All offline tests passed.'
