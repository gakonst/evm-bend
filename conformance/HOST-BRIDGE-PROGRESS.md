# Host-bridge hardening progress

Signed-byte requests no longer require redundant transaction metadata. Signed fields override fixture annotations. Missing or inconsistent authority recovery is a host error; explicitly unrecoverable authority signatures remain null. Decoder errors must belong to the pinned wire/cryptographic vocabulary before they can produce transaction rejections. Bend semantic rejection mapping and 256-bit gas serialization are preserved.

Verified: 8 fixture-backed bridge tests and 11 runner tests pass. The exhaustive serialization/context audit checked 15,918 contexts and 15,898 decoded transactions, including both accepted gas values above Nat48; 7,329 authorizations were preserved, including 21 unrecoverable signatures. All 20 wire rejection commitments and 933 expected-rejection prestate commitments match. Zero unexpected bridge mismatches or host limits. These are bridge checks, not EVM execution passes.

Fresh full execution now passes **15,918/15,918 on native and 15,918/15,918 on JavaScript**, with zero failures, skips, unsupported cases or host errors. Independent verification rechecked every post commitment, unique inventory IDs, fixture hashes, current fingerprints and the unchanged source/binary manifest. Native took 462.06s; JavaScript took 1905.49s. Execution source is `a4e6187de6c0c0736534301973c23310acde68cc`. No Bend source or binaries changed.

[Current evidence](state-conformance-host-hardened.json) records the new adapter SHA and exact commands. Previous completion evidence remains unchanged in state-conformance-complete.json (published at 35db6bfb7464a12a8013f5ce61dde6876813be91).

```sh
python3 -m unittest discover -s conformance -p test_host_bridge.py -v
python3 -m unittest discover -s conformance -p test_runner.py -v
python3 conformance/audit_host_bridge.py
python3 -u conformance/full_state_gate.py --backend native --workers 12 --timeout 1200 --output state-gate-host-hardened
python3 -u conformance/full_state_gate.py --backend js --workers 12 --timeout 3600 --output state-gate-host-hardened
```

Audit caches, raw corpus, and binaries are excluded from publication. Summary: host-bridge-summary.json. Both complete runs retain exact fingerprints and every fixture ID.

## Isolated transaction-helper audit

The parent reported a read-only audit of the separate `evm-bend-transactions` workspace: `transaction-admission-js-rejected.json` contains 935 selected admission-only cases, with 875 passes, 54 failures and 6 errors. This partial result is not a clean conformance pass. The 54 mismatches were floor-specific actual exceptions versus generic intrinsic-gas expectations; main already handles that pinned alias in `rejection_mapping.py` and `EXCEPTION-MATCHING.md`. The parent independently found all 60 helper non-pass IDs passing in both historical `state-gate-complete` journals; that comparison is historical evidence, not a fresh execution claim. The parent also reported 20 focused unit passes per backend.

No pinned state mapping gap was identified. The helper's shared `validate_word` refactor, unsupported-type reason and reordered blob checks were not merged. The helper follow-up's provider 400 `unsupported_parameter access_programs.cyber` was an infrastructure failure, separate from the admission results above. No implementation files changed for this note; the independently verified fresh main runs recorded in `state-conformance-host-hardened.json` remain 15,918/15,918 passing on each backend.

## Isolated admission repair completed

The original JS admission result (875 pass, 54 fail, 6 error) and native-all admission result (15,863 pass, 55 fail) remain preserved. A subsequent isolated repair uses the existing fixed reason-20 aliases and tail-recursive byte decoding; all six JS errors were reproduced as stack-overflow memory faults before repair. Fresh runs of the identical 935-case selection pass 935/935 on each backend, with zero failures or errors. The root agent independently checked exact selected IDs and recorded source hashes. These are admission-only checks, not accepted execution or root checks; main source and its complete execution gates are unchanged. See [repair report](TRANSACTION-ADMISSION-REPAIR.md) for commands, hashes, and evidence locations.
