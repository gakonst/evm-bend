# Exact wide transaction gas API (isolated extension)

`transaction-wide.bend` preserves all v1 `T.Tx`, `M.Engine`, and `Tx` record/API layouts.

```text
Wide.WideTx{transaction: T.Transaction, gas: Word}
Wide.prepare(WideTx, world, context) -> Wide.Preparation
  Rejected{reason: U32}
  Prepared{engine: M.Engine, metadata: F.Metadata, gas: Word, escrow: Word}
Wide.prepared(Preparation) -> IO(Wide.Completion)
Wide.run(WideTx, world, context) -> IO(Wide.Completion)
Wide.finish(metadata, totalGas, escrow, terminalEngine) -> Wide.Completion
  Incomplete{}
  Completed{engine: M.Engine, gas: Wide.Settlement, reservoir: Word}
Wide.Gas{used: Word, left: Word, execution: Word, state: Word}
Wide.Completion.reservoir(Completion) -> +Maybe<Word>
```

The outer gas Word is authoritative; nested `T.Tx.gas` is ignored. Exact gas is checked against the full block limit and used in maximum fee overflow and affordability checks before mutation. The v1 validator's other conditions and order are preserved. Sender and authorization recovery remain the existing trusted crypto boundary. Whole-block consumed capacities remain the caller's responsibility.

The v1 proxy gas is `min(totalGas, 2^44)`. No high gas bits are converted to Nat: the only narrowing follows this minimum. Escrow is `totalGas - proxyGas`, held as Word throughout. Preparation debits `escrow * effectivePrice` from both the prepared world and the metadata rollback snapshot after the proxy preparation; full affordability was already validated. This occurs before any VM opcode observes balances. Settlement calls deposit and rollback directly, never the proxy's fee payment. Before-refund usage is exactly `totalGas - executionLeft - engineReservoir - escrow`. Refund cap, floor, sender unused-fee refund, and coinbase payment all use Word arithmetic. Completion explicitly reports `engineReservoir + escrow`; the underlying engine reservoir alone is only the active window.

## Conservative window bound

This is an implementation argument tied to the pinned cost schedule, not a machine-checked theorem. The existing grant is at most `2^24 - intrinsic.execution`. CALL/CALLCODE stipend is 2300 (call-enter.bend:55) and paid value-call surcharge is 11300 (call-enter.bend:87), which exceeds it; even allowing returned stipends, total raw charged execution is conservatively below `2 * 2^24`. State gas that spills to execution cannot replenish net execution: settlement/refill only restores previously spilled execution. For positive escrow the window is never close to spilling under the bound below.

Every positive state-charge path has state/execution ratio below 10000:

* Code deposit costs 1530 per byte and charges 6 execution per 32-byte word, hence maximum ratio `1530*32/6 = 8160` (create-finish.bend:22,29). Code length is capped at 65536 before deposit.
* SSTORE state creation is 97920 and requires the storage-write execution charge (state-ops.bend:119-126); CALL/CREATE/SELFDESTRUCT account creation is 183600, with their opcode/entry execution charges (call-common.bend:74-81 and respective entry modules).
* Authorization state charge is at most 183600+35190 per entry (transaction-auth.bend:71-90), backed by 7816 intrinsic execution per authorization (transaction-intrinsic.bend:98-103). Top-level account creation is backed by the recipient intrinsic charge (transaction-intrinsic.bend:32-37).

Thus aggregate positive state charging, including rolled-back work, is bounded by `2 * 2^24 * 10000 = 335544320000`. Refills undo paid state charges and cannot grow the window by more than this conservative total; authorization committed counters and nested rollback remain within Nat48. This is far below both the `2^44` window and `2^40` guard margin. Initial window reservoir is proxyGas minus the at-most-2^24 total execution allocation. Therefore no valid transaction with positive escrow can exhaust the window; escrow need not be refilled or redistributed at calls. Since the existing VM sees an effectively inexhaustible reservoir, it charges exactly the same state cost and exposes exactly the same GAS as the full reservoir would. Parent frames carry state deltas, not reservoir snapshots; rollback returns deltas to the shared window and leaves escrow invariant.

Every VM transition and precompile callback is followed by a check that, for positive escrow, the active reservoir remains in `[2^44 - 2^40, 2^44 + 2^40]`. Leaving this conservative range changes the action to HostLimit and yields Incomplete, never an accepted result or consensus OOG. This makes violations of the cost-bound argument explicit. The check also runs before the first VM transition. Host execution fuel remains finite and host exhaustion remains Incomplete.

Only `prepare`-produced metadata/engine/escrow should be passed to the execution/settlement APIs. Arbitrarily constructed inconsistent engine state is outside the contract. Word represents up to 256-bit gas; this is not unrestricted mathematical Uint.

## Evidence

`transaction-wide-execution-test.py` generates Bend only from selected fixture inputs, not post state/receipt/expected exceptions. Expected allocation and receipt fields are used solely by the separate post-execution comparison. Tests target both pinned accepted >=2^48 fixtures from the report. Build logs, backend observations and comparison results use the `transaction-wide-execution-*` prefix. The exhaustive 7012-record audit is in `transaction-wide-gas-fixtures.jsonl`; concise inventory counts are in `transaction-wide-gas-findings.md`.

Verified fixture results on both JavaScript and native (crypto host configured):

| Fixture | Full allocation | Receipt gas | Status/logs |
|---|---|---:|---|
| callcode_lose_gas_oog --g2 | pass | 343611 | pass |
| ecrecover_short_buff | pass | 8177924 | pass |

The earlier execution without a configured crypto-host path correctly returned Incomplete for ecrecover; the harness now explicitly sets the existing crypto-only helper path. Results are in transaction-wide-execution-results.json. No roots or signature-recovery conformance claim is made.

Seven focused JavaScript assertions also pass (`transaction-wide-tests.log`): authoritative outer Word gas despite nested zero Nat, exact block-limit rejection, wide multiplication overflow, intrinsic rejection, wide affordability, invalid-window HostLimit, and Word unused-gas/full-reservoir conservation. These tests use input-only fixture definitions in transaction-wide-test-inputs.bend; no expected fixture state is passed into execution.

Transaction/Settlement and RefundSettlement expose field getters. Completion engine/gas/reservoir getters return Maybe. Wide.refunds(totalGas,escrow,floor,completedEngine) returns Refund{txgas,before_refund,capped_refund,effective_refund,floor_charge}, all Word. Supply the completed engine after deployment and rollback. The Word refund report has a passing JS assertion.
