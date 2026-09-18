# Isolated Amsterdam complete-state oracle

Parent integration source: `revm-adapter/{Cargo.toml,Cargo.lock,src/main.rs,src/commitment.rs,fixtures/stop.json}`. Original project was not edited. Rust executes REVM only as a differential oracle; commitment mode performs cryptography only and is suitable for Bend-produced state.

Reference inspected: adjacent evm2-reference commit `0a5314efb28cbef7dc1a83e38ac75860b974adcd`, especially crates/eest/src/{execute,state,tx,env}.rs. The Amsterdam blob update fraction is explicitly 11684671, matching that reference (REVM's new_with_spec helper otherwise uses Prague). Cargo.lock pins the actual dependency resolution, including revm 43.0.0 and alloy-trie 0.9.5.

## Build and protocol

From `/omarchy-desktop/evm-bend-conformance-oracle` as the tool workdir (native path `/srv/nanocodex/workspace/evm-bend-conformance-oracle`):

```
/srv/nanocodex/.cargo/bin/cargo test --locked --manifest-path revm-adapter/Cargo.toml
/srv/nanocodex/.cargo/bin/cargo run --quiet --locked --manifest-path revm-adapter/Cargo.toml < revm-adapter/fixtures/stop.json
```

JSON Lines stdin/stdout, one independent invocation per line. Default `mode: transaction` retains old fields, defaults, status vocabulary, and state delta. New transaction fields:

- `tx_type`: explicit integer 0/1/2/3/4; `create`: bool (otherwise call target).
- `chain_id`: optional u64; `cfg_chain_id`: u64 default 1.
- `max_fee_per_gas`, `max_priority_fee_per_gas`: optional u128 JSON integers; max fee overrides legacy gas_price.
- `access_list`: array `{address,storageKeys:[32-byte hex strings]}`.
- `blob_hashes` (alias `blob_versioned_hashes`): 32-byte hex strings; `max_fee_per_blob_gas`: u128.
- `authorization_list`: signed EIP-7702 objects `{chainId,address,nonce,yParity,r,s}` in Alloy serde format (hex quantity strings supported); signatures are recovered by REVM, not trusted recovered addresses.
- `block_hashes`: object mapping decimal block number strings to 32-byte hashes.
- `strict`: true for fixtures; disables automatic caller funding and enforces chain-ID checks. False preserves legacy behavior.

Block fields: old gas_limit/basefee/beneficiary/prevrandao, number/timestamp (old JSON u64 integers or U256 strings), plus difficulty (U256 string), slot_num (u64), excess_blob_gas (u64), blob_gasprice (optional explicit u128 override). Code/calldata remain byte arrays; balances/value/storage quantities remain strings; transaction gas/nonce/chain IDs use JSON integers. Block gas defaults 30 million. Types are not inferred; specify tx_type for typed transactions. This is an adapter API, not a raw EEST JSON parser.

Successful execution adds sorted `post_allocation` with every surviving account, full bytecode, balance, nonce, and all nonzero storage, including untouched prestate. It applies REVM committed changes and removes touched empty accounts (EIP-161), preserving untouched explicit empty accounts. Existing state.accounts/state.storage delta stays available.

Gas fields: gas_used (transaction charged gas), total_gas_spent (before refunds), state_gas_spent, block_regular_gas_used, block_state_gas_used, gas_refunded (EIP-3529-capped before floor adjustment), effective_gas_refunded (after floor adjustment), floor_gas. Uncapped interpreter refund counter is not exposed by this REVM result API. Also returns created_address, stateRoot, logsHash.

## Pure commitment mode

```
{"mode":"commitment","accounts":[{"address":"0x0000000000000000000000000000000000000001","balance":"0x1","nonce":0,"code":[],"storage":[["0x0","0x2"]]}],"logs":[]}
```

Alternatively use `alloc` or `allocation` address-keyed objects (only one allocation field). Commitment code accepts hex byte strings or arrays; storage may be an object or key/value pairs. Existing empty accounts are included, zero storage omitted, duplicate accounts/slots rejected. It never executes code, funds callers, or deletes empty accounts. It returns stateRoot/logsHash and identical state_root/logs_hash aliases. Secure Ethereum MPT keys are keccak(address) and keccak(32-byte slot); values use Ethereum RLP account/storage encodings. Logs hash is keccak(RLP(logs)), not receipt root or bloom. Log ordering is preserved.

Either mode accepts `expected` object. Each supplied field is compared exactly; `verification:{passed,mismatches}` reports expected/actual differences. Compare stateRoot/logsHash for order-independent complete-state commitments; compare post_allocation for exact canonical allocation. Missing expected fields do not imply verification. Invalid transaction/input returns old rejected response; invalid commitment returns status error. Rejected transaction responses do not include full prestate; they are not executed poststates.

## Evidence and limits

16 unit tests: known empty state/log constants; independent single-leaf secure state+storage RLP vector; independent log RLP; malformed/duplicate inputs; legacy defaults; strict chain/funding rejection; types 1/2/3/4; CREATE runtime bytecode; revert storage rollback; storage clear/refund retaining other slots; block history; pinned Amsterdam blob price; expected mismatch; strict fixture checking entire allocation. The EIP-7702 test covers an invalid signature being skipped, not a valid delegation mutation. `fixtures/stop.actual.json` records a CLI fixture result with verification.passed=true. Its stateRoot is d9666ef0c2313ba91a50a8b4d40c48ca5c09edfecf68a6e4b945f2ec8bfc04a3.

This is a single-transaction execution oracle, not block processing: no withdrawals, beacon/history system calls, block reward, cumulative block gas constraints, receipt trie, or transaction signature/envelope validation. Caller is supplied explicitly. Parent must supply system-call effects in prestate or implement block processing separately. Arbitrary allocation commitments are complete, but tests are selected coverage, not full EEST execution or formal conformance proof. No Bend execution semantics were replaced. REVM semantics remain an independent implementation, not proof of equivalence to pinned evm2/execution-specs.
