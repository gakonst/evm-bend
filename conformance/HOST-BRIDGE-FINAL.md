# Host-bridge revalidation complete

Execution source: `a4e6187de6c0c0736534301973c23310acde68cc` (tree `a652b6e337da8a6fe3ce00655283597a79123cb3`).

| Backend | Passed | Other outcomes | Seconds |
|---|---:|---:|---:|
| native | 15,918 / 15,918 | 0 | 462.06 |
| js | 15,918 / 15,918 | 0 | 1905.49 |

Both exact inventories and every post commitment independently rechecked; current fingerprints and all source/binary manifest entries match. Adapter SHA-256: `80dd779d577bc5cdf2d5f0e7229f7b76db235b6f9965ccf2812009e2febde8be`.

```sh
python3 -u conformance/full_state_gate.py --backend native --workers 12 --timeout 1200 --output state-gate-host-hardened
python3 -u conformance/full_state_gate.py --backend js --workers 12 --timeout 3600 --output state-gate-host-hardened
python3 conformance/host-hardened-evidence/verify.py native
python3 conformance/host-hardened-evidence/verify.py js
```

Machine evidence: state-conformance-host-hardened.json; per-backend evidence: native-host-hardened-summary.json and js-host-hardened-summary.json. Raw and deterministic gzip journals remain in state-gate-host-hardened/ on this host; hashes are recorded in the evidence. No corpus, caches or binaries are published. Previous state-conformance-complete.json is preserved.

This completes host-bridge state revalidation only. Broader blockchain/standalone transaction conformance and formal proof remain unfinished.
