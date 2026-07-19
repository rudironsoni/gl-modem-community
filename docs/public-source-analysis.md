# GL.iNet public-source analysis

Repositories were read at these commits on `2026-07-19`:

| Repository | Commit |
|---|---|
| `gl-inet/sdk` | `d8ad57d4474c2978ea3c9a530ee48c414c057bab` |
| `gl-inet/gl-modem-at` | `484b43a5824fd1487100680a633ecdbfb63922b9` |
| `gl-inet/openwrt-patch-status` | `a78c112d1c5bd591515d9f61c821b685017d892f` |
| `gl-inet/mt798x-boot` | `8f73dd1a66e2a9037e48ca7df6c5b14a48672a6e` |

Conclusion: [CONFIRMED] Public `gl-modem-at` is a small serial transport utility, not the proprietary `gl_modem` recovered from the image.

Evidence: public usage is `<gl_modem> <device> <command>` with a compatibility-shaped example `gl_modem -B 1-1.2 AT /dev/ttyUSB3 ATI`; source opens a tty, uses nonblocking serial I/O, and obtains an exclusive `flock`. The stock proprietary binary instead links `libcm` and exposes bus/SIM/config/SMS operations.

Confidence: confirmed.

Alternative explanations: the public implementation demonstrates GL.iNet conventions and may share lineage, but identity is unsupported by hashes, API, and dependencies.

How to verify dynamically: compare argv, serial locking, output, timeouts, and exit behavior. Do not substitute the public utility without a captured contract.

The SDK and patch-status sources were used only for package/build conventions and platform context. `mt798x-boot` is bootloader/platform context and provides no identified cellular application implementation. GL.iNet's public troubleshooting and cellular-interface guides describe supported user workflows, but do not publish the proprietary RPC/libcm contract.

No claim in this repository treats public `gl-modem-at` as source for proprietary behavior unless the same behavior is independently present in firmware evidence.
