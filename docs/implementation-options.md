# Implementation options

Scores use 1 (poor/high cost) through 5 (strong/low cost). Completeness is for stock UI integration, including advanced features.

| Strategy | Feasibility | Completeness | Effort | Runtime safety | Upgrade resilience | Reversible | Testable | Maintenance |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| A. Configuration-only table entry | 4 | 2 | 5 | 4 | 3 | 5 | 4 | 5 |
| B. Binary model allowlist patch | 2 | 2 | 2 | 2 | 1 | 3 | 2 | 1 |
| C. Binary Fibocom handlers | 2 | 5 | 1 | 1 | 1 | 2 | 2 | 1 |
| D. `gl_modem` wrapper | 3 | 2 | 3 | 3 | 3 | 5 | 3 | 3 |
| E. `gl_modem` replacement | 2 | 2 | 1 | 2 | 2 | 4 | 2 | 2 |
| F. AT-response proxy | 2 | 3 | 1 | 1 | 2 | 4 | 2 | 1 |
| G. Backend RPC extension | 4 | 4 | 3 | 4 | 3 | 5 | 4 | 3 |
| H. Frontend adaptation | 3 | 4 | 2 | 3 | 1 | 4 | 3 | 2 |
| I. LuCI/external UI | 5 | 5 | 3 | 4 | 4 | 5 | 5 | 4 |

Conclusion: [CONFIRMED] Binary patching is unnecessary for initial detection because the allowlist is an external JSON file. It would also remain insufficient for Quectel-specific advanced code.

Evidence: hotplug/model table and libcm AT catalog.

Confidence: high.

Alternative explanations: a later binary model comparison may still appear at runtime.

How to verify dynamically: table-only staged test plus serial/process trace.

Conclusion: [CONFIRMED] A complete `gl_modem` replacement is the wrong boundary because the resident manager and RPC module directly use `libcm`.

Evidence: ELF dependencies and architecture map.

Confidence: confirmed.

Alternative explanations: a limited connect-only wrapper could still be useful.

How to verify dynamically: record every CLI invocation and direct serial/socket operation during UI use.

Recommendation: [INFERENCE] Use a package-level hybrid of A and G: merge additive modem definitions at boot, provide the proven `xmm` netifd protocol, and install a narrow Lua RPC extension that transparently falls through to the vendor `.so`. Add Fibocom method handlers only when a captured stock method contract requires them. This is the smallest maintainable route that can grow without copying or patching proprietary code.

The fallback if GL's core parsers prove incompatible is to implement method-specific clean-room RPC handlers backed by public FM350 commands. The stock frontend and mobile app remain unchanged.
