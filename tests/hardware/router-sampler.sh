#!/bin/sh
set -eu

duration=180
interval=2
interface=
output=

while [ "$#" -gt 0 ]; do
	case "$1" in
		--duration) duration=${2:?}; shift 2 ;;
		--interval) interval=${2:?}; shift 2 ;;
		--interface) interface=${2:?}; shift 2 ;;
		--output) output=${2:?}; shift 2 ;;
		*) echo "Unknown argument: $1" >&2; exit 2 ;;
	esac
done

[ -n "$output" ] || { echo "--output is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

start=$(date +%s)
end=$((start + duration))
: >"$output"

while :; do
	now=$(date +%s)
	iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
	service_running=false
	/etc/init.d/gl_modem_community running >/dev/null 2>&1 && service_running=true
	model_table_mounted=false
	grep -F ' /lib/modem_data/modem_list.json ' /proc/mounts >/dev/null 2>&1 && model_table_mounted=true
	modem_at_mounted=false
	grep -F ' /usr/bin/modem_AT ' /proc/mounts >/dev/null 2>&1 && modem_at_mounted=true
	usb_ids=$(
		for path in /sys/bus/usb/devices/*; do
			[ -r "$path/idVendor" ] && [ -r "$path/idProduct" ] || continue
			printf '%s:%s ' "$(cat "$path/idVendor")" "$(cat "$path/idProduct")"
		done
	)
	default_routes=$(ip route show default 2>/dev/null || true)
	dns_state=$(cat /tmp/resolv.conf.d/resolv.conf.auto 2>/dev/null || true)
	network_status='{}'
	if [ -n "$interface" ]; then
		network_status=$(ubus call "network.interface.$interface" status 2>/dev/null || printf '{}')
		printf '%s' "$network_status" | jq -e . >/dev/null 2>&1 || network_status='{}'
	fi

	jq -cn \
		--argjson ts_epoch "$now" \
		--arg ts_iso "$iso" \
		--argjson service_running "$service_running" \
		--argjson model_table_mounted "$model_table_mounted" \
		--argjson modem_at_mounted "$modem_at_mounted" \
		--arg usb_ids "$usb_ids" \
		--arg default_routes "$default_routes" \
		--arg dns_state "$dns_state" \
		--argjson network_status "$network_status" \
		'{
			ts_epoch: $ts_epoch,
			ts_iso: $ts_iso,
			service_running: $service_running,
			model_table_mounted: $model_table_mounted,
			modem_at_mounted: $modem_at_mounted,
			usb_ids: $usb_ids,
			default_routes: $default_routes,
			dns_state: $dns_state,
			network_status: $network_status
		}' >>"$output"

	[ "$now" -ge "$end" ] && break
	sleep "$interval"
done
