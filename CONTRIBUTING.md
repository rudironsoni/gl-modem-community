# Contributing

Contributions for additional GL.iNet routers and cellular modems are welcome. Keep each change limited to one router, modem, or compatibility problem and include the hardware evidence needed to review it.

## Compatibility claims

Use these terms consistently:

- **Builds** means that the repository's pinned SDK produced the package.
- **Installed** means that the package manager accepted the package on a named firmware version.
- **Detected** means that GL.iNet's cellular services identified the modem.
- **Data session verified** means that the modem received an address and supplied a working route and DNS configuration.
- **Tested** means that the documented hardware test matrix passed for the exact router, modem, and firmware version.
- **Not tested** means that no hardware result is available. A successful SDK build does not change this status.

Every hardware claim must name the router, modem, USB IDs, exact firmware version, and observed result. Redact IMEI, ICCID, IMSI, phone numbers, APN credentials, and other subscriber data.

Do not describe a package as supported merely because it builds. Do not use statements about honesty, rigor, safety, or completeness in place of test evidence.

## Documentation style

Write user-facing documentation in complete sentences. Prefer direct statements about observed behavior:

> The IPK builds with the OpenWrt 24.10.7 SDK, but it has not been installed on GL.iNet OEM or OpenWrt 24 firmware.

Avoid replacing test evidence with a statement about the writer's intentions.

Keep `[CONFIRMED]`, `[INFERENCE]`, `[UNVERIFIED]`, and `[BLOCKED]` labels in research and analysis documents. Use the compatibility terms above in the README, release notes, and installation instructions.

## Pull requests

A pull request must include:

- the router model and exact firmware version;
- the modem name and USB IDs;
- the package format;
- the commands that were run;
- redacted hardware evidence;
- the affected success and failure cases;
- any test-matrix entries that remain incomplete.

Run the repository checks before publishing:

```sh
make test
git diff --check
```

Build both package formats when package contents, metadata, installation behavior, signing, feeds, or release automation changes:

```sh
make package
make package-opkg
```
