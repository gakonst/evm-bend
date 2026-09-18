# Validation record

> Host-bridge hardening update: the adapter has changed since the complete runs below. Eight fixture-backed bridge tests and 11 runner tests pass; the exhaustive bridge audit reports zero mismatches or host limits. Fresh full native and JS execution gates are pending for this new fingerprint. Prior 15,918/15,918 results remain valid only for their recorded implementation. See conformance/HOST-BRIDGE-PROGRESS.md (HOST-BRIDGE-PROGRESS.md within conformance).

This is execution evidence for the pinned Amsterdam interpreter, not a correctness proof.

| Suite | Completed evidence |
|---|---|
| Official pinned Amsterdam state gate | 15,918 fixtures x 2 backends, all pass; no skipped, blocked, failed, or host-error cases |
| Full prepared-frame differential | 624 cases x 2 backends, zero mismatches |
| Decoded transaction integration | 22 cases x 2 backends, complete state/log commitments match |
| Large jump-destination fixtures | 6 cases x 2 backends, all pass |
| Additional EXP vectors | 320 cases x 2 backends, all pass |
| Precompile differential | 74 checks, zero mismatches |
| Actual contract / valid crypto fixtures | 22 checks, zero mismatches |
| State reservoir / rollback invariants | 56 checks, zero failures |
| Word arithmetic | 6,733 cases x 2 backends, all pass |
| Keccak | 15 cases x 2 backends |
| Earlier Shanghai subset | 452 Python and 436 evm2 comparisons pass |
| Existing proof mutation gate | 5 semantic mutants rejected |

The complete state gate is recorded in [conformance/state-conformance-complete.json](conformance/state-conformance-complete.json). Both runs verified unchanged fingerprints. An independent audit confirmed all 15,918 required fixture IDs occur exactly once per backend, all fixture hashes match the pinned inventory, and every post variant passes with state and logs commitments present. Source/compiler/binary hashes are in [conformance/integrated-build-provenance.json](conformance/integrated-build-provenance.json).

Other machine-readable results are the corresponding `*-results.json` and `full-differential-*.json` files. The prepared-frame differential reconciles intrinsic gas and compares reference-reported storage writes; the official state gate compares complete post-state and logs commitments. No complete opcode or journal refinement theorem is claimed.

`benchmark-results.json` records a local end-to-end baseline. Native 1,000-iteration loop median was ~0.101 seconds, including startup and JSON handling, with no claim of equivalence to an isolated revm throughput benchmark.

Known toolchain workarounds are described in README.md and `toolchain-layout.patch`. The current EXP implementation passed a fresh complete 6,733-case arithmetic suite on each backend, plus 320 independent EXP vectors.
