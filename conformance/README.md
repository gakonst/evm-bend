# Pinned Amsterdam state conformance

The completed gate is all **15,918 state fixtures**, passing on both native Bend and JavaScript. The full inventory also contains blockchain and standalone transaction fixtures (40,911 required cases total); those additional formats are outside this state gate and remain unfinished. See [STATE-PROGRESS.md](STATE-PROGRESS.md) for current measured results.

`full_state_gate.py` executes every state fixture, compares its expected exception or success, state root, logs hash, and output when specified, and retains the full denominator. Blocked cases, host errors, timeouts, and failures never count as passes. Resume accepts only matching fixture hashes and exact implementation fingerprints. A final passing report requires all 15,918 fixtures and an unchanged fingerprint.

```sh
./conformance/build_transactions.sh
python3 conformance/full_state_gate.py --backend native --workers 12 --timeout 1200 --output state-gate-host-hardened
python3 conformance/full_state_gate.py --backend js --workers 12 --timeout 3600 --output state-gate-host-hardened
```

These commands require the pinned corpus and built Rust helpers described below and in the root README. The timeout is a host resource deadline, not an EVM exception. Full JavaScript execution follows the native gate.

Signed envelopes use the strict wire/crypto decoder in `envelope-host`. EVM execution, validation, transaction gas accounting, and settlement run in Bend. Rust supplies cryptographic precompiles, authorization recovery, trie commitments, and a separate differential oracle. Total transaction gas uses a 256-bit Word; bounded execution counters are backed by exact outer gas accounting. Inputs are limited to 16 MiB by the wire adapter; an exceeded limit is explicit and cannot count as a passing fixture.

`test_transaction_integration.py` checks 22 decoded synthetic transactions against revm, including complete state and logs commitments, output, and gas. These are supplementary checks, not substitutes for signed state fixtures. [EXCEPTION-MATCHING.md](EXCEPTION-MATCHING.md) documents the pinned EEST exception-alias contract.

`corpus-manifest.json` pins execution-specs commit `7341820b5b394b1934dfe7bb6f621fcdab7baf7f`, release `tests-glamsterdam-devnet@v8.1.4`, and archive SHA-256 `aed315489163dc67c4e5607d7bbb8902e8329afe939be58193b125f2e81a85d4`. The multi-gigabyte corpus and compiled binaries are not source-repository artifacts.
