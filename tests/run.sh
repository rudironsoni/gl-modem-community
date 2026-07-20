#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=mt3000-modem-analysis:2026-07-19
PACKAGE="$REPO_DIR/package/gl-modem-community"

docker run --rm --mount "type=bind,src=$REPO_DIR,dst=/repo" "$IMAGE" sh -c '
set -eu
find /repo/scripts /repo/tests /repo/package/gl-modem-community/files -type f -perm /111 -exec sh -n {} \;
find /repo/package/gl-modem-community/files -type f -name "*.lua" -exec luac5.1 -p {} \;
shellcheck -S warning -e SC1091,SC2034,SC3043 /repo/scripts/*.sh /repo/tests/*.sh \
		/repo/package/gl-modem-community/files/etc/init.d/gl_modem_community \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/merge-models \
		/repo/package/gl-modem-community/files/usr/libexec/gl-modem-community/modem_AT-wrapper \
		/repo/package/gl-modem-community/files/lib/netifd/proto/xmm.sh
jq -e ".modems | length == 2" /repo/package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/fm350.json >/dev/null
'

"$REPO_DIR/tests/test-fm350-at-compat.sh"
"$REPO_DIR/tests/test-xmm-proto.sh"
"$REPO_DIR/tests/test-network-repair.sh"
"$REPO_DIR/tests/test-release-config.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-community-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
printf '%s\n' '{"modems":[{"bus_type":"USB","vid":"2c7c","pid":"0801","name":"stock"}]}' > "$tmp/base.json"
"$PACKAGE/files/usr/libexec/gl-modem-community/merge-models" \
	"$tmp/base.json" "$PACKAGE/files/usr/share/gl-modem-community/drivers.d" "$tmp/merged.json"
jq -e '.modems | length == 3' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "0e8d" and .pid == "7126") | .supports_proto == ["xmm"]' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "0e8d" and .pid == "7126") | .supports_port == [{"port_type":"USB","port_name":"ttyUSB","port_offset_at":2}]' "$tmp/merged.json" >/dev/null
jq -e '.modems[] | select(.vid == "0e8d" and .pid == "7127") | .supports_port == [{"port_type":"USB","port_name":"ttyUSB","port_offset_at":3}]' "$tmp/merged.json" >/dev/null
! grep -R "ttyACM" "$PACKAGE/files/usr/share/gl-modem-community/drivers.d"
jq -e '.modems[] | select(.vid == "2c7c" and .pid == "0801") | .name == "stock"' "$tmp/merged.json" >/dev/null

printf '%s\n' 'All offline tests passed.'
