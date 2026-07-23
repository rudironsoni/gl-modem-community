SHELL := /bin/sh
.SHELLFLAGS := -eu -c

ifneq ($(filter 3.80 3.81,$(MAKE_VERSION)),)
$(error GNU Make 3.82 or newer is required; use gmake on macOS)
endif

.ONESHELL:
.SILENT:

REPO_DIR := $(CURDIR)
ANALYSIS_DIR := $(REPO_DIR)/analysis
FIRMWARE_DIR := $(REPO_DIR)/firmware
WORK_DIR := $(REPO_DIR)/work
EXTRACT_DIR := $(REPO_DIR)/extracted
FIRMWARE_NAME := mt3000-op-4.9.1-op25_beta3-1035-0721-1784638698.bin
FIRMWARE_URL := https://fw.gl-inet.com/firmware/mt3000-open/testing/$(FIRMWARE_NAME)
FIRMWARE_PATH := $(FIRMWARE_DIR)/$(FIRMWARE_NAME)
ANALYSIS_IMAGE := mt3000-modem-analysis:2026-07-19
PACKAGE_VERSION := $(shell sed -n 's/^PKG_VERSION:=//p' package/gl-modem-community/Makefile)
PACKAGE_RELEASE := $(shell sed -n 's/^PKG_RELEASE:=//p' package/gl-modem-community/Makefile)
CHANNEL_MANIFEST := $(REPO_DIR)/config/firmware-channels.json

.PHONY: tools download verify identify extract inventory inventory-filesystem
.PHONY: inventory-packages find-modem-components analyze analyze-frontend
.PHONY: analyze-elf extract-strings report test package package-opkg
.PHONY: package-glinet21 check-firmware-channels verify-firmware-channels
.PHONY: generate-sbom validate-sbom verify-signing-key sign-apk-release clean-work

tools:
	docker build -t $(ANALYSIS_IMAGE) tools/analysis-container

download:
	mkdir -p "$(FIRMWARE_DIR)" "$(ANALYSIS_DIR)/hashes" "$(ANALYSIS_DIR)/reports"
	tmp="$(FIRMWARE_PATH).partial"
	curl --fail --location --retry 2 --connect-timeout 20 \
		--user-agent 'Mozilla/5.0 mt3000-gl-modem-research/1.0' \
		--dump-header "$(ANALYSIS_DIR)/reports/firmware-http-headers.txt" \
		--output "$$tmp" "$(FIRMWARE_URL)"
	mv "$$tmp" "$(FIRMWARE_PATH)"
	date -u '+%Y-%m-%dT%H:%M:%SZ' >"$(ANALYSIS_DIR)/reports/firmware-retrieved-utc.txt"
	printf '%s\n' "$(FIRMWARE_URL)" >"$(ANALYSIS_DIR)/reports/firmware-url.txt"

verify:
	test -f "$(FIRMWARE_PATH)"
	mkdir -p "$(ANALYSIS_DIR)/hashes" "$(ANALYSIS_DIR)/reports"
	wc -c <"$(FIRMWARE_PATH)" | tr -d ' ' >"$(ANALYSIS_DIR)/hashes/firmware.size"
	shasum -a 256 "$(FIRMWARE_PATH)" |
		sed "s# $(FIRMWARE_PATH)# firmware/$(FIRMWARE_NAME)#" >"$(ANALYSIS_DIR)/hashes/firmware.sha256"
	shasum -a 512 "$(FIRMWARE_PATH)" |
		sed "s# $(FIRMWARE_PATH)# firmware/$(FIRMWARE_NAME)#" >"$(ANALYSIS_DIR)/hashes/firmware.sha512"
	docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(ANALYSIS_IMAGE)" sh -c \
		'b2sum /repo/firmware/$(FIRMWARE_NAME) | sed "s#/repo/##"' \
		>"$(ANALYSIS_DIR)/hashes/firmware.blake2b512"
	file "$(FIRMWARE_PATH)" |
		sed "s#^$(FIRMWARE_PATH)#firmware/$(FIRMWARE_NAME)#" >"$(ANALYSIS_DIR)/reports/firmware-file.txt"

identify:
	test -f "$(FIRMWARE_PATH)"
	mkdir -p "$(ANALYSIS_DIR)/reports" "$(WORK_DIR)/identify"
	tar -tvf "$(FIRMWARE_PATH)" >"$(ANALYSIS_DIR)/reports/outer-tar-list.txt"
	docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(ANALYSIS_IMAGE)" sh -c \
		'binwalk /repo/firmware/$(FIRMWARE_NAME) > /repo/analysis/reports/binwalk.txt 2>&1 || true'
	tar -xf "$(FIRMWARE_PATH)" -C "$(WORK_DIR)/identify"
	docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(ANALYSIS_IMAGE)" sh -c \
		'find /repo/work/identify -type f -exec file {} \; | sort > /repo/analysis/reports/container-files.txt'

