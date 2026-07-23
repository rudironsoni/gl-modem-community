#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
analyzer="$repo_dir/tests/hardware/analyze-run.sh"
issue_form="$repo_dir/.github/ISSUE_TEMPLATE/modem-compatibility.yml"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-hardware-evidence.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

test -x "$analyzer"
test -s "$issue_form"
for field in router-model firmware-version package-manager package-version \
	modem-model modem-firmware usb-ids usb-composition tests evidence; do
	grep -Fq "id: $field" "$issue_form"
done

cat >"$tmp/client.csv" <<'EOF'
ts_epoch,ts_iso,status,http_code
100,1970-01-01T00:01:40Z,online,204
101,1970-01-01T00:01:41Z,offline,000
102,1970-01-01T00:01:42Z,online,204
EOF
cat >"$tmp/router.jsonl" <<'EOF'
{"ts_epoch":100,"service_running":true,"model_table_mounted":true,"modem_at_mounted":true}
{"ts_epoch":101,"service_running":true,"model_table_mounted":true,"modem_at_mounted":true}
{"ts_epoch":102,"service_running":true,"model_table_mounted":true,"modem_at_mounted":true}
EOF

"$analyzer" \
	--client "$tmp/client.csv" \
	--router "$tmp/router.jsonl" \
	--expect transition-recovered \
	--output "$tmp/summary.json"

jq -e '
	.verdict == "PASS" and
	.expectation == "transition-recovered" and
	.client_samples == 3 and
	.router_samples == 3 and
	.offline_samples == 1 and
	.final_status == "online"
' "$tmp/summary.json" >/dev/null
