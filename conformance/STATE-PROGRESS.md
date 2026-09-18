# State conformance integration — incomplete

Target: all 15,918 pinned Amsterdam state fixtures on actual Bend native and JS.
Pin: `7341820b5b394b1934dfe7bb6f621fcdab7baf7f` (`tests-glamsterdam-devnet@v8.1.4`).

The transaction entrypoint now uses full Word gas, with a bounded active state-gas window and full-width escrow/settlement in Bend. The host only serializes inputs, performs wire/cryptographic operations, and computes commitments. Native verification passes both signed fixtures above 2^48 gas and all 22 decoded transaction integration cases.

The integrated native build passes 24 previously failing memory-overflow and EIP-8024 state fixtures, comparing exact state/log roots and exception outcome. EIP-8024 missing immediate bytes read as zero; legacy jump-destination scanning skips PUSH data only. LOG and EXTCODECOPY charge memory with checked arithmetic before accessing memory.

Of 933 fixtures expecting rejection, 878 pass exact exception and state/log commitment checks. The remaining 55 are rejected with correct commitments but differ between generic intrinsic-gas and floor-specific exception names. Their pinned matching rules remain under audit; they are failures, not passes. Large-code host timeouts and the complete native/JS gate remain outstanding. Earlier arithmetic/frame regression results predate these changes and are not fresh validation of this snapshot.

Build transaction executables: `conformance/build_transactions.sh` (crypto hosts must already be built as documented in the main README).

Run the complete gate:

```sh
python3 conformance/full_state_gate.py --backend native --workers 8
python3 conformance/full_state_gate.py --backend js --workers 8
```

`--resume` reuses only passing rows with the exact implementation fingerprint. Host errors, unsupported results, unknown statuses, timeouts, and unrun cases cannot pass. Full-suite success is not a formal correctness proof.