extract:
	test -f "$(FIRMWARE_PATH)"
	rm_target="$(WORK_DIR)/extraction-new"
	rm -rf "$$rm_target"
	mkdir -p "$$rm_target/outer" "$$rm_target/rootfs" "$$rm_target/fit"
	tar -xf "$(FIRMWARE_PATH)" -C "$$rm_target/outer"
	root_image=$$(find "$$rm_target/outer" -type f -name root -print | head -n 1)
	kernel_image=$$(find "$$rm_target/outer" -type f -name kernel -print | head -n 1)
	test -n "$$root_image"
	test -n "$$kernel_image"
	root_container=$$(printf '%s' "$$root_image" | sed "s#^$(REPO_DIR)#/repo#")
	kernel_container=$$(printf '%s' "$$kernel_image" | sed "s#^$(REPO_DIR)#/repo#")
	docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(ANALYSIS_IMAGE)" sh -c \
		"set -eu
		mkdir -p /case-root /repo/work/extraction-new/rootfs
		unsquashfs -no-progress -d /case-root '$$root_container'
		tar -C /case-root -cf /repo/work/extraction-new/rootfs.tar .
		dumpimage -l '$$kernel_container' > /repo/analysis/reports/fit-list.txt"
	rm -rf "$(EXTRACT_DIR)"
	mkdir -p "$(EXTRACT_DIR)/rootfs"
	tar --exclude='./dev/*' -xf "$$rm_target/rootfs.tar" -C "$(EXTRACT_DIR)/rootfs"
	cp -R "$$rm_target/outer" "$(EXTRACT_DIR)/outer"
	printf '%s\n' "$${root_image#$(REPO_DIR)/}" >"$(ANALYSIS_DIR)/reports/root-image-source.txt"
	printf '%s\n' "$${kernel_image#$(REPO_DIR)/}" >"$(ANALYSIS_DIR)/reports/kernel-image-source.txt"

inventory: inventory-filesystem inventory-packages find-modem-components

inventory-filesystem:
	root="$(EXTRACT_DIR)/rootfs"
	test -d "$$root"
	mkdir -p "$(ANALYSIS_DIR)/manifests" "$(ANALYSIS_DIR)/configs"
	docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(ANALYSIS_IMAGE)" sh -c '
		set -eu
		cd /repo/extracted/rootfs
		find . -printf "%M\t%U\t%G\t%s\t%y\t%p\t%l\n" | LC_ALL=C sort > /repo/analysis/manifests/filesystem.tsv
		find . -type f -exec file {} + | LC_ALL=C sort > /repo/analysis/manifests/file-types.txt
		find . -type f -exec sh -c '"'"'for f do file "$$f" | grep -q "ELF" && printf "%s\n" "$$f"; done'"'"' sh {} + |
			LC_ALL=C sort > /repo/analysis/manifests/elf-paths.txt
		find . -type f \( -name "*.sh" -o -name "*.lua" -o -name "*.uc" -o -name "*.js" -o -name "*.json" \) |
			LC_ALL=C sort > /repo/analysis/manifests/source-like-paths.txt
		'
	for path in etc/openwrt_release etc/os-release etc/config/cellular etc/config/glmodem lib/modem_data/modem_list.json; do
		if test -f "$$root/$$path"; then
			dest=$$(printf '%s' "$$path" | tr '/' '_')
			cp "$$root/$$path" "$(ANALYSIS_DIR)/configs/$$dest"
		fi
	done

inventory-packages:
	root="$(EXTRACT_DIR)/rootfs"
	test -d "$$root"
	mkdir -p "$(ANALYSIS_DIR)/manifests"
	if test -f "$$root/lib/apk/db/installed"; then
		cp "$$root/lib/apk/db/installed" "$(ANALYSIS_DIR)/manifests/apk-installed.txt"
		awk -F: '/^P:/{print $$2}' "$$root/lib/apk/db/installed" |
			sed 's/^ //' | LC_ALL=C sort >"$(ANALYSIS_DIR)/manifests/package-names.txt"
	else
		: >"$(ANALYSIS_DIR)/manifests/apk-installed.txt"
	fi
	if test -d "$$root/usr/lib/opkg/info"; then
		find "$$root/usr/lib/opkg/info" -type f | LC_ALL=C sort >"$(ANALYSIS_DIR)/manifests/opkg-metadata-paths.txt"
	else
		printf '%s\n' 'No opkg metadata directory found.' >"$(ANALYSIS_DIR)/manifests/opkg-metadata-paths.txt"
	fi
	find "$$root/lib/apk/packages" -type f -name '*.list' -print 2>/dev/null |
		sed 's#.*/##;s/\.list$$//' | LC_ALL=C sort >"$(ANALYSIS_DIR)/manifests/apk-package-list-files.txt"

