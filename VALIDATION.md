# Validation record

This is execution evidence for the pinned Amsterdam interpreter, not a correctness proof.

| Suite | Completed evidence |
|---|---|
| Full EVM differential | 616 cases x 2 backends, zero mismatches |
| Delegation / storage context / CREATE2 | 8 additional cases x 2 backends, zero mismatches |
| Precompile differential | 74 checks, zero mismatches |
| Actual contract / valid crypto fixtures | 22 checks, zero mismatches |
| State reservoir / rollback invariants | 56 checks, zero failures |
| Word arithmetic | 6,733 cases x 2 backends, all pass |
| Keccak | 15 cases x 2 backends |
| Earlier Shanghai subset | 452 Python and 436 evm2 comparisons pass |
| Existing proof mutation gate | 5 semantic mutants rejected |

Machine-readable results are the corresponding `*-results.json` and `full-differential-*.json` files. Differential gas compares pre-refund spending after reconciling transaction intrinsic gas. Storage comparison checks writes reported by the reference; it is not a full trie/state-root comparison. The selfdestruct list is pending transaction finalization. No complete opcode or journal refinement theorem is claimed.

`benchmark-results.json` records a local end-to-end baseline. Native 1,000-iteration loop median was ~0.101 seconds, including startup and JSON handling, with no claim of equivalence to an isolated revm throughput benchmark.

Known toolchain workarounds are described in README.md and `toolchain-layout.patch`. Native arithmetic validation was interrupted by a Hand reconnect and resumed at the verified 2,496-case boundary; retained logs and the combined final result identify the ranges.
