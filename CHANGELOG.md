# Changelog

## [0.4.0](https://github.com/rudironsoni/gl-modem-community/compare/v0.3.0...v0.4.0) (2026-08-24)


### Features

* single architecture-independent package per OS version with standard feed layout ([#81](https://github.com/rudironsoni/gl-modem-community/issues/81)) ([73b1c5e](https://github.com/rudironsoni/gl-modem-community/commit/73b1c5ef01e33d95fdcde39d0d02d4561a0f8d92))


### Bug Fixes

* **release:** retag published Release Please PRs so the next release can start ([#82](https://github.com/rudironsoni/gl-modem-community/issues/82)) ([82138ee](https://github.com/rudironsoni/gl-modem-community/commit/82138eec9bace3ce817df4414195ed8467c27246))

## [0.3.0](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.14...v0.3.0) (2026-08-22)


### Features

* add VOS 5G QMI support on GL-BE3600 ([89d1cd7](https://github.com/rudironsoni/gl-modem-community/commit/89d1cd741d2d9a78016d834ff22a3a2c0880c427))
* **fm350:** add Dell DW5931e-eSIM support on MT3000 ([#70](https://github.com/rudironsoni/gl-modem-community/issues/70)) ([de0a50c](https://github.com/rudironsoni/gl-modem-community/commit/de0a50cc3f4e32474a512a925d8f6046cabe9c51)), closes [#24](https://github.com/rudironsoni/gl-modem-community/issues/24)


### Bug Fixes

* add checkout step before determine version ([4a0c020](https://github.com/rudironsoni/gl-modem-community/commit/4a0c02045758bdd0131b5843ac71edcdfa1d347f))
* add debug ls to verify artifacts step ([cbe270f](https://github.com/rudironsoni/gl-modem-community/commit/cbe270faa444de8a60a8013b8e740ed7c8a05fcd))
* add jq to SDK container for SBOM generation ([6084977](https://github.com/rudironsoni/gl-modem-community/commit/6084977d3436fd4494bdb7b4bcd7958a1d027d5f))
* address VOS 5G review feedback ([06e7b13](https://github.com/rudironsoni/gl-modem-community/commit/06e7b13a107be978bde489110ba2e39f99b6ac9c))
* **ci:** avoid checksum pipeline aliasing ([929d4dc](https://github.com/rudironsoni/gl-modem-community/commit/929d4dc553a61cde0b7a9644fa7d6d7be296467f))
* **feeds:** publish signed 25.12 APK feed and index pages for GitHub Pages ([#73](https://github.com/rudironsoni/gl-modem-community/issues/73)) ([51ad197](https://github.com/rudironsoni/gl-modem-community/commit/51ad197c0b6f53c5a2eeee79674cd085776ab2fe))
* **feeds:** scope GL-BE3600 dependencies ([8305192](https://github.com/rudironsoni/gl-modem-community/commit/830519219164f8644774a3cffb65a7412b350ff8))
* fix shellcheck and actionlint issues in release workflow ([c942bf7](https://github.com/rudironsoni/gl-modem-community/commit/c942bf7c408e2869091385db59782b2900ecc009))
* **fm350:** restore 4.8.1 eSIM, dual-slot, and boot state on MT3000 ([#71](https://github.com/rudironsoni/gl-modem-community/issues/71)) ([62e5e6c](https://github.com/rudironsoni/gl-modem-community/commit/62e5e6c8a703da11b8dc8c9d0734d635be47301e))
* move set-version step before verify artifacts for actionlint ([ea44a06](https://github.com/rudironsoni/gl-modem-community/commit/ea44a0612386cbacbac288b41d94b76d36c136b8))
* preserve stock modem_AT arguments for VOS ([124b820](https://github.com/rudironsoni/gl-modem-community/commit/124b8201cadee1549268ce78408ef7c3e3f167b7))
* **release:** bind publication to immutable inputs ([918289b](https://github.com/rudironsoni/gl-modem-community/commit/918289b24560c0ae1300af15b607c7a79c98c89a))
* **release:** merge validated release proposals ([#78](https://github.com/rudironsoni/gl-modem-community/issues/78)) ([41edb52](https://github.com/rudironsoni/gl-modem-community/commit/41edb52c4ffedaf1aa07ee5b24308f5694a9f710))
* **release:** publish only complete unreleased feeds ([e46e926](https://github.com/rudironsoni/gl-modem-community/commit/e46e9268171acdd75a2f27c2f2d7443f9e8de642))
* **release:** reconcile Release Please baseline ([9444c3e](https://github.com/rudironsoni/gl-modem-community/commit/9444c3ea51c6debf357705d42e1d10c73d620d8c))
* **release:** reconcile Release Please baseline ([#75](https://github.com/rudironsoni/gl-modem-community/issues/75)) ([78a8c2b](https://github.com/rudironsoni/gl-modem-community/commit/78a8c2b200b7e1edf951898da1b36ef39dc8af3c))
* **release:** reconcile stale pending labels ([80c697b](https://github.com/rudironsoni/gl-modem-community/commit/80c697bdf0a7d1dff145fe01a586772546fb0d11))
* **release:** restore automatic versioned publication ([52a8c27](https://github.com/rudironsoni/gl-modem-community/commit/52a8c274e45ef9a7f6018b0dd6655d1d5e2e00ed))
* **release:** restore automatic versioned publication ([#74](https://github.com/rudironsoni/gl-modem-community/issues/74)) ([cec158e](https://github.com/rudironsoni/gl-modem-community/commit/cec158e20a24d324cdfb6d2bd5450842470087bc))
* remove APK SBOM generation (requires metadata) ([8fbc24d](https://github.com/rudironsoni/gl-modem-community/commit/8fbc24dcebe51f2ece12d155804c73cb72705013))
* replace Release Please with simple reliable release workflow ([dacb2b4](https://github.com/rudironsoni/gl-modem-community/commit/dacb2b4369eefa5c257d63c8723d0978db5891d0))
* update test-release-config.sh for new release workflow ([f80030e](https://github.com/rudironsoni/gl-modem-community/commit/f80030eaaca2e567fe9a99d9448f0ac7b3f3a7a4))
* use correct action SHA pins in release workflow ([dbfa854](https://github.com/rudironsoni/gl-modem-community/commit/dbfa85410dcfd381a4ca52a9184f819cc80b4498))
* use correct softprops/action-gh-release SHA ([a13e21b](https://github.com/rudironsoni/gl-modem-community/commit/a13e21b27f7f31b38c5cb3131ea7febc91528f7e))
* use correct softprops/action-gh-release SHA ([de1f04f](https://github.com/rudironsoni/gl-modem-community/commit/de1f04fa8a6982e902f471cee3a09aaffc602d4f))
* use exact filenames in verify artifacts step ([ebbe7d7](https://github.com/rudironsoni/gl-modem-community/commit/ebbe7d73ba9b133569afada7bb5bf936f788f5f5))
* use specific glob patterns in verify artifacts step ([f773394](https://github.com/rudironsoni/gl-modem-community/commit/f773394842c0b34b2e98337a918b5b80c44bf4d5))
* **vos5g:** block on prepare contention and stamp completed handoffs ([3fa699b](https://github.com/rudironsoni/gl-modem-community/commit/3fa699b01b7b8dae298e48c1dad678d33456b4f5))
* **vos5g:** release the WDS client when autoconnect disable fails ([f2658a9](https://github.com/rudironsoni/gl-modem-community/commit/f2658a9d8077a10bcd5b0bc578287dcb3b1b5297))


### Documentation

* remove transient GL-BE3600 CI status ([51b4a05](https://github.com/rudironsoni/gl-modem-community/commit/51b4a054544ab801a2612a2c2039684981821683))
* rewrite unknowns.md as a remaining-gaps tracker ([#72](https://github.com/rudironsoni/gl-modem-community/issues/72)) ([87b02fa](https://github.com/rudironsoni/gl-modem-community/commit/87b02fa3a3e96fdf86224f67115e1dc162296f81))
* standardize feed URLs to HTTPS custom domain and tighten README install UX ([#64](https://github.com/rudironsoni/gl-modem-community/issues/64)) ([10857f8](https://github.com/rudironsoni/gl-modem-community/commit/10857f83abeeaee57338ddcf1aca12f4d284c2a4))


### Miscellaneous Chores

* **deps:** bump actions/checkout from 4.2.2 to 7.0.1 ([#66](https://github.com/rudironsoni/gl-modem-community/issues/66)) ([29754e1](https://github.com/rudironsoni/gl-modem-community/commit/29754e1b4570dbccfb0c6d486cff7cc30a4a3c3d))
* **deps:** bump debian from `7b140f3` to `abd67ff` in /tools/analysis-container ([#67](https://github.com/rudironsoni/gl-modem-community/issues/67)) ([85d7fdc](https://github.com/rudironsoni/gl-modem-community/commit/85d7fdc71ecbe6f975a032e8e0ab14e247de2efd))
* **deps:** bump debian from `7b140f3` to `abd67ff` in /tools/sdk-container ([#65](https://github.com/rudironsoni/gl-modem-community/issues/65)) ([1de5ab7](https://github.com/rudironsoni/gl-modem-community/commit/1de5ab7c5bedeb41533b0506e7e6fbe3d334f2ae))

## [0.2.10](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.9...v0.2.10) (2026-08-07)


### Miscellaneous Chores

* trigger release workflow after fixing release-please state ([8a9a09c](https://github.com/rudironsoni/gl-modem-community/commit/8a9a09c48972d0876495500cf25f55c471c13435))
* trigger release workflow after v0.2.9 tag ([8b13b9f](https://github.com/rudironsoni/gl-modem-community/commit/8b13b9f9aed34fd7ae1e7e77c45b78c17a137b15))

## [0.2.7](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.6...v0.2.7) (2026-08-06)


### Documentation

* add web-based opkg feed via GitHub Pages ([#40](https://github.com/rudironsoni/gl-modem-community/issues/40)) ([26667a0](https://github.com/rudironsoni/gl-modem-community/commit/26667a01dea46b180df961e7f385139a31ab6b1c))

## [0.2.6](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.5...v0.2.6) (2026-08-06)


### Documentation

* add opkg feed instructions for IPK firmware ([#38](https://github.com/rudironsoni/gl-modem-community/issues/38)) ([d46e0db](https://github.com/rudironsoni/gl-modem-community/commit/d46e0db4ad467476b6f2d1ee6cde51df362d2ae5))

## [0.2.5](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.4...v0.2.5) (2026-08-06)


### Bug Fixes

* remove AT+CFUN rewrite and synthetic OK from FM350 compat library ([#36](https://github.com/rudironsoni/gl-modem-community/issues/36)) ([958b79b](https://github.com/rudironsoni/gl-modem-community/commit/958b79bfc615c2482359c466fc0840b9493baee1))

## [0.2.4](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.3...v0.2.4) (2026-08-05)


### Bug Fixes

* **build:** extract APK metadata via adbdump --format json ([#34](https://github.com/rudironsoni/gl-modem-community/issues/34)) ([fc6090a](https://github.com/rudironsoni/gl-modem-community/commit/fc6090aebd18c447cdddf1c4a9c88be4fe624a42))

## [0.2.3](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.2...v0.2.3) (2026-08-05)


### Bug Fixes

* **build:** extract APK metadata from .PKGINFO tar entry ([#32](https://github.com/rudironsoni/gl-modem-community/issues/32)) ([b6b9b84](https://github.com/rudironsoni/gl-modem-community/commit/b6b9b84a360358d5dbce9d37175b61e16a3a950d))

## [0.2.2](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.1...v0.2.2) (2026-08-05)


### Bug Fixes

* **build:** extract APK metadata from control tar instead of apk info ([#30](https://github.com/rudironsoni/gl-modem-community/issues/30)) ([94054ff](https://github.com/rudironsoni/gl-modem-community/commit/94054ff1bdec022db47a872aae1c48b4e4e6efb3))

## [0.2.1](https://github.com/rudironsoni/gl-modem-community/compare/v0.2.0...v0.2.1) (2026-08-05)


### Bug Fixes

* **build:** drop --all from apk info metadata extraction ([#28](https://github.com/rudironsoni/gl-modem-community/issues/28)) ([def1209](https://github.com/rudironsoni/gl-modem-community/commit/def12093980d3c5b52f4a1f2f3c1b4ec9728bca2))

## [0.2.0](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.13...v0.2.0) (2026-08-05)


### Features

* support all GL-MT3000 firmware channels ([2da6b00](https://github.com/rudironsoni/gl-modem-community/commit/2da6b0030df616a8accf06ea0d35f41cd279819e))
* support all GL-MT3000 firmware channels ([4342515](https://github.com/rudironsoni/gl-modem-community/commit/43425152f9bd94adead0217209458f0b236b1d95))


### Bug Fixes

* **modem:** inject FM350-GL Option module IDs at boot and hotplug ([#27](https://github.com/rudironsoni/gl-modem-community/issues/27)) ([ab8522c](https://github.com/rudironsoni/gl-modem-community/commit/ab8522c2dc5e102054574c31f2b77cf3e150de82))
* reconcile FM350 bus re-enumeration ([ddae0e7](https://github.com/rudironsoni/gl-modem-community/commit/ddae0e74abc6df7b318cae92397edf0fac0f7f17))
* reconcile FM350 bus re-enumeration ([caa83fa](https://github.com/rudironsoni/gl-modem-community/commit/caa83fa880479d40d4687848ac4ab232289f6083))


### Documentation

* refresh firmware compatibility evidence ([0276a0f](https://github.com/rudironsoni/gl-modem-community/commit/0276a0fc4575bbfac49a769b6e5260e3721020d3))
* refresh firmware compatibility evidence ([3b658f9](https://github.com/rudironsoni/gl-modem-community/commit/3b658f9e2f4afc38293f9addd64cc8ba48ce1a91))

## [0.1.13](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.12...v0.1.13) (2026-07-23)


### Bug Fixes

* make runtime lifecycle reversible ([9c3f228](https://github.com/rudironsoni/gl-modem-community/commit/9c3f2285045f53b65416dd0c0b8fb29157fc0f96))
* make runtime lifecycle reversible ([a4d3ce7](https://github.com/rudironsoni/gl-modem-community/commit/a4d3ce74804dcd2593aa4336f98e5da2213ae25c))


### Documentation

* clarify firmware compatibility status ([2dd9eb1](https://github.com/rudironsoni/gl-modem-community/commit/2dd9eb1b3bd10cc7a7b0740522179d1722cd5da5))
* clarify firmware compatibility status ([0961b63](https://github.com/rudironsoni/gl-modem-community/commit/0961b639c653d6df18c08b71070d03fe7091f9ac))

## [0.1.12](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.11...v0.1.12) (2026-07-22)


### Bug Fixes

* **release:** stabilize LuCI APK feed ([344d19a](https://github.com/rudironsoni/gl-modem-community/commit/344d19ac0c5f921fd15ad9614317c8da9dcc9f43))

## [0.1.11](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.10...v0.1.11) (2026-07-21)


### Bug Fixes

* **ci:** cache readable SDK archives ([456d4e9](https://github.com/rudironsoni/gl-modem-community/commit/456d4e98bae9eb886db5beff57d4b18f9f5f1aaf))
* **ci:** cache readable SDK archives ([6bcce98](https://github.com/rudironsoni/gl-modem-community/commit/6bcce98898a2af5c853edd1ea9797e8944d1e07b))


### Documentation

* reframe project for community modem support ([28a69dc](https://github.com/rudironsoni/gl-modem-community/commit/28a69dcd12fcd821954cd11b0269d8f9757c3da1))
* rewrite project README ([bee2915](https://github.com/rudironsoni/gl-modem-community/commit/bee2915d79860801c1da69451c26637ee7410b9b))


### Continuous Integration

* harden package builds and signed releases ([ac9b38c](https://github.com/rudironsoni/gl-modem-community/commit/ac9b38c7c3c501aa98969df8c2f7f293e14975a8))
* harden package builds and signed releases ([c9366b7](https://github.com/rudironsoni/gl-modem-community/commit/c9366b79438362e702e1359e91e0200c6e4f00ab))

## [0.1.10](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.9...v0.1.10) (2026-07-20)


### Bug Fixes

* expose Linux preload interfaces ([8e4806d](https://github.com/rudironsoni/gl-modem-community/commit/8e4806d0645ad3018ed6b3c6d47caa4c74a3eebf))
* expose Linux preload interfaces ([98552a6](https://github.com/rudironsoni/gl-modem-community/commit/98552a6f4095b99bd5eb6fd56d544e33d86320a0))

## [0.1.9](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.8...v0.1.9) (2026-07-20)


### Bug Fixes

* recover FM350 cold activation ([81b9a20](https://github.com/rudironsoni/gl-modem-community/commit/81b9a20ba2a30248412125631b55e35de6b89423))
* recover FM350 cold activation ([a82fbbc](https://github.com/rudironsoni/gl-modem-community/commit/a82fbbcd62036a96f5ab10045479b5bdc31e7822))

## [0.1.8](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.7...v0.1.8) (2026-07-20)


### Bug Fixes

* route FM350 setup through stock modem transport ([4d11d73](https://github.com/rudironsoni/gl-modem-community/commit/4d11d73c78c9c475a245c460daa9bff05ca21507))

## [0.1.7](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.6...v0.1.7) (2026-07-20)


### Bug Fixes

* repair FM350 interface after stock discovery ([fa564ca](https://github.com/rudironsoni/gl-modem-community/commit/fa564cae037598f6bd2d22177fcaa3656e56e778))

## [0.1.6](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.5...v0.1.6) (2026-07-20)


### Bug Fixes

* restore stock FM350 network interface ([e08c5a0](https://github.com/rudironsoni/gl-modem-community/commit/e08c5a09113dcdaa8dc19992cc1e3b94f950dc21))

## [0.1.5](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.4...v0.1.5) (2026-07-20)


### Bug Fixes

* bridge FM350 CID into stock modem lifecycle ([2d3ba9d](https://github.com/rudironsoni/gl-modem-community/commit/2d3ba9d80a1e60f768580c12811988ff46ce3309))

## [0.1.4](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.3...v0.1.4) (2026-07-20)


### Bug Fixes

* keep FM350 netifd session active ([d65dd98](https://github.com/rudironsoni/gl-modem-community/commit/d65dd9823d82815fb284088ac5d4bbad3099bcd5))

## [0.1.3](https://github.com/rudironsoni/gl-modem-community/compare/v0.1.2...v0.1.3) (2026-07-20)


### Bug Fixes

* **ci:** allow manual release recovery ([67b78d8](https://github.com/rudironsoni/gl-modem-community/commit/67b78d80ea56de42c28aaf4c259467844d97c259))
* **ci:** validate released manifest state ([67ddfa5](https://github.com/rudironsoni/gl-modem-community/commit/67ddfa53c3958e4f34c56bc8e42529591a265243))

## 0.1.2 (2026-07-20)


### Features

* add community FM350 backend package ([4b0ab98](https://github.com/rudironsoni/gl-modem-community/commit/4b0ab988857f267df6350fea60b5d4303cfb6c7e))


### Bug Fixes

* adapt FM350 PDP setup ([95e8154](https://github.com/rudironsoni/gl-modem-community/commit/95e8154f3571dd99a7048217303afc3ee6211549))
* map FM350 ttyUSB AT ports ([a007be7](https://github.com/rudironsoni/gl-modem-community/commit/a007be7e21fab508650bb48f10d2593946783fd3))


### Documentation

* analyze FM350 integration gap ([a342f98](https://github.com/rudironsoni/gl-modem-community/commit/a342f98ac5a61d5acca51e073a60c6d9bbbb6ea6))
* document OpenWrt community CI/CD patterns ([3631104](https://github.com/rudironsoni/gl-modem-community/commit/36311040ad6a31ddd0cbd77aeaaf8c558c9429c5))
* map stock cellular architecture ([84d71cb](https://github.com/rudironsoni/gl-modem-community/commit/84d71cb899eed93aa97dc22f47dae60ec2cf5f26))


### Build System

* add OpenWrt 24 OPKG artifact ([7b07bad](https://github.com/rudironsoni/gl-modem-community/commit/7b07badfb2f5c716667ef95abe3e1644eb5a71f6))


### Continuous Integration

* update GitHub Actions runtimes ([881c0c2](https://github.com/rudironsoni/gl-modem-community/commit/881c0c27b1b1f58d9758231b87512c905635bf4c))
* upgrade Release Please to v5 ([7bb640c](https://github.com/rudironsoni/gl-modem-community/commit/7bb640ce1f2719ed182d7e729d562b077693a3b9))


### Miscellaneous Chores

* add automated releases ([a65f181](https://github.com/rudironsoni/gl-modem-community/commit/a65f181b18fc3c8fec6ed4b601e8087ff607fadc))
* add reproducible firmware acquisition ([bfab737](https://github.com/rudironsoni/gl-modem-community/commit/bfab7374b47d944b8f037876d02f19fb0d0ba297))
