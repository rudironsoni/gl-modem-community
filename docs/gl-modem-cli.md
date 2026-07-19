# `gl_modem` CLI contract

| Invocation | Purpose | Input | Output | Caller evidence |
|---|---|---|---|---|
| `gl_modem -B <bus> -U <SUB> AT <AT_CMD>` | send AT command | bus, subchannel, command | [UNVERIFIED] text/JSON | embedded usage and callers |
| `gl_modem -B <bus> -S <SLOT> connect-auto` | connect selected SIM | bus, slot | [UNVERIFIED] | embedded usage |
| `gl_modem -B <bus> -S <SLOT> disconnect` | disconnect | bus, slot | [UNVERIFIED] | embedded usage |
| `gl_modem -B <bus> init` | initialize modem | bus | [UNVERIFIED] | embedded usage |
| `gl_modem -B <bus> sms-config` | configure SMS | bus | [UNVERIFIED] | embedded usage |
| `gl_modem -B <bus> convert <file> <length>` | convert SMS data | file/length | [UNVERIFIED] | embedded usage |
| `gl_modem -B <bus> -C check_traffic_config` | validate/apply traffic config | UCI/state | [UNVERIFIED] | embedded usage |
| `gl_modem -B <bus> -C check_apnprofile_config` | validate/apply APN profiles | UCI/state | [UNVERIFIED] | embedded usage |
| `gl_modem -B <bus> -C check_sms_forward_config` | validate/apply forwarding | UCI/state | [UNVERIFIED] | embedded usage |

Conclusion: [CONFIRMED] The CLI is bus-oriented and dynamically linked to the proprietary `libcm` stack. Its known command surface is narrow, but it is not the sole UI/backend contract.

Evidence: `gl_modem` strings with offsets, ELF dependencies, scripts, and adjacent binaries in `analysis/`.

Confidence: high.

Alternative explanations: there may be undocumented argument combinations not exposed in static strings.

How to verify dynamically: install a transparent logging wrapper that preserves argv, stdout, stderr, exit status, timing, signals, and concurrency, then exercise every stock UI action.

Conclusion: [CONFIRMED] Replacing only `gl_modem` cannot provide complete native FM350 UI integration because `modem.so` and `cellular_manager` call `libcm` directly.

Evidence: direct ELF library dependencies and process architecture.

Confidence: confirmed.

Alternative explanations: a wrapper could still cover only the subprocess paths that happen to matter for a limited workflow.

How to verify dynamically: trace all `execve` and libcm-related serial/socket activity during supported-modem operation.