find-modem-components:
	root="$(EXTRACT_DIR)/rootfs"
	test -d "$$root"
	mkdir -p "$(ANALYSIS_DIR)/manifests" "$(ANALYSIS_DIR)/reports"
	pattern='modem|cellular|sim|imei|iccid|signal|band|servingcell|qmi|mbim|ncm|rndis|wwan|ttyUSB|ttyACM|cdc-wdm|gl_modem|gl-modem|Fibocom|Quectel|Sierra|Telit|ZTE|FM350|RM500|RM520'
	find "$$root" -print | grep -Ei "$$pattern" |
		sed "s#^$$root##" | LC_ALL=C sort >"$(ANALYSIS_DIR)/manifests/modem-related-paths.txt"
	docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(ANALYSIS_IMAGE)" sh -c \
		'grep -RInaE --binary-files=without-match "$$1" /repo/extracted/rootfs 2>/dev/null |
			sed "s#/repo/extracted/rootfs##" | LC_ALL=C sort > /repo/analysis/manifests/modem-text-hits.txt || true' \
		sh "$$pattern"
	{
		for dir in etc/init.d etc/rc.d etc/config usr/libexec usr/share/rpcd usr/lib/rpcd usr/lib/lua usr/lib/ucode usr/share/ucode www etc/hotplug.d usr/lib/hotplug.d lib/netifd lib/functions; do
			test ! -e "$$root/$$dir" || find "$$root/$$dir" -print | sed "s#^$$root##"
		done
	} | LC_ALL=C sort -u >"$(ANALYSIS_DIR)/manifests/service-and-interface-paths.txt"

analyze: analyze-frontend analyze-elf extract-strings

analyze-frontend:
	root="$(EXTRACT_DIR)/rootfs"
	mkdir -p "$(ANALYSIS_DIR)/frontend/original" "$(ANALYSIS_DIR)/frontend/beautified"
	find "$$root/www" -type f \( -name '*.js' -o -name '*.js.gz' \) -print |
		sed "s#^$$root/##" | LC_ALL=C sort >"$(ANALYSIS_DIR)/frontend/javascript-paths.txt"
	: >"$(ANALYSIS_DIR)/frontend/bundle-sha256.tsv"
	while IFS= read -r rel; do
		js="$$root/$$rel"
		key=$$(printf '%s' "$$rel" | tr '/' '_')
		case "$$js" in
		*.gz) gzip -dc "$$js" >"$(ANALYSIS_DIR)/frontend/original/$${key%.gz}" ;;
		*) cp "$$js" "$(ANALYSIS_DIR)/frontend/original/$$key" ;;
		esac
		shasum -a 256 "$(ANALYSIS_DIR)/frontend/original/$${key%.gz}" |
			awk -v path="$$rel" '{ print path "\t" $$1 }' >>"$(ANALYSIS_DIR)/frontend/bundle-sha256.tsv"
	done <"$(ANALYSIS_DIR)/frontend/javascript-paths.txt"
	docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(ANALYSIS_IMAGE)" sh -c '
		set -eu
		for f in /repo/analysis/frontend/original/*.js; do
			test -f "$$f" || continue
			js-beautify "$$f" >"/repo/analysis/frontend/beautified/$$(basename "$$f")"
		done
		grep -rhoE "(/rpc|/ws|cellular\.[A-Za-z0-9_.-]+|unsupportedModem|currentModemType|send_at_command|get_[A-Za-z0-9_]+|set_[A-Za-z0-9_]+|scan_[A-Za-z0-9_]+|remove_profile|disconnect)" \
			/repo/analysis/frontend/beautified 2>/dev/null | LC_ALL=C sort -u > /repo/analysis/frontend/api-hits.txt || true
		'

analyze-elf:
	root="$(EXTRACT_DIR)/rootfs"
	list="$(ANALYSIS_DIR)/manifests/elf-paths.txt"
	test -f "$$list"
	mkdir -p "$(ANALYSIS_DIR)/elf"
	while IFS= read -r rel; do
		rel=$${rel#./}
		case "$$rel" in
		usr/bin/gl_modem|usr/bin/cellular_manager|usr/bin/modem_AT|usr/bin/qcm|usr/bin/process_modem_network|usr/bin/modem_signal|usr/lib/libcm*.so|usr/lib/oui-httpd/rpc/modem.so)
			key=$$(printf '%s' "$$rel" | tr '/' '_')
			out="$(ANALYSIS_DIR)/elf/$$key.txt"
			sha=$$(shasum -a 256 "$$root/$$rel" | awk '{print $$1}')
			{
				printf 'path: /%s\nsha256: %s\n\n' "$$rel" "$$sha"
				file "$$root/$$rel" | sed "s#^$$root##"
			} >"$$out"
			docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
				"$(ANALYSIS_IMAGE)" sh -c "
				f=/repo/extracted/rootfs/$$rel
				o=/repo/analysis/elf/$$key.txt
				{
					echo
					echo '## readelf -h -l -d -n -s'
					readelf -W -h -l -d -n -s \"\$$f\" 2>&1 || true
					echo
					echo '## objdump -p -T'
					objdump -p -T \"\$$f\" 2>&1 || true
					echo
					echo '## nm -D'
					nm -D \"\$$f\" 2>&1 || true
				} >>\"\$$o\""
			;;
		esac
	done <"$$list"
	printf 'path\tsha256\tfile\n' >"$(ANALYSIS_DIR)/elf/index.tsv"
	for report in "$(ANALYSIS_DIR)"/elf/*.txt; do
		test -f "$$report" || continue
		path=$$(sed -n 's/^path: //p' "$$report" | head -n 1)
		sha=$$(sed -n 's/^sha256: //p' "$$report" | head -n 1)
		printf '%s\t%s\t%s\n' "$$path" "$$sha" "$${report#$(REPO_DIR)/}" >>"$(ANALYSIS_DIR)/elf/index.tsv"
	done

extract-strings:
	root="$(EXTRACT_DIR)/rootfs"
	mkdir -p "$(ANALYSIS_DIR)/strings"
	{
		printf '%s\n' usr/bin/gl_modem usr/bin/cellular_manager usr/bin/modem_AT usr/bin/qcm \
			usr/bin/process_modem_network usr/bin/modem_signal usr/lib/oui-httpd/rpc/modem.so
		find "$$root/usr/lib" -maxdepth 1 -type f -name 'libcm*.so' -print |
			sed "s#^$$root/##"
	} | LC_ALL=C sort -u | while IFS= read -r rel; do
		test -f "$$root/$$rel" || continue
		key=$$(printf '%s' "$$rel" | tr '/' '_')
		docker run --rm --mount "type=bind,src=$(REPO_DIR),dst=/repo" \
			"$(ANALYSIS_IMAGE)" sh -c \
			"strings -a -t x -n 4 /repo/extracted/rootfs/$$rel | LC_ALL=C sort -k1,1 > /repo/analysis/strings/$$key.txt"
	done
	printf 'source\toffset_and_string\n' >"$(ANALYSIS_DIR)/strings/at-command-catalog.tsv"
	for report in "$(ANALYSIS_DIR)"/strings/*.txt; do
		test -f "$$report" || continue
		source=$$(basename "$$report" .txt)
		grep -E '(^|[[:space:]])AT([+^$$!&]|I([^[:alnum:]]|$$))' "$$report" 2>/dev/null |
			while IFS= read -r line; do printf '%s\t%s\n' "$$source" "$$line"; done
	done >>"$(ANALYSIS_DIR)/strings/at-command-catalog.tsv"

report:
	mkdir -p "$(ANALYSIS_DIR)/reports"
	{
		printf '# Generated evidence index\n\n'
		printf 'Generated UTC: %s\n\n' "$$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
		find "$(ANALYSIS_DIR)" -type f ! -path '*/reports/generated-index.md' -print |
			sed "s#^$(REPO_DIR)/##" | LC_ALL=C sort | sed 's/^/- `&`/'
	} >"$(ANALYSIS_DIR)/reports/generated-index.md"

