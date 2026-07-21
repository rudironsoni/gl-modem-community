#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 CYCLONEDX_JSON" >&2
    exit 2
fi

sbom=$1
test -s "$sbom"

jq -e '
    .bomFormat == "CycloneDX" and
    .specVersion == "1.6" and
    .version == 1 and
    (.metadata.component.type == "application") and
    (.metadata.component.name | type == "string" and length > 0) and
    (.metadata.component.version | type == "string" and length > 0) and
    (.metadata.component.hashes | any(.alg == "SHA-256" and (.content | test("^[0-9a-f]{64}$")))) and
    (.components | type == "array") and
    (.components | any(.type == "file" and (.hashes | any(.alg == "SHA-256")))) and
    (.dependencies | type == "array" and length == 1) and
    (.dependencies[0].ref == .metadata.component["bom-ref"])
' "$sbom" >/dev/null

if command -v cyclonedx >/dev/null 2>&1; then
    cyclonedx validate --input-file "$sbom" >/dev/null
fi
