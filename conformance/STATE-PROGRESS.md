# Pinned Amsterdam state gate

Current native: **15,918 / 15,918 passed**, zero failed, blocked, skipped, or host-error cases. The fresh combined-source run completed in 391 seconds and verified that its implementation fingerprint was unchanged. The fresh full JavaScript gate is running; no complete JavaScript pass is claimed yet.

The previous JavaScript run exposed four host stack overflows in maximum-size jump-destination scans. The scan is now tail-recursive, preserving PUSH-data exclusion and EIP-8024 immediate semantics. All six related fixtures pass on both backends. The combined source also includes exact EXP early termination, checked by all 6,733 arithmetic cases and 320 extra EXP vectors per backend.

The immediate scope is the 15,918 state fixtures in `tests-glamsterdam-devnet@v8.1.4`, pinned to execution-specs `7341820b5b394b1934dfe7bb6f621fcdab7baf7f`. The broader inventory contains 40,911 required state, blockchain, and transaction fixtures; the additional formats remain unfinished. Passing tests is not a formal correctness proof.

See [native-state-gate-summary.json](native-state-gate-summary.json) for the exact count, command, implementation fingerprint, binary hash, and journal hash, and [integrated-build-provenance.json](integrated-build-provenance.json) for source and compiler hashes.

Execution and transaction semantics remain in Bend. The integrated repairs cover full-Word transaction gas, precise rejection facets and pinned EEST aliases, checked memory charging, missing EIP-8024 immediates and jump destinations, persistent sparse memory, immutable calldata views, stack-safe large byte processing, storage warmth as a set, constant-time code emptiness, and exact limb comparisons. The host supplies only the established crypto/wire/commitment boundaries.

Supplementary checks on the integrated binaries passed 624 prepared-frame differentials and 22 transaction integrations per backend. The comparison change passed 1,316 independent vectors per backend. Large byte/view/memory-cost regressions pass on both backends. The previously slow static-call fixture passes on JavaScript with exact roots and logs in 126 seconds; its earlier 120-second timeout is not counted as a pass. The full JavaScript gate uses a 3,600-second host deadline.

The mandatory core proof, mutation, and differential checks also pass. These supplemental suites do not replace the full state gate.
