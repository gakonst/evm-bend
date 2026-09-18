# Sequential authorization preparation

`transaction-auth.bend` implements the state-dependent EIP-7702 preparation in
[EELS Amsterdam eoa_delegation.py at a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/eoa_delegation.py).
The engine/world model is unchanged.

`process(engine, original_world, chain, authorizations, paid_writes)` returns
`AuthResult`, with explicit getters `engine`, `preparation_failed`, `snapshot`,
`paid_writes`, and `designation_set`.

* `original_world` is the world before transaction preparation, used to determine
  whether an authority originally held a designation.
* `engine` carries the preparation meter and current world, including the sender's
  already-incremented transaction nonce. Authorizations are applied sequentially.
* `paid_writes` initially contains the sender and, when transaction value is
  nonzero, its recipient. Other valid authorities pay execution 9000 once.
* `snapshot` is the world after processing. On success this is the rollback
  baseline for dispatched code, so applied authorizations survive code failure.
* On preparation failure, engine/snapshot may contain earlier applied tuples.
  The caller MUST restore its pre-preparation world and settle the failed gas
  meter. Neither partial snapshot nor paid/designation metadata may be committed.

The caller validates the canonical decoded envelope (including 160-bit addresses)
and charges authorization intrinsic cost for every tuple, even rejected tuples.
Each `T.Auth.authority` is a crypto trust boundary: `Some(address)` attests correct
recovery against Keccak(0x05 || RLP(chainid,address,nonce)); `None` denotes failed
recovery. There is no signature-recovery implementation or arbitrary foreign
transaction semantics in this module. Bend checks chain ID, nonce less than
2^64-1, parity 0/1, nonzero r below the curve order, and nonzero low-s. Recovery
inputs must be bound to the exact supplied tuple by the trusted adapter.

Only eligible recovered authorities are warmed, before checking stored code and
current nonce. Invalid state checks retain warmth without charging or applying.
Valid tuples charge missing account leaf state 183600, then first unpaid write
execution 9000, then first net-new designation state 35190. Each charge is checked
before advancing. Zero target clears code; otherwise the exact 23-byte designation
is stored. Successful application creates the leaf and increments nonce. Clearing
a designation never refunds its state charge. Original designation lookup and a
separate per-authority designation set prevent repeated indicator charges.

Run `./full/transaction-auth-test.sh`. Fifteen concrete executable checks cover
sequential set/clear/set, original designation, missing leaf, prepaid writes,
invalid-chain/nonce/parity/scalars/recovery, warm-on-state-rejection, wildcard
chain ID, all charge boundaries, state spill, partial preparation failure, and
snapshot metadata. These are concrete tests, not a universal correctness proof or
a differential suite. Transaction-level restoration and dispatch persistence
belong to the transaction entry-point tests.

Applied authorization writes use `World.modify`; warming uses `warm_account` and
does not prune untouched empty accounts. A successful clear increments nonce, so
the authority remains nonempty. The added leaf-existence regression checks that
invalid-nonce warming preserves both present-empty and absent authority leaves.

`./full/transaction-auth-flow-test.sh --native` adds five prepare/VM/finish
checks on both JavaScript and native backends. They cover applied authorization
persistence across STOP, REVERT and exceptional code, authorization state spill
remaining charged after REVERT, and preparation OOG restoring both the failing
authorization and earlier applied tuples while retaining sender nonce and fees.

Validation record: all 15 unit checks and all five end-to-end checks passed on
JavaScript. The end-to-end native build was stopped during Bend C emission after
about four minutes when its resident memory reached approximately 20 GB, without
a binary or diagnostic. Native results are unverified; this compiler resource
limit is not represented as EVM out-of-gas. The optional native command above
remains available for reproduction with a suitably bounded compiler workflow.