test:
	./tests/run.sh

package: SDK_NAME = openwrt-sdk-25.12.5-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst
package: SDK_URL = https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/$(SDK_NAME)
package: SDK_SHA256 = ff4a38a397caa2cfe1c39e18f84ddede14878221b3593c3f2c4cfe24e3ec4c25
package: SDK_DIR_NAME = sdk-25.12.5-mediatek-filogic
package: BUILD_IMAGE = mt3000-openwrt-sdk:25.12.5
package: PACKAGE_GLOB = gl-modem-community*.apk
package: PACKAGE_ASSET = gl-modem-community-$(PACKAGE_VERSION)-r$(PACKAGE_RELEASE).apk
package: BUILD_REPORT = package-build.txt
package: HASH_REPORT = gl-modem-community.apk.sha256
package: ARTIFACT_REPORT = package-artifact-path.txt

package-opkg: SDK_NAME = openwrt-sdk-24.10.4-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst
package-opkg: SDK_URL = https://downloads.openwrt.org/releases/24.10.4/targets/mediatek/filogic/$(SDK_NAME)
package-opkg: SDK_SHA256 = b9762b8e1c8e114b0e6a252b98e94e6e4a1d2496beb9f6044c26227a8d78dee0
package-opkg: SDK_DIR_NAME = sdk-24.10.4-mediatek-filogic
package-opkg: BUILD_IMAGE = mt3000-openwrt-sdk:24.10.4
package-opkg: PACKAGE_GLOB = gl-modem-community*.ipk
package-opkg: PACKAGE_ASSET = gl-modem-community_$(PACKAGE_VERSION)-r$(PACKAGE_RELEASE)_aarch64_cortex-a53.ipk
package-opkg: BUILD_REPORT = package-opkg-build.txt
package-opkg: HASH_REPORT = gl-modem-community.ipk.sha256
package-opkg: ARTIFACT_REPORT = package-opkg-artifact-path.txt

package-glinet21: SDK_NAME = openwrt-sdk-21.02.7-mediatek-mt7622_gcc-8.4.0_musl.Linux-x86_64.tar.xz
package-glinet21: SDK_URL = https://downloads.openwrt.org/releases/21.02.7/targets/mediatek/mt7622/$(SDK_NAME)
package-glinet21: SDK_SHA256 = 723b08a90778779cbc20da03a36fa0e213b22dd63ce601803f0eae44f303681d
package-glinet21: SDK_DIR_NAME = sdk-21.02.7-mediatek-mt7622
package-glinet21: BUILD_IMAGE = mt3000-openwrt-sdk:21.02.7
package-glinet21: PACKAGE_GLOB = gl-modem-community*.ipk
package-glinet21: PACKAGE_ASSET = gl-modem-community_$(PACKAGE_VERSION)-$(PACKAGE_RELEASE)_glinet-21.02_aarch64_cortex-a53.ipk
package-glinet21: BUILD_REPORT = package-glinet21-build.txt
package-glinet21: HASH_REPORT = gl-modem-community-glinet21.ipk.sha256
package-glinet21: ARTIFACT_REPORT = package-glinet21-artifact-path.txt

