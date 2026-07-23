#!/bin/sh
set -eu

duration=180
interval=2
probe_url=
expected_code=204
output=

while [ "$#" -gt 0 ]; do
	case "$1" in
		--duration) duration=${2:?}; shift 2 ;;
		--interval) interval=${2:?}; shift 2 ;;
		--probe-url) probe_url=${2:?}; shift 2 ;;
		--expected-code) expected_code=${2:?}; shift 2 ;;
		--output) output=${2:?}; shift 2 ;;
		*) echo "Unknown argument: $1" >&2; exit 2 ;;
	esac
done

[ -n "$probe_url" ] || { echo "--probe-url is required" >&2; exit 2; }
[ -n "$output" ] || { echo "--output is required" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 2; }

start=$(date +%s)
end=$((start + duration))
printf 'ts_epoch,ts_iso,status,http_code\n' >"$output"

while :; do
	now=$(date +%s)
	iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
	code=$(curl --silent --show-error --output /dev/null \
		--max-time "$interval" --write-out '%{http_code}' "$probe_url" 2>/dev/null || printf '000')
	case "$code" in
		"$expected_code") status=online ;;
		*) status=offline ;;
	esac
	printf '%s,%s,%s,%s\n' "$now" "$iso" "$status" "$code" >>"$output"
	[ "$now" -ge "$end" ] && break
	sleep "$interval"
done
