#!/bin/sh
set -eu

client=
router=
expectation=
output=

while [ "$#" -gt 0 ]; do
	case "$1" in
		--client) client=${2:?}; shift 2 ;;
		--router) router=${2:?}; shift 2 ;;
		--expect) expectation=${2:?}; shift 2 ;;
		--output) output=${2:?}; shift 2 ;;
		*) echo "Unknown argument: $1" >&2; exit 2 ;;
	esac
done

[ -s "$client" ] || { echo "Missing client CSV: $client" >&2; exit 2; }
[ -s "$router" ] || { echo "Missing router JSONL: $router" >&2; exit 2; }
[ -n "$output" ] || { echo "--output is required" >&2; exit 2; }
jq -e . "$router" >/dev/null

client_samples=$(awk 'NR > 1 { count++ } END { print count + 0 }' "$client")
online_samples=$(awk -F, 'NR > 1 && $3 == "online" { count++ } END { print count + 0 }' "$client")
offline_samples=$(awk -F, 'NR > 1 && $3 == "offline" { count++ } END { print count + 0 }' "$client")
final_status=$(awk -F, 'NR > 1 { status = $3 } END { print status }' "$client")
router_samples=$(wc -l <"$router" | tr -d ' ')
verdict=FAIL

case "$expectation" in
	all-online)
		[ "$client_samples" -gt 0 ] && [ "$offline_samples" -eq 0 ] && verdict=PASS
		;;
	all-offline)
		[ "$client_samples" -gt 0 ] && [ "$online_samples" -eq 0 ] && verdict=PASS
		;;
	final-online)
		[ "$client_samples" -gt 0 ] && [ "$final_status" = online ] && verdict=PASS
		;;
	transition-recovered)
		[ "$offline_samples" -gt 0 ] && [ "$final_status" = online ] && verdict=PASS
		;;
	*)
		echo "Unsupported expectation: $expectation" >&2
		exit 2
		;;
esac

jq -n \
	--arg verdict "$verdict" \
	--arg expectation "$expectation" \
	--arg final_status "$final_status" \
	--argjson client_samples "$client_samples" \
	--argjson router_samples "$router_samples" \
	--argjson online_samples "$online_samples" \
	--argjson offline_samples "$offline_samples" \
	'{
		verdict: $verdict,
		expectation: $expectation,
		client_samples: $client_samples,
		router_samples: $router_samples,
		online_samples: $online_samples,
		offline_samples: $offline_samples,
		final_status: $final_status
	}' >"$output"

[ "$verdict" = PASS ]
