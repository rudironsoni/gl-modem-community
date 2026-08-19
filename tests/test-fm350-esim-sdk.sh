#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-esim-sdk"
launcher="$repo_dir/package/gl-modem-community/files/usr/share/gl-modem-community/esim-http/sdk/v1"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-esim-sdk.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys/2-1" "$tmp/bin" "$tmp/lib"
command -v jq >/dev/null 2>&1 || {
	echo 'jq is required for esim sdk tests' >&2
	exit 1
}
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"

cat >"$tmp/bin/fm350-port" <<'EOF'
#!/bin/sh
printf '%s\n' /dev/ttyUSB4
EOF

cat >"$tmp/profiles.json" <<'EOF'
{"type":"lpa","payload":{"code":0,"data":[]}}
EOF

cat >"$tmp/bin/fake-lpac" <<'EOF'
#!/bin/sh
set -eu
store=${LPAC_STORE:?}
printf '%s\n' "APDU=${LPAC_APDU:-} DEVICE=${LPAC_APDU_AT_DEVICE:-} MSS=${LPAC_CUSTOM_ES10X_MSS:-} $*" >>"${LPAC_ARGV_LOG:?}"
case "${1:-} ${2:-}" in
"chip info")
	printf '%s\n' '{"type":"lpa","payload":{"code":0,"data":{"eidValue":"89033023400000000000000000000000"}}}'
	;;
"profile list")
	cat "$store"
	;;
"profile enable")
	iccid=$3
	jq --arg iccid "$iccid" '
		.payload.data |= map(if .iccid == $iccid then .profileState = "enabled" else .profileState = "disabled" end)
	' "$store" >"$store.next"
	mv "$store.next" "$store"
	printf '%s\n' '{"type":"lpa","payload":{"code":0,"data":{}}}'
	;;
"profile disable")
	iccid=$3
	jq --arg iccid "$iccid" '
		.payload.data |= map(if .iccid == $iccid then .profileState = "disabled" else . end)
	' "$store" >"$store.next"
	mv "$store.next" "$store"
	printf '%s\n' '{"type":"lpa","payload":{"code":0,"data":{}}}'
	;;
"profile delete")
	iccid=$3
	jq --arg iccid "$iccid" '
		.payload.data |= map(select(.iccid != $iccid))
	' "$store" >"$store.next"
	mv "$store.next" "$store"
	printf '%s\n' '{"type":"lpa","payload":{"code":0,"data":{}}}'
	;;
"profile nickname")
	iccid=$3
	name=$4
	jq --arg iccid "$iccid" --arg name "$name" '
		.payload.data |= map(if .iccid == $iccid then .profileNickname = $name else . end)
	' "$store" >"$store.next"
	mv "$store.next" "$store"
	printf '%s\n' '{"type":"lpa","payload":{"code":0,"data":{}}}'
	;;
"profile download")
	printf '%s\n' '{"type":"lpa","payload":{"code":0,"data":[{"iccid":"8903302341111111111","profileName":"O2","profileState":"disabled","profileClass":"operational"}]}}' >"$store"
	printf '%s\n' '{"type":"lpa","payload":{"code":0,"data":{}}}'
	;;
*)
	exit 1
	;;
esac
EOF
chmod +x "$tmp/bin/"*

cat >"$tmp/profiles.json" <<'EOF'
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "data": [
      {
        "iccid": "8903302341111111111",
        "profileName": "O2",
        "profileNickname": "",
        "profileState": "enabled",
        "profileClass": "operational"
      }
    ]
  }
}
EOF

run_sdk() {
	USB_DEVICES_ROOT="$tmp/sys" \
	PORT_BIN="$tmp/bin/fm350-port" \
	JQ_BIN=jq \
	LPAC_BIN="$tmp/bin/fake-lpac" \
	LPAC_LOCK="$tmp/lpac.lock" \
	LPAC_LIB_PATH="$tmp/lib" \
	LPAC_STORE="$tmp/profiles.json" \
	LPAC_ARGV_LOG="$tmp/lpac.argv" \
	LOG_FILE="$tmp/esim.log" \
	PROGRESS_FILE="$tmp/progress.json" \
	FLOCK_BIN=flock \
		"$helper" "$1"
}

grep -F 'exec /usr/libexec/gl-modem-community/fm350-esim-sdk' "$launcher" >/dev/null

status=$(run_sdk '{"method":"status","env":1}')
printf '%s\n' "$status" | jq -e '.code == 200' >/dev/null
printf '%s\n' "$status" | jq -e '.data.eid == "89033023400000000000000000000000"' >/dev/null
printf '%s\n' "$status" | jq -e '.data.profile_list[0].state == 1' >/dev/null
printf '%s\n' "$status" | jq -e '.data.profile_list[0].class == 2' >/dev/null
printf '%s\n' "$status" | jq -e '.data.env.iccid == "8903302341111111111"' >/dev/null

enable=$(run_sdk '{"method":"disable","iccid":"8903302341111111111"}')
printf '%s\n' "$enable" | jq -e '.code == 200' >/dev/null
status=$(run_sdk '{"method":"status"}')
printf '%s\n' "$status" | jq -e '.data.profile_list[0].state == 0' >/dev/null

enable=$(run_sdk '{"method":"enable","iccid":"8903302341111111111"}')
printf '%s\n' "$enable" | jq -e '.code == 200' >/dev/null

nick=$(run_sdk '{"method":"nick","iccid":"8903302341111111111","name":"Travel"}')
printf '%s\n' "$nick" | jq -e '.code == 200' >/dev/null

install=$(run_sdk '{"method":"install","ac_code":"LPA:1$example$secret","cf_code":"confirm-secret"}')
printf '%s\n' "$install" | jq -e '.code == 200' >/dev/null
if printf '%s\n' "$install" | grep -E 'secret|confirm-secret' >/dev/null; then
	echo 'activation or confirmation code leaked from esim sdk output' >&2
	exit 1
fi
if grep -E 'secret|confirm-secret' "$tmp/esim.log" >/dev/null 2>&1; then
	echo 'activation or confirmation code leaked into esim log' >&2
	exit 1
fi

progress=$(run_sdk '{"method":"progress"}')
printf '%s\n' "$progress" | jq -e '.data.ratio == 100' >/dev/null
printf '%s\n' "$progress" | jq -e '.data | has("ac_code") and has("hint") and has("progress")' >/dev/null

delete=$(run_sdk '{"method":"delete","iccid":"8903302341111111111"}')
printf '%s\n' "$delete" | jq -e '.code == 200' >/dev/null

grep -F 'APDU=at' "$tmp/lpac.argv" >/dev/null
grep -F 'DEVICE=/dev/ttyUSB4' "$tmp/lpac.argv" >/dev/null
grep -F 'MSS=80' "$tmp/lpac.argv" >/dev/null
! grep -F 'AT_DEVICE=' "$tmp/lpac.argv" >/dev/null

# Missing lpac still returns an empty status and does not leak codes.
USB_DEVICES_ROOT="$tmp/sys" \
PORT_BIN="$tmp/bin/fm350-port" \
JQ_BIN=jq \
LPAC_BIN="$tmp/missing-lpac" \
LOG_FILE="$tmp/esim.log" \
	"$helper" '{"method":"install","activationCode":"LPA:1$example$secret"}' \
	| jq -e '.code == 600' >/dev/null
