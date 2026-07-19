# Firmware acquisition

Conclusion: [CONFIRMED] The analyzed file is the exact supplied GL-MT3000 OpenWrt 25 beta image.

Evidence: URL `https://fw.gl-inet.com/firmware/mt3000-open/testing/mt3000-op-4.9.1-op25_beta1-1032-0707-1783421663.bin`; retrieval date `2026-07-19` UTC; size `76,622,158` bytes; MIME `application/octet-stream`; HTTP `200`; last modified `Tue, 07 Jul 2026 11:49:48 GMT`.

Hashes:

| Algorithm | Digest |
|---|---|
| SHA-256 | `423c4f495385d51f829f436a494fe88a0ebd5bd7cc86f436a9ff3ae05f87891b` |
| SHA-512 | `561404e7bbe0604a92b9c5d9ec8eac07818b9f7517d822bd3cb42739fe90696e69cb48c4814682f962c8928043c13ca736b4497a6ef8d188bd5d78effd1678fa` |
| BLAKE2b-512 | `9b76a8580971bce2522ad5972e6dbad9e7ecb022a49c4108117eec400a9022546c2ddebb90904aec0a8c2933d946969f708f00793a207f2dde71296f0f505a45` |

Confidence: confirmed.

Alternative explanations: none for file identity after byte count and three hashes. Authenticity beyond transport and the image's own metadata was not independently attested.

How to verify dynamically: run `make download verify` and compare `analysis/hashes/` and `analysis/reports/firmware-http-headers.txt`.

The firmware and HTTP body are ignored by Git.
