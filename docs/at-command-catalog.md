# AT-command catalog

The machine-readable catalog is `analysis/strings/at-command-catalog.tsv`. It contains 236 command-like occurrences with source file and offset where recoverable.

Conclusion: [CONFIRMED] Generic identity, SIM, registration, signal, PDP, and attachment paths use 3GPP commands including `CGMM`, `CGMR`, `CGSN`, `CIMI`, `ICCID`, `COPS?`, `CNUM`, `CPIN?`, `CGREG?`, `CEREG?`, `C5GREG?`, `CSQ`, `CFUN`, `CGPADDR`, `CGDCONT`, `CGATT`, and `CGACT`.

Evidence: offset-preserving string catalog and libcm string groups.

Confidence: high for occurrence and apparent grouping; parser semantics are not all recovered.

Alternative explanations: some strings may be diagnostics or inactive code paths.

How to verify dynamically: log AT requests and responses for each UI operation on an officially supported modem.

Conclusion: [CONFIRMED] Advanced paths contain extensive Quectel commands including `QENG`, `QCAINFO`, `QNWPREFCFG`, `QNWLOCK`, `QCFG`, `QNWCFG`, `QSCAN`, and `QUIMSLOT`.

Evidence: catalog and `function_at_quectel` model assignments.

Confidence: high.

Alternative explanations: support for individual commands can vary by Quectel model and firmware.

How to verify dynamically: compare capability flags and emitted commands for each supported model.

Conclusion: [CONFIRMED] The stock firmware has no Fibocom function map and no identified `AT+GT...` command family in the modem backend catalog.

Evidence: full case-insensitive string search across relevant files and model table.

Confidence: high for the analyzed files, not proof that no dynamically constructed command exists.

Alternative explanations: commands could be assembled from fragments or supplied externally.

How to verify dynamically: trace serial I/O after presenting FM350 as a common modem.

Public FM350 commands from `modemfeed` are kept separate in `docs/modemfeed-source-analysis.md`; they are not evidence of stock GL.iNet behavior.