package package-opkg:
	sdk_archive="$(REPO_DIR)/tool-cache/$(SDK_NAME)"
	sdk_dir="$(REPO_DIR)/tool-cache/$(SDK_DIR_NAME)"
	mkdir -p "$(REPO_DIR)/tool-cache" "$(REPO_DIR)/artifacts" "$(ANALYSIS_DIR)/reports" "$(ANALYSIS_DIR)/hashes"
	if ! test -f "$$sdk_archive"; then
		curl --fail --location --retry 2 --output "$$sdk_archive.partial" "$(SDK_URL)"
		mv "$$sdk_archive.partial" "$$sdk_archive"
	fi
	printf '%s  %s\n' "$(SDK_SHA256)" "$$sdk_archive" | shasum -a 256 -c -
	if ! test -d "$$sdk_dir"; then
		mkdir -p "$$sdk_dir"
		tar --strip-components=1 -xf "$$sdk_archive" -C "$$sdk_dir"
	fi
	mkdir -p "$$sdk_dir/package/gl-modem-community"
	rsync -a --delete "$(REPO_DIR)/package/gl-modem-community/" "$$sdk_dir/package/gl-modem-community/"
	find "$$sdk_dir/bin/packages" -type f -name '$(PACKAGE_GLOB)' -delete 2>/dev/null || true
	rm -f "$(REPO_DIR)/artifacts/$(PACKAGE_ASSET)"
	docker build --platform linux/amd64 -t "$(BUILD_IMAGE)" "$(REPO_DIR)/tools/sdk-container"
	docker run --rm --platform linux/amd64 \
		--mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(BUILD_IMAGE)" sh -c "
			set -eu
			cd /repo/tool-cache/$(SDK_DIR_NAME)
			make defconfig
			make V=s package/gl-modem-community/compile
		" >"$(ANALYSIS_DIR)/reports/$(BUILD_REPORT)" 2>&1
	artifact=$$(find "$$sdk_dir/bin/packages" -type f -name '$(PACKAGE_GLOB)' -print | head -n 1)
	test -n "$$artifact"
	install -m 0644 "$$artifact" "$(REPO_DIR)/artifacts/$(PACKAGE_ASSET)"
	shasum -a 256 "$(REPO_DIR)/artifacts/$(PACKAGE_ASSET)" |
		sed "s# $(REPO_DIR)/# #" >"$(ANALYSIS_DIR)/hashes/$(HASH_REPORT)"
	printf '%s\n' "artifacts/$(PACKAGE_ASSET)" >"$(ANALYSIS_DIR)/reports/$(ARTIFACT_REPORT)"

