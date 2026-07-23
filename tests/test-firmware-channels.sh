#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$repo_dir/config/firmware-channels.json"
makefile="$repo_dir/Makefile"

jq -e '
	.schema_version == 1 and
	.device == "GL.iNet GL-MT3000" and
	.support_policy == "current-channel-heads" and
	([.channels[].channel] | sort) ==
		(["stable", "beta", "openwrt24", "openwrt25"] | sort) and
	all(.channels[];
		(.artifact.sha256 | test("^[0-9a-f]{64}$")) and
		(.artifact.size | type == "number" and . > 0) and
		(.firmware.architecture == "aarch64_cortex-a53") and
		(.firmware.package_manager == "opkg" or .firmware.package_manager == "apk") and
		(.firmware.cellular_stack == "legacy" or .firmware.cellular_stack == "modern")
	) and
	([.channels[] | select(.channel == "stable" or .channel == "beta") | .package_profile] | unique) ==
		["glinet21"] and
	(.channels[] | select(.channel == "stable") |
		.firmware.openwrt_release == "21.02-SNAPSHOT" and
		.firmware.cellular_stack == "legacy") and
	(.channels[] | select(.channel == "beta") |
		.firmware.openwrt_release == "21.02-SNAPSHOT" and
		.firmware.cellular_stack == "modern") and
	(.channels[] | select(.channel == "openwrt24") |
		.firmware.openwrt_release == "24.10.4 r28959-29397011cc") and
	(.channels[] | select(.channel == "openwrt25") |
		.firmware.openwrt_release == "25.12.5 r33051-f5dae5ece4")
' "$manifest" >/dev/null

grep -Fq 'package-glinet21:' "$makefile"
grep -Fq 'check-firmware-channels:' "$makefile"
grep -Fq 'verify-firmware-channels:' "$makefile"
grep -Fq 'openwrt-sdk-24.10.4-mediatek-filogic' "$makefile"
grep -Fq 'openwrt-sdk-21.02.7-mediatek-mt7622' "$makefile"
test ! -d "$repo_dir/scripts"
