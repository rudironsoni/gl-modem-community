#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
state="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-state"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-vos5g-state.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/usb/2-1" "$tmp/net/usb0/statistics"
printf '%s\n' 05c6 >"$tmp/usb/2-1/idVendor"
printf '%s\n' 9064 >"$tmp/usb/2-1/idProduct"
printf '%s\n' 125000 >"$tmp/net/usb0/statistics/rx_bytes"
printf '%s\n' 75000 >"$tmp/net/usb0/statistics/tx_bytes"

cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
key=${3:-}
case "$key" in
gl_modem_community.vos5g.enabled) printf '%s\n' 1 ;;
gl_modem_community.vos5g.mode) printf '%s\n' ecm ;;
gl_modem_community.vos5g.management_url) printf '%s\n' https://192.168.225.1 ;;
gl_modem_community.vos5g.username) printf '%s\n' admin ;;
gl_modem_community.vos5g.password_cipher) printf '%s\n' encrypted-for-test ;;
gl_modem_community.vos5g.apn) printf '%s\n' '' ;;
*) exit 1 ;;
esac
EOF

cat >"$tmp/bin/ubus" <<'EOF'
#!/bin/sh
if [ "${MOCK_TETHERING_UP:-1}" = 1 ]; then
	printf '%s\n' '{"up":true,"l3_device":"usb0"}'
else
	printf '%s\n' '{"up":false,"l3_device":"usb0"}'
fi
EOF

cat >"$tmp/bin/curl" <<'EOF'
#!/bin/sh
[ "${MOCK_API_DOWN:-0}" != 1 ] || {
	printf '%s\n' '{}'
	exit 0
}
page=
login=0
for arg in "$@"; do
	case "$arg" in
	*/cgi-bin/qcmap_auth) login=1 ;;
	Page=*) page=${arg#Page=} ;;
	esac
done
if [ "$login" -eq 1 ]; then
	printf '%s\n' '{"result":"0","token":"test-token"}'
	exit 0
fi
case "$page" in
GetHomePageInfo)
	printf '%s\n' '{"network_signal_strength_result":"SUCCESS","network_signal_strength_lte":"-109","network_signal_strength_nr5g":"-92"}' ;;
GetServingInfo)
	# The validated firmware labels the Canadian MCC and MNC in reverse.
	printf '%s\n' '{"serving_system_result":"SUCCESS","operator_name":"TELUS","mcc":"220","mnc":"302"}' ;;
GetBandInfo)
	printf '%s\n' '{"connection_result":"SUCCESS","radio_if":"LTE","band":"LTE BAND 2","nr5g_radio_if":"NR5G","nr5g_band":"NR5G BAND 78","channel":"633984"}' ;;
GetSimCardStatus)
	printf '%s\n' '{"get_sim_card_status_result":"SUCCESS","get_sim_card_status":"READY"}' ;;
GetSimIMSI)
	printf '%s\n' '{"get_sim_card_imsi_result":"SUCCESS","get_sim_card_imsi":"001010000000001"}' ;;
GetSimMSISDN)
	printf '%s\n' '{"get_sim_card_msisdn_result":"SUCCESS","get_sim_card_msisdn":"15550000000"}' ;;
GetSimICCID)
	printf '%s\n' '{"get_sim_card_iccid_result":"SUCCESS","get_sim_card_iccid":"8901000000000000000"}' ;;
GetModuleVer)
	printf '%s\n' '{"get_module_ver_result":"SUCCESS","get_module_ver":"MV31-W test"}' ;;
GetApnProfile)
	printf '%s\n' '{"apn_name":"sp.telus.com","pdp_type":"IPV4V6","profile_index":"1"}' ;;
*) printf '%s\n' '{}' ;;
esac
EOF
chmod +x "$tmp/bin/"*

RUNTIME_DIR="$tmp/runtime" \
CURL="$tmp/bin/curl" \
UBUS="$tmp/bin/ubus" \
UCI="$tmp/bin/uci" \
SYS_USB="$tmp/usb" \
SYS_NET="$tmp/net" \
	"$state" >"$tmp/state.json"

jq -e '.present == true and .bus == "2-1" and .mode == "ecm"' "$tmp/state.json" >/dev/null
jq -e '.telemetry.band == "NR5G BAND 78, LTE BAND 2" and .telemetry.channel == "633984"' "$tmp/state.json" >/dev/null
jq -e '.sim_status.carrier == "TELUS · NR5G BAND 78, LTE BAND 2"' "$tmp/state.json" >/dev/null
jq -e '.sim_info.mcc == "302" and .sim_info.mnc == "220" and .sim_status.apn == "sp.telus.com"' "$tmp/state.json" >/dev/null
jq -e '.sim_status.status == 2 and .sim_status.strength == 4 and .sim_status.technology == 5' "$tmp/state.json" >/dev/null
jq -e '.network_status.status == 0 and .network_status.dial_status == 0 and .network_status.traffic_total == "200000"' "$tmp/state.json" >/dev/null
jq -e '.modem_info.type == 1 and .modem_info.protocols == ["ecm"] and .modem_info.devices == ["usb0"]' "$tmp/state.json" >/dev/null

cp "$tmp/state.json" "$tmp/runtime/vos5g-state.json"
MOCK_TETHERING_UP=0 MOCK_API_DOWN=1 \
RUNTIME_DIR="$tmp/runtime" \
CURL="$tmp/bin/curl" \
UBUS="$tmp/bin/ubus" \
UCI="$tmp/bin/uci" \
SYS_USB="$tmp/usb" \
SYS_NET="$tmp/net" \
	"$state" >"$tmp/disconnected.json"
jq -e '.sim_status.status == 2 and .sim_status.carrier == "TELUS · NR5G BAND 78, LTE BAND 2"' "$tmp/disconnected.json" >/dev/null
jq -e '.network_status.status == 2 and .network_status.dial_status == 0' "$tmp/disconnected.json" >/dev/null

printf '%s\n' stale-token >"$tmp/runtime/vos5g-token"
printf '%s\n' stale-cookie >"$tmp/runtime/vos5g-cookie.txt"
RUNTIME_DIR="$tmp/runtime" CURL="$tmp/bin/curl" UCI="$tmp/bin/uci" \
	"$state" --logout
test ! -e "$tmp/runtime/vos5g-token"
test ! -e "$tmp/runtime/vos5g-cookie.txt"

rm -rf "$tmp/usb/2-1"
RUNTIME_DIR="$tmp/runtime" \
CURL="$tmp/bin/curl" \
UBUS="$tmp/bin/ubus" \
UCI="$tmp/bin/uci" \
SYS_USB="$tmp/usb" \
SYS_NET="$tmp/net" \
	"$state" >"$tmp/absent.json"
jq -e '.present == false' "$tmp/absent.json" >/dev/null
