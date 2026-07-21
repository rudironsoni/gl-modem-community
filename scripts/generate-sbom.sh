#!/bin/bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo "usage: $0 apk|ipk ARTIFACT OUTPUT [APK_METADATA]" >&2
    exit 2
fi

format=$1
artifact=$2
output=$3
apk_metadata=${4:-}

test -s "$artifact"
mkdir -p "$(dirname "$output")"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-sbom.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

artifact_hash=$(sha256sum "$artifact" | awk '{print $1}')
files_json="$tmp/files.json"
dependencies_json="$tmp/dependencies.json"

case "$format" in
    apk)
        test -n "$apk_metadata"
        test -s "$apk_metadata"
        name=$(jq -er '.info.name' "$apk_metadata")
        version=$(jq -er '.info.version' "$apk_metadata")
        architecture=$(jq -er '.info.arch' "$apk_metadata")
        license=$(jq -er '.info.license' "$apk_metadata")
        description=$(jq -er '.info.description' "$apk_metadata")
        jq -c '[.info.depends[]? | capture("^(?<name>[^<>=~ ]+)").name] | unique' \
            "$apk_metadata" > "$dependencies_json"
        jq -c '[
            .paths[] |
            select(.name != null) as $directory |
            ($directory.files // [])[] |
            {
                type: "file",
                name: ("/" + $directory.name + "/" + .name),
                "bom-ref": ("file:/" + $directory.name + "/" + .name + "#" + .hash),
                hashes: [{alg: "SHA-256", content: .hash}]
            }
        ]' "$apk_metadata" > "$files_json"
        package_type=apk
        ;;
    ipk)
        mkdir "$tmp/outer" "$tmp/root"
        if tar -tzf "$artifact" >/dev/null 2>&1; then
            tar -xzf "$artifact" -C "$tmp/outer"
        else
            (
                cd "$tmp/outer"
                ar x "$OLDPWD/$artifact"
            )
        fi
        control_archive=$(find "$tmp/outer" -maxdepth 1 -type f -name 'control.tar.*' -print -quit)
        data_archive=$(find "$tmp/outer" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
        test -n "$control_archive"
        test -n "$data_archive"
        tar -xf "$control_archive" -C "$tmp/outer"
        control_file=$(find "$tmp/outer" -maxdepth 1 -type f -name control -print -quit)
        test -n "$control_file"

        control_value() {
            sed -n "s/^$1: //p" "$control_file"
        }

        name=$(control_value Package)
        version=$(control_value Version)
        architecture=$(control_value Architecture)
        license=$(control_value License)
        description=$(control_value Description)
        depends=$(control_value Depends)
        printf '%s\n' "$depends" | jq -Rsc '
            split(",") |
            map(gsub("^\\s+|\\s+$"; "")) |
            map(select(length > 0)) |
            map(capture("^(?<name>[^ (]+)").name) |
            unique
        ' > "$dependencies_json"

        tar -xf "$data_archive" -C "$tmp/root"
        : > "$tmp/files.tsv"
        find "$tmp/root" -type f -print | LC_ALL=C sort > "$tmp/file-list.txt"
        while IFS= read -r file; do
            relative=${file#"$tmp/root"}
            hash=$(sha256sum "$file" | awk '{print $1}')
            printf '%s\t%s\n' "$relative" "$hash" >> "$tmp/files.tsv"
        done < "$tmp/file-list.txt"
        jq -Rn '[
            inputs |
            split("\t") |
            {
                type: "file",
                name: .[0],
                "bom-ref": ("file:" + .[0] + "#" + .[1]),
                hashes: [{alg: "SHA-256", content: .[1]}]
            }
        ]' < "$tmp/files.tsv" > "$files_json"
        package_type=opkg
        ;;
    *)
        echo "Unsupported package format: $format" >&2
        exit 2
        ;;
esac

test -n "$name"
test -n "$version"
test -n "$architecture"
root_ref="pkg:$package_type/openwrt/$name@$version?arch=$architecture"

jq -n \
    --arg architecture "$architecture" \
    --arg description "$description" \
    --arg format "$format" \
    --arg hash "$artifact_hash" \
    --arg license "$license" \
    --arg name "$name" \
    --arg root_ref "$root_ref" \
    --arg version "$version" \
    --slurpfile dependencies "$dependencies_json" \
    --slurpfile files "$files_json" '
    {
        "$schema": "https://cyclonedx.org/schema/bom-1.6.schema.json",
        bomFormat: "CycloneDX",
        specVersion: "1.6",
        version: 1,
        metadata: {
            component: ({
                type: "application",
                name: $name,
                version: $version,
                description: $description,
                "bom-ref": $root_ref,
                purl: $root_ref,
                hashes: [{alg: "SHA-256", content: $hash}],
                properties: [
                    {name: "openwrt:architecture", value: $architecture},
                    {name: "openwrt:package-format", value: $format}
                ]
            } + if $license == "" then {} else {
                licenses: [{license: {id: $license}}]
            } end)
        },
        components: (
            ($dependencies[0] | map({
                type: "library",
                name: .,
                "bom-ref": ("pkg:generic/" + .),
                purl: ("pkg:generic/" + .)
            })) + $files[0]
        ),
        dependencies: [{
            ref: $root_ref,
            dependsOn: ($dependencies[0] | map("pkg:generic/" + .))
        }]
    }
' > "$output"