package-glinet21:
	sdk_archive="$(REPO_DIR)/tool-cache/$(SDK_NAME)"
	mkdir -p "$(REPO_DIR)/tool-cache" "$(REPO_DIR)/artifacts" "$(ANALYSIS_DIR)/reports" "$(ANALYSIS_DIR)/hashes"
	if ! test -f "$$sdk_archive"; then
		curl --fail --location --retry 2 --output "$$sdk_archive.partial" "$(SDK_URL)"
		mv "$$sdk_archive.partial" "$$sdk_archive"
	fi
	printf '%s  %s\n' "$(SDK_SHA256)" "$$sdk_archive" | shasum -a 256 -c -
	rm -f "$(REPO_DIR)/artifacts/$(PACKAGE_ASSET)"
	docker build --platform linux/amd64 -t "$(BUILD_IMAGE)" "$(REPO_DIR)/tools/sdk-container"
	docker run --rm --platform linux/amd64 \
		--mount "type=bind,src=$(REPO_DIR),dst=/repo" \
		"$(BUILD_IMAGE)" sh -c "
			set -eu
			sdk_dir=\$$(mktemp -d /tmp/gl-modem-community-sdk.XXXXXX)
			tar --strip-components=1 -xf '/repo/tool-cache/$(SDK_NAME)' -C \"\$$sdk_dir\"
			mkdir -p \"\$$sdk_dir/package/gl-modem-community\"
			rsync -a --delete /repo/package/gl-modem-community/ \"\$$sdk_dir/package/gl-modem-community/\"
			cd \"\$$sdk_dir\"
			make defconfig
			make V=s package/gl-modem-community/compile
			artifact=\$$(find \"\$$sdk_dir/bin/packages\" -type f -name '$(PACKAGE_GLOB)' -print | head -n 1)
			test -n \"\$$artifact\"
			install -m 0644 \"\$$artifact\" '/repo/artifacts/$(PACKAGE_ASSET)'
		" >"$(ANALYSIS_DIR)/reports/$(BUILD_REPORT)" 2>&1
	test -s "$(REPO_DIR)/artifacts/$(PACKAGE_ASSET)"
	shasum -a 256 "$(REPO_DIR)/artifacts/$(PACKAGE_ASSET)" |
		sed "s# $(REPO_DIR)/# #" >"$(ANALYSIS_DIR)/hashes/$(HASH_REPORT)"
	printf '%s\n' "artifacts/$(PACKAGE_ASSET)" >"$(ANALYSIS_DIR)/reports/$(ARTIFACT_REPORT)"

check-firmware-channels: CHANNEL_VERIFY_IMAGES = 0
verify-firmware-channels: CHANNEL_VERIFY_IMAGES = 1

check-firmware-channels verify-firmware-channels:
	tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/gl-modem-channel-check.XXXXXX")
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM
	for model in $$(jq -r '.channels[].api_model' "$(CHANNEL_MANIFEST)" | sort -u); do
		curl --fail --silent --show-error --location \
			"https://firmware-api.gl-inet.com/cloud-api/model/info?model=$$model" >"$$tmp/$$model.json"
		jq -e '.code == 0 and (.info | type == "array")' "$$tmp/$$model.json" >/dev/null
	done
	jq -c '.channels[]' "$(CHANNEL_MANIFEST)" |
	while IFS= read -r row; do
		channel=$$(printf '%s\n' "$$row" | jq -r '.channel')
		model=$$(printf '%s\n' "$$row" | jq -r '.api_model')
		expected=$$(printf '%s\n' "$$row" | jq -c '{
			version: .glinet_version,
			stage,
			release_time,
			name: .artifact.name,
			link: .artifact.url,
			sha256: .artifact.sha256,
			size: .artifact.size
		}')
		case "$$channel" in
		stable)
			actual=$$(jq -c 'first(
				.info[] | select(.stage == "RELEASE") as $$release |
				$$release.download[] | select(.name | endswith(".tar")) |
				{version: $$release.version, stage: $$release.stage,
				release_time: $$release.release_time, name, link, sha256, size}
			)' "$$tmp/$$model.json")
			;;
		beta)
			actual=$$(jq -c 'first(
				.info[] | select(.stage == "TESTING") as $$release |
				$$release.download[] | select(.name | endswith(".tar")) |
				{version: $$release.version, stage: $$release.stage,
				release_time: $$release.release_time, name, link, sha256, size}
			)' "$$tmp/$$model.json")
			;;
		openwrt24|openwrt25)
			marker=op$${channel#openwrt}
			actual=$$(jq -c --arg marker "$$marker" 'first(
				.info[] as $$release | $$release.download[] |
				select(.name | contains($$marker)) |
				{version: $$release.version, stage: $$release.stage,
				release_time: $$release.release_time, name, link, sha256, size}
			)' "$$tmp/$$model.json")
			;;
		esac
		if [ "$$actual" != "$$expected" ]; then
			printf 'GL.iNet channel drift detected for %s\nexpected: %s\nactual:   %s\n' \
				"$$channel" "$$expected" "$$actual" >&2
			exit 1
		fi
		printf 'channel metadata verified: %s\n' "$$channel"
		[ "$(CHANNEL_VERIFY_IMAGES)" -eq 1 ] || continue
		url=$$(printf '%s\n' "$$row" | jq -r '.artifact.url')
		name=$$(printf '%s\n' "$$row" | jq -r '.artifact.name')
		sha=$$(printf '%s\n' "$$row" | jq -r '.artifact.sha256')
		curl --fail --silent --show-error --location --retry 2 --output "$$tmp/$$name" "$$url"
		printf '%s  %s\n' "$$sha" "$$tmp/$$name" | shasum -a 256 -c -
		facts=$$(docker run --rm \
			--mount "type=bind,src=$$tmp/$$name,dst=/firmware,readonly" \
			"$(ANALYSIS_IMAGE)" sh -c '
				set -eu
				work=$$(mktemp -d)
				mkdir -p "$$work/outer" "$$work/rootfs"
				tar -xf /firmware -C "$$work/outer"
				root=$$(find "$$work/outer" -type f -name root -print | head -n 1)
				test -n "$$root"
				unsquashfs -no-progress -d "$$work/rootfs" "$$root" >/dev/null
				description=$$(sed -n "s/^DISTRIB_DESCRIPTION='\''OpenWrt \(.*\)'\''/\1/p" "$$work/rootfs/etc/openwrt_release")
				description=$$(printf "%s" "$$description" | sed "s/[[:space:]]*$$//")
				target=$$(sed -n "s/^DISTRIB_TARGET='\''\(.*\)'\''/\1/p" "$$work/rootfs/etc/openwrt_release")
				kernel=$$(find "$$work/rootfs/lib/modules" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)
				kernel=$${kernel##*/}
				if test -f "$$work/rootfs/lib/apk/db/installed"; then manager=apk; else manager=opkg; fi
				if test -r "$$work/rootfs/lib/modem_data/modem_list.json" &&
					test -x "$$work/rootfs/etc/init.d/gl_cellular_manager"; then
					stack=modern
				elif test -r "$$work/rootfs/lib/functions/modem.sh" &&
					test -x "$$work/rootfs/etc/init.d/modem"; then
					stack=legacy
				else
					stack=unsupported
				fi
				jq -cn \
					--arg openwrt_release "$$description" \
					--arg target "$$target" \
					--arg kernel "$$kernel" \
					--arg package_manager "$$manager" \
					--arg cellular_stack "$$stack" \
					"{openwrt_release: \$$openwrt_release, target: \$$target, kernel: \$$kernel,
					  package_manager: \$$package_manager, cellular_stack: \$$cellular_stack}"
			')
		expected_facts=$$(printf '%s\n' "$$row" | jq -c '.firmware | {
			openwrt_release, target, kernel, package_manager, cellular_stack
		}')
		test "$$facts" = "$$expected_facts" || {
			printf 'Embedded firmware drift detected for %s\nexpected: %s\nactual:   %s\n' \
				"$$channel" "$$expected_facts" "$$facts" >&2
			exit 1
		}
		printf 'embedded firmware verified: %s\n' "$$channel"
	done

generate-sbom:
	test -n "$(SBOM_FORMAT)"
	test -s "$(SBOM_ARTIFACT)"
	test -n "$(SBOM_OUTPUT)"
	mkdir -p "$$(dirname "$(SBOM_OUTPUT)")"
	tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/gl-modem-sbom.XXXXXX")
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM
	hash=$$(shasum -a 256 "$(SBOM_ARTIFACT)" | awk '{print $$1}')
	case "$(SBOM_FORMAT)" in
	apk)
		test -s "$(APK_METADATA)"
		jq -c '[.info.depends[]? | capture("^(?<name>[^<>=~ ]+)").name] | unique' \
			"$(APK_METADATA)" >"$$tmp/dependencies.json"
		jq -c '[.paths[] | select(.name != null) as $$directory |
			($$directory.files // [])[] | {
				type: "file",
				name: ("/" + $$directory.name + "/" + .name),
				"bom-ref": ("file:/" + $$directory.name + "/" + .name + "#" + .hash),
				hashes: [{alg: "SHA-256", content: .hash}]
			}]' "$(APK_METADATA)" >"$$tmp/files.json"
		name=$$(jq -er '.info.name' "$(APK_METADATA)")
		version=$$(jq -er '.info.version' "$(APK_METADATA)")
		architecture=$$(jq -er '.info.arch' "$(APK_METADATA)")
		license=$$(jq -er '.info.license' "$(APK_METADATA)")
		description=$$(jq -er '.info.description' "$(APK_METADATA)")
		;;
	ipk)
		mkdir -p "$$tmp/outer" "$$tmp/control" "$$tmp/root"
		artifact=$$(cd "$$(dirname "$(SBOM_ARTIFACT)")" && pwd)/$$(basename "$(SBOM_ARTIFACT)")
		if tar -tzf "$$artifact" >/dev/null 2>&1; then
			tar -xzf "$$artifact" -C "$$tmp/outer"
		else
			(cd "$$tmp/outer" && ar x "$$artifact")
		fi
		control=$$(find "$$tmp/outer" -maxdepth 1 -type f -name 'control.tar.*' -print | head -n 1)
		data=$$(find "$$tmp/outer" -maxdepth 1 -type f -name 'data.tar.*' -print | head -n 1)
		test -n "$$control"
		test -n "$$data"
		tar -xf "$$control" -C "$$tmp/control"
		tar -xf "$$data" -C "$$tmp/root"
		control_file=$$(find "$$tmp/control" -type f -name control -print | head -n 1)
		name=$$(sed -n 's/^Package: //p' "$$control_file")
		version=$$(sed -n 's/^Version: //p' "$$control_file")
		architecture=$$(sed -n 's/^Architecture: //p' "$$control_file")
		license=$$(sed -n 's/^License: //p' "$$control_file")
		description=$$(sed -n 's/^Description: //p' "$$control_file")
		depends=$$(sed -n 's/^Depends: //p' "$$control_file")
		printf '%s\n' "$$depends" | tr ',' '\n' |
			sed 's/^[[:space:]]*//;s/[[:space:]]*(.*$$//;/^$$/d' |
			LC_ALL=C sort -u | jq -Rsc 'split("\n") | map(select(length > 0))' >"$$tmp/dependencies.json"
		: >"$$tmp/files.tsv"
		find "$$tmp/root" -type f -print | LC_ALL=C sort |
			while IFS= read -r file; do
				relative=$${file#"$$tmp/root"}
				file_hash=$$(shasum -a 256 "$$file" | awk '{print $$1}')
				printf '%s\t%s\n' "$$relative" "$$file_hash"
			done >"$$tmp/files.tsv"
		jq -Rn '[inputs | split("\t") | {
			type: "file",
			name: .[0],
			"bom-ref": ("file:" + .[0] + "#" + .[1]),
			hashes: [{alg: "SHA-256", content: .[1]}]
		}]' <"$$tmp/files.tsv" >"$$tmp/files.json"
		;;
	*)
		printf 'Unsupported SBOM format: %s\n' "$(SBOM_FORMAT)" >&2
		exit 2
		;;
	esac
	root_ref="pkg:$(SBOM_FORMAT)/openwrt/$$name@$$version?arch=$$architecture"
	jq -n \
		--arg architecture "$$architecture" \
		--arg description "$$description" \
		--arg format "$(SBOM_FORMAT)" \
		--arg hash "$$hash" \
		--arg license "$$license" \
		--arg name "$$name" \
		--arg root_ref "$$root_ref" \
		--arg version "$$version" \
		--slurpfile dependencies "$$tmp/dependencies.json" \
		--slurpfile files "$$tmp/files.json" '
		{
			"$$schema": "https://cyclonedx.org/schema/bom-1.6.schema.json",
			bomFormat: "CycloneDX",
			specVersion: "1.6",
			version: 1,
			metadata: {
				component: ({
					type: "application",
					name: $$name,
					version: $$version,
					description: $$description,
					"bom-ref": $$root_ref,
					purl: $$root_ref,
					hashes: [{alg: "SHA-256", content: $$hash}],
					properties: [
						{name: "openwrt:architecture", value: $$architecture},
						{name: "openwrt:package-format", value: $$format}
					]
				} + if $$license == "" then {} else {
					licenses: [{license: {id: $$license}}]
				} end)
			},
			components: (
				($$dependencies[0] | map({
					type: "library",
					name: .,
					"bom-ref": ("pkg:generic/" + .),
					purl: ("pkg:generic/" + .)
				})) + $$files[0]
			),
			dependencies: [{
				ref: $$root_ref,
				dependsOn: ($$dependencies[0] | map("pkg:generic/" + .))
			}]
		}' >"$(SBOM_OUTPUT)"

