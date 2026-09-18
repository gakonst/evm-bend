# Transaction finish

`transaction-finish.bend` exports `Metadata`, `settlement(metadata, engine)`, and
`gas(...) -> GasSettlement{used,left,execution,state}`. Settlement is a single-use
boundary for a terminal top frame. HostLimit passes through without settlement.
The returned frame retains execution gas; use `gas` for sender-facing gas left,
which includes reservoir and capped refunds and applies the calldata floor.

The metadata snapshot must be taken after sender nonce/upfront fee debit and
authorization commit, before dispatched value transfer or creation. Its counters
`committed_used` and `committed_spilled` hold authorization charges. The incoming
engine counters EXCLUDE these committed counters: resetting them at dispatch
allows existing gas.rollback to restore the post-authorization reservoir and only
refill refundable spill. Settlement adds the committed counters back for reporting.
`entry_reservoir` documents the initial transaction grant; the post-auth baseline
is reconstructed from the engine's reservoir, signed state usage and spill.
Preparation failure requires the preparation snapshot and zero committed counters.

Pinned normative source: execution-specs commit
`a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b`, Amsterdam `vm/gas.py`
(`settle_transaction_gas`), `vm/interpreter.py` (`process_top_level`), `fork.py`
(`disburse_gas_fees`, `process_transaction`) and `state_tracker.py`
(`create_ether`, `clear_account_preserving_balance`, `modify_state`).

Gas refunds are capped at one fifth of pre-refund usage; the floor applies after
refunds. Block execution accounting ignores execution refunds. Signed negative
state usage is clamped to zero for block accounting. Refund counter handling
clamps negative internal signed values to zero. Sender and coinbase credits use
word arithmetic. As in pinned EELS, gas payments emit NO EIP-7708 transfer log:
`create_ether` modifies account balance without emitting a log. Runtime deployment
uses the existing checked create-finish module. Selfdestruct cleanup clears code,
nonce and storage while preserving a replenished balance, including gas fees.

Empty-account cleanup follows EELS `modify_state` at actual account mutation
sites through `World.modify`. Empty modified accounts become tombstones with
`exists=False`, cleared balance/nonce/code/storage, and preserved transaction
warm/storage-warm/original/transient/created metadata. This resolves the missing
touched-journal issue without model fields: account mutation itself identifies a
touch. Mere address or slot warming and storage access use raw `put` and never
prune unrelated empty accounts. Nonzero transfers, create nonce/code writes,
authorization writes, fees and destruction use modification. SELFDESTRUCT uses
`move_ether` even when value is zero, matching its distinct EELS behavior;
ordinary message entry still skips zero-value transfer. World snapshots restore
tombstones and live leaves together on rollback. Transaction preparation resets
transaction annotations. `finalize_touched` remains available for explicit callers.

Checks: `./bend-local.sh full/transaction-finish.bend` checks all terms. The tests
in `transaction-finish-tests.bend` exercise refund cap, calldata floor, negative
counters, post-auth rollback/spill, nonce persistence, fee balances and absent fee
logs, exceptional burn, rejected top-create runtime prefix, balance-preserving
selfdestruct cleanup, explicit touched-empty pruning and HostLimit passthrough.
Compile them to JS or native with bend-local.sh. The JS backend needs the existing
repository hyphenated-identifier replacement workaround. These are concrete
regression checks, not universal proofs or a complete EELS differential suite.

Reporting getters cover every `Metadata` and `GasSettlement` field. The separate
`refunds(txgas,floor,execution_left,reservoir,refund)` result exposes `txgas`,
`before_refund`, `capped_refund`, `effective_refund` (clamped to zero when the floor
exceeds pre-refund usage), and `floor_charge` (amount added above post-refund usage).
Every `RefundSettlement` field also has a getter. The four-field GasSettlement
constructor remains stable. Run `full/transaction-finish-test.sh` for 21 JS/native
concrete checks. `transaction-world-integration.patch` contains existing-module
changes relative to the parallel base checkout, without touching main.bend.

Nested CREATE integration also follows the pinned deployability rule: only
nonzero nonce or nonempty code collides; balance and storage alone do not.
Successful creation resets both current and transaction-original storage so
initcode SSTORE refunds use an empty baseline. The existing parent snapshot
restores both on failure, retaining creator nonce and destination warmth.
`transaction-create-integration-test.sh` runs seven focused JS/native tests
through Create.start and child completion, with no full VM import. Fresh outputs
are required and results persist in transaction-create-integration-tests-*.log.
