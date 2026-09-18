# Admission repair evidence

Fresh original-selection runs: **JS 935 passed, 0 failed, 0 errors** (75.36s); **native 935 passed, 0 failed, 0 errors** (30.48s). Both have 915 Bend decisions and 20 crypto rejections. Fixture IDs, hashes, paths, post indices and order exactly match the original 935 selection. Admission only: no accepted EVM execution, state roots, or logs roots were checked.

Historical JS 875/54/6 and native-all 15,863/55/0 results remain unchanged, with preserved copies in `admission-repair-evidence/before/` and SHA-256 manifest `before.sha256`. All 54 JS and 55 native label failures are actual floor-specific rejection versus generic intrinsic-gas expectation. The main pinned mapping supplies aliases from actual reason 20 alone; expected fixture data is used only in final comparison. Unknown reasons remain errors, and Bend reason/exception consistency is checked.

All six old JS errors were rerun before rebuilding. Each exited 1 with `bend: memory fault (machine stack overflow?)`; input sizes were 132,050–263,044 bytes. Full stdout/stderr and IDs are in `admission-repair-evidence/six-errors-before.jsonl`. The helper codec's non-tail-recursive byte reader was replaced by the exact main accumulator/reverse implementation; the codec diff contains only that change. All six now pass on both backends. Existing tail-recursive bytes.len was unchanged. No validation laws or rejection semantics changed.

The harness now uses `A.signed_authorities` for signed envelopes, the explicit wire/crypto exception allowlist, and crypto recovery for unsigned fixture authorizations instead of fixture signer fallback. It retains stderr on process failures, enforces the 16MiB transport limit, accepts `--output-prefix`, and refuses to overwrite prior results. Contract checks cover reason-20 aliasing, non-widening of reason 8, unmapped reasons 1/100/999, missing/inconsistent authority recovery fields, non-crypto recovery errors and explicit null crypto failure (`contract-checks.json`: all true).

Commands (cwd `/srv/nanocodex/workspace/evm-bend-transactions`):

```text
python3 full/admission-repair-evidence/diagnose.py
cp /srv/nanocodex/workspace/evm-bend/full/codec.bend full/codec.bend
BEND_NO_TELEMETRY=1 ./bend-local.sh full/transaction-rejection-driver.bend -o full/transaction-rejection-driver.js > full/admission-repair-evidence/build-js.log 2>&1
JS identifier normalization: re.sub(r'\$[\w$-]+',lambda m:m[0].replace('-','_'),source)
PATH=/srv/nanocodex/.cargo/bin:$PATH BEND_NO_TELEMETRY=1 ./bend-local.sh full/transaction-rejection-driver.bend -o full/transaction-rejection-driver.native > full/admission-repair-evidence/build-native.log 2>&1
python3 full/transaction-admission-corpus.py --backend js --workers 8 --output-prefix full/admission-repair-evidence/repaired-js > full/admission-repair-evidence/repaired-js.log 2>&1
python3 full/transaction-admission-corpus.py --backend native --workers 8 --output-prefix full/admission-repair-evidence/repaired-native > full/admission-repair-evidence/repaired-native.log 2>&1
```

SHA-256:

- Rebuilt JS: `68b3ebc0f33337af148e93de53de14905930a28c364b51c3b96d3e50ceadd365`
- Rebuilt native: `15e4c324f75a58e69ba7efa4b109eba172911fe9b7ede0eb93c5c085e63731dd`
- Codec: `64dbafd30e2fc3854c9cff9b3875c8f2423ade5e315667933c8e907262a98b2d`
- Harness: `0f2941d4665fd0f1eecd0cb5edb4c34d606a190f56b46e57d806ee18d541e7e0`
- Patch: `282c17b14c9bb7bffe51972cf59e787c7ac555ea36320d7279c5905773d6edb2`

Auditable two-source patch: `admission-repair-evidence/admission-repair.patch`. Per-case fresh results: `repaired-js.jsonl` and `repaired-native.jsonl` beneath that directory. Per-run JSON includes source/binary hashes; shared dependency hashes and Python/Markdown snapshots are beside them. Machine-readable summary: `transaction-admission-repair-summary.json`.

No remaining failure in the selected 935 admission cases. Full 15,918 native admission corpus was not rerun; its historical results are preserved. Main workspace and main binaries were not edited. No publication was performed. These results do not establish full EVM execution conformance or a correctness proof.