validate-sbom:
	test -s "$(SBOM)"
	jq -e '
		.bomFormat == "CycloneDX" and
		.specVersion == "1.6" and
		.version == 1 and
		(.metadata.component.type == "application") and
		(.metadata.component.name | type == "string" and length > 0) and
		(.metadata.component.version | type == "string" and length > 0) and
		(.metadata.component.hashes | any(.alg == "SHA-256" and (.content | test("^[0-9a-f]{64}$$")))) and
		(.components | type == "array") and
		(.components | any(.type == "file" and (.hashes | any(.alg == "SHA-256")))) and
		(.dependencies | type == "array" and length == 1) and
		(.dependencies[0].ref == .metadata.component["bom-ref"])
	' "$(SBOM)" >/dev/null
	if command -v cyclonedx >/dev/null 2>&1; then
		cyclonedx validate --input-file "$(SBOM)" >/dev/null
	fi

verify-signing-key:
	test -s "$(PRIVATE_KEY)"
	test -s "$(PUBLIC_KEY)"
	tmp=$$(mktemp "$${TMPDIR:-/tmp}/gl-modem-public-key.XXXXXX")
	trap 'rm -f "$$tmp"' EXIT HUP INT TERM
	openssl pkey -in "$(PRIVATE_KEY)" -pubout -out "$$tmp"
	if ! cmp -s "$$tmp" "$(PUBLIC_KEY)"; then
		printf 'APK signing private key does not match %s\n' "$(PUBLIC_KEY)" >&2
		exit 1
	fi

