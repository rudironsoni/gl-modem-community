# Proprietary binary static analysis

Conclusion: [CONFIRMED] Nineteen modem-relevant ELF files were analyzed without executing extracted code. Per-file reports record path, SHA-256, architecture, ABI, interpreter, stripping, build ID, sections, imports, exports, dynamic dependencies, and disassembly metadata.

Evidence: `analysis/elf/index.tsv`, individual files under `analysis/elf/`, and `make analyze`.

Confidence: confirmed.

Alternative explanations: stripped binaries limit semantic reconstruction; function behavior inferred from string cross-references remains labeled.

How to verify dynamically: trace the stock processes on hardware and correlate observed operations with static call sites.

Key hashes:

| Path | SHA-256 |
|---|---|
| `/usr/bin/gl_modem` | `28289d0ef6dc7a6e756680426673b56c2f8396ed77fbf2f34f5c67ffe702b25a` |
| `/usr/bin/cellular_manager` | `eab349a42927ecfd269b14d150ddd3e4aa91be57520db123b57b62fc004f4887` |
| `/usr/bin/modem_AT` | `bd66dfd4e70402ff2828bee9bc9fb2fa1756289d2cd24d18938a9aee57821b66` |
| `/usr/lib/libcm_modem.so` | `16d2c8b86420db037aed0b3bb9dfc6556d357fd8c174a36450d86b3d413575f5` |

`libcm_modem.so` contains the command format `/usr/bin/modem_AT -B %s -P %s -O%d`, process-control strings, AT-device selection strings, generic 3GPP commands, and Quectel-specific dispatch data. `modem_AT` exposes bus-scoped socket/ubus evidence and raw serial handling.

[BLOCKED] Ghidra headless, radare2/rizin, and checksec were unavailable in the reproducible analysis image. `file`, `readelf`, `objdump`, `nm`, and offset-preserving `strings` completed for every relevant ELF. No guessed function names are represented as recovered symbols.

No proprietary executable or library is stored in Git.
