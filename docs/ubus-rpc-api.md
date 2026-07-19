# RPC, ubus, HTTP, and IPC interfaces

| Name | Implementation | Caller | Callee | Input/output | Side effects | Confidence |
|---|---|---|---|---|---|---|
| `/rpc` | `oui-rpc.lua` | UI/app | Lua module or `modem.so` | JSON-RPC envelope; method-specific JSON | modem/config actions | confirmed |
| `/ws` cellular topics | `cellular.lua` | UI/app | ubus cellular objects | topic subscriptions and JSON events | none observed statically | high |
| `cellular.status` | `cellular_manager` | hotplug/backend | manager/libcm | event JSON includes bus/model context | detection lifecycle | high |
| `cellular.modem` | `cellular_manager` | websocket/backend | libcm modem | info/status JSON | AT and modem state | high |
| `cellular.sim` | `cellular_manager` | websocket/backend | libcm SIM | info/status JSON | PIN/SIM state | high |
| `cellular.network` | `cellular_manager` | websocket/backend | libcm/netifd | info/status JSON | network state | high |
| `/tmp/<bus>.sock` | `modem_AT` | libcm/clients | serial daemon | proprietary request framing [UNVERIFIED] | serial AT I/O | medium |
| `gl_modem` CLI | `/usr/bin/gl_modem` | scripts/operators/libcm | libcm | CLI, stdout/stderr | connect/config/SMS | high |
| UCI network/cellular | libcm/netifd/scripts | manager/RPC | netifd | UCI sections/options | interface configuration | high |
| USB hotplug | `30_modem` | kernel hotplug | `cellular.status` | `PRODUCT`, bus/device variables | adds/removes modem | confirmed |

Conclusion: [CONFIRMED] Nginx maps `/rpc` to the GL JSON-RPC dispatcher and `/ws` to Lua websocket handlers. The websocket layer calls the four cellular ubus objects rather than invoking `gl_modem` directly.

Evidence: nginx and Lua configuration in the extracted root.

Confidence: confirmed.

Alternative explanations: individual ubus methods may spawn helpers internally.

How to verify dynamically: `ubus monitor`, nginx debug logs, and `strace -f -e execve,file,connect` on the relevant PIDs.

[UNVERIFIED] Exact proprietary socket framing, method timeouts, numeric exit codes, and all optional JSON fields cannot be established safely from strings alone. The validation plan captures them without bypassing authentication.