sign-apk-release:
	test -n "$(SDK_DIR)"
	test -s "$(PRIVATE_KEY)"
	test -s "$(PUBLIC_KEY)"
	test -s "$(APK)"
	test -n "$(OUTPUT_INDEX)"
	test -n "$(OUTPUT_METADATA)"
	apk_tool="$(SDK_DIR)/staging_dir/host/bin/apk"
	test -x "$$apk_tool"
	$(MAKE) --no-print-directory verify-signing-key \
		PRIVATE_KEY="$(PRIVATE_KEY)" PUBLIC_KEY="$(PUBLIC_KEY)"
	tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/gl-modem-signing.XXXXXX")
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM
	"$$apk_tool" adbsign --allow-untrusted --reset-signatures \
		--sign-key "$(PRIVATE_KEY)" "$(APK)"
	apk_dir=$$(cd "$$(dirname "$(APK)")" && pwd)
	apk_name=$$(basename "$(APK)")
	index_dir=$$(dirname "$(OUTPUT_INDEX)")
	mkdir -p "$$index_dir"
	index_dir=$$(cd "$$index_dir" && pwd)
	public_keys=$$(dirname "$(PUBLIC_KEY)")
	(
		cd "$$apk_dir"
		"$$apk_tool" mkndx \
			--description "gl-modem-community signed package feed" \
			--keys-dir "$$public_keys" \
			--output "$$index_dir/$$(basename "$(OUTPUT_INDEX)")" \
			--sign-key "$(PRIVATE_KEY)" \
			"$$apk_name"
	)
	"$$apk_tool" verify --keys-dir "$$public_keys" "$(APK)"
	"$$apk_tool" verify --keys-dir "$$public_keys" "$(OUTPUT_INDEX)"
	mkdir "$$tmp/empty-keys"
	for signed_file in "$(APK)" "$(OUTPUT_INDEX)"; do
		if "$$apk_tool" verify --keys-dir "$$tmp/empty-keys" "$$signed_file" >"$$tmp/untrusted.log" 2>&1; then
			printf 'Unsigned verification unexpectedly succeeded for %s\n' "$$signed_file" >&2
			exit 1
		fi
		grep -F 'UNTRUSTED' "$$tmp/untrusted.log" >/dev/null
	done
	"$$apk_tool" --format json info --all "$(APK)" >"$(OUTPUT_METADATA)"

clean-work:
	@echo "Remove ignored work directories manually after reviewing their paths."
