# Pinned Amsterdam state gate: complete

| Backend | Passed | Failed / blocked / skipped / host error | Duration |
|---|---:|---:|---:|
| Native | 15,918 / 15,918 | 0 | 462.06 seconds |
| JavaScript | 15,918 / 15,918 | 0 | 1,905.49 seconds |

Both fresh complete runs verified unchanged implementation fingerprints. An independent audit confirmed every required fixture ID appears exactly once per backend, fixture hashes match the pinned inventory, all post variants pass, and current source/binary hashes match the recorded manifests. No old pass rows were reused across implementation changes.

The corpus is `tests-glamsterdam-devnet@v8.1.4`, execution-specs commit `7341820b5b394b1934dfe7bb6f621fcdab7baf7f`, archive SHA-256 `aed315489163dc67c4e5607d7bbb8902e8329afe939be58193b125f2e81a85d4`.

[Complete evidence](state-conformance-host-hardened.json), [native summary](native-host-hardened-summary.json), [JavaScript summary](js-host-hardened-summary.json), and [source/compiler/binary hashes](integrated-build-provenance.json) contain exact commands and hashes. Full local journals are `state-gate-host-hardened/native.jsonl` and `state-gate-host-hardened/js.jsonl`; their hashes are recorded in the summaries.

Execution and transaction semantics remain in Bend. The host supplies the established crypto, wire-decoding, and commitment boundaries. Repairs include full-Word gas accounting, precise rejection facets and pinned EEST aliases, checked memory charging, correct EIP-8024 immediates and jump destinations, persistent sparse memory, immutable calldata views, stack-safe byte handling and jump scanning, storage warmth as a set, constant-time code emptiness, exact limb comparison, and exact EXP early termination.

Preserved supplementary validation from before host-bridge hardening passes on both backends: 624 prepared-frame differentials, 22 decoded transaction integrations, 6,733 arithmetic cases, 320 extra EXP vectors, and six large jump-destination fixtures. Core proof, mutation and differential checks pass. Timeouts and host errors from superseded diagnostic runs were retained as non-passing results and repaired; they were never counted as passes.

This completes the requested state-test scope. The broader 40,911-case inventory also contains blockchain and standalone transaction formats, which remain unfinished. Passing this test corpus is not a formal correctness proof.
