# Transaction schema and intrinsic evidence

Normative snapshot: EELS `a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b`:

- [transactions.py, calculate_intrinsic_cost](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/transactions.py#L673-L782)
- [vm/gas.py constants](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/gas.py#L153-L174)

Read the pinned source bodies, local AMSTERDAM-SPEC.md and references/BendGuide.md before implementing. Schema is decoded input, with kind 0..4: legacy, access-list, fee-market, blob, set-code. Exact getters are generated from the constructor fields in transaction-types.bend. Sender is trusted signature recovery over the signed transaction. An authorization's authority is a trusted recovery result, None when recovery fails; this does not replace parity/scalar, chain-id, nonce, or state checks. No signature hashing or recovery is implemented in these two files.

Canonicality/type validation belongs to the entry validator. Addresses must fit 160 bits, data elements must fit 8 bits, kind must be 0..4, typed chainid must be Some, and fields absent from each EELS envelope must have canonical empty/zero values. For legacy/type1, fee_cap and tip both represent gas_price. Types2..4 use max_fee_per_gas and max_priority_fee_per_gas. Transaction gas is Nat, nonce and fees are 256-bit Word, and creation is to=None (an address-zero call remains Some{zero}).

`compute(tx)` returns Intrinsic{execution, floor, state}. State is zero: EELS explicitly charges account creation and authorization state writes during top-frame preparation, not calculate_intrinsic_cost. Execution base is 12000 plus 12000 for creation, or 3000 for non-self call plus 6000 when it transfers nonzero value. Self-transfer skips both recipient and value charges. Creation adds 2*ceil(data length/32) execution. Zero/nonzero data bytes cost 4/16 execution. All bytes cost 64 in the floor. Every typed access entry costs 2900 execution plus 1280 on both execution and floor, every key costs 2000 execution plus 2048 on both; duplicates remain chargeable. Type4 charges 7816 execution per authorization, including invalid tuples. Floor excludes authorizations and initcode-word charges. Type0 ignores the access-list field and types0..3 ignore authorizations consistently with the source branches; entry validation separately rejects malformed envelope fields.

Verification on 2026-09-18:

- `./bend-local.sh full/transaction-types.bend`: All terms check.
- `./bend-local.sh full/transaction-intrinsic.bend`: All terms check.
- Eight concrete vectors below were checked by a temporary Bend harness, both checker-normalized and compiled native: both returned True{}. All state results were zero.

| Case | execution | floor |
|---|---:|---:|
| Type0 self-transfer, nonzero value, empty data |12000|12000|
| Type0 non-self value transfer, data [0,1] |21020|21128|
| Type2 creation, data [0,1] |24022|24128|
| Type1 two duplicate addresses, two duplicate keys in first entry |31456|21656|
| Type4 one invalid authorization, empty data |22816|15000|
| Type3 non-self zero-value call, data [1] |15016|15064|
| Type2 creation, 33 zero bytes |24136|26112|
| Type0 supplied access list (intrinsic ignores; validator must reject) |15000|15000|

For all call cases sender=1, non-self recipient=2. Duplicate access entries use address9, keys zero/zero. The invalid authorization has parity9 and no recovered authority. Root independently reports ten permanent JS/native acceptance vectors in transaction-acceptance-intrinsic.bend; that file is owned by root.

Limits: these are concrete checks against source-derived expected values, not universal equivalence proofs or an executable EELS differential. Nat runtime is bounded by 2^48-1; costs and gas must fit a declared host bound. This is not a 24-bit transaction gas cap and does not implement EELS arbitrary-precision Uint. Large Nat source literals overflowed the compiler's parser stack; constants now use U32.to_nat, with no toolchain changes. These modules do not perform admission, signature recovery, state-dependent charging, warming, execution, settlement, or receipts. No model/main changes were made.

## Additional end-to-end flow coverage

At the lead's subsequent request, `transaction-flow-tests.bend` adds eight checks using transaction prepare, 32 pure `VM.step` transitions, and transaction finish. Cases cover legacy STOP, EIP-1559 STOP/effective fee, REVERT rolling back transferred value, INVALID forfeiting execution gas, a new value recipient's state charge spilling into execution, empty-runtime top-level creation fee/nonce, and creation collision. They assert sender nonce and balances, recipient balances, coinbase priority-fee income, charged gas, state gas and terminal action. All eight pass emitted JavaScript with the repository's existing hyphen-identifier normalization workaround. The runner does not turn fuel exhaustion into EVM OOG: unfinished execution is rejected as incomplete by finish. Native build result is recorded separately below.

Native flow limitation: `./bend-local.sh full/transaction-flow-tests.bend -o /tmp/transactionflow` was attempted. The compiler consumed approximately 12–17 GB RSS for over two minutes without emitting a binary. This owned build was stopped to reduce contention with other concurrent native builds. Therefore no native flow pass is claimed. The earlier small intrinsic harness did compile and pass native; those results must not be conflated with the much larger VM flow dependency graph. No compiler changes were made.

## JavaScript large-input stack repair

A subsequent root acceptance test exposed non-tail input traversals overflowing JavaScript's call stack for valid Amsterdam initcode sizes. Intrinsic calldata summation, access entry summation, and generic byte/key/authorization counts now recurse with accumulators. `full/bytes.bend` length uses `len_acc` for the same reason. The public APIs and numeric formulas remain unchanged; termination still decreases on the input list. `transaction-bytes-integration.patch` captures the separate bytes helper integration, preserving all other bytes behavior.

Post-change evidence: both changed modules report All terms check. Root's `transaction-acceptance-validation.bend` passes all20 JavaScript checks, including49153-byte creation beyond the old Shanghai limit, exact131072-byte acceptance, and131073-byte rejection. Root's ten intrinsic acceptance cases all pass again. An independent temporary JS harness passes eight direct traversal stress checks: byte lengths65536/131072, zero data131072 cost524288, nonzero data65536 cost1048576,20000 duplicate empty access entries execution58000000/floor surcharge25600000,20000 keys in one entry execution40002900, and20000 authorization tuples cost156320000. The oversized access/auth stress inputs intentionally exceed the transaction execution cap and test safe cost calculation before rejection; they are not claimed to be admissible transactions. No new full-VM native build was attempted for this repair.
