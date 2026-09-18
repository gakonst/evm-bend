# Amsterdam transaction API

Sources: EELS `a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b`, Amsterdam subtree; evm2 `0a5314efb28cbef7dc1a83e38ac75860b974adcd`. Local pinned Python source copies are evidence, never foreign execution semantics.

`transaction.bend` exports `prepare(tx, world, context) -> Preparation` and `finish(metadata, terminal_engine) -> Completion`. All semantic transitions are Bend. `prepare` returns `Rejected{reason: U32}` without modifying input state, or `Prepared{engine: M.Engine, metadata: F.Metadata}`. Preparation execution failures are accepted transactions: `Prepared` carries an exceptional terminal frame, sender nonce/upfront fees remain, and authorizations and dispatch preparation state are rolled back. `finish` returns `Completed{engine: M.Engine, gas: F.GasSettlement}` or `Incomplete{}` for HostLimit or nonterminal input. Never publish a receipt/world from `Incomplete`.

Execute a Prepared frame using `transaction-runtime.execute(engine)` (IO, crypto precompiles only) or the existing `Runtime.loop(fuel, Runtime.decide(M.Machine{engine, Nil{}}))`. Do **not** use `Runtime.run`: it repeats address-only initial precompile dispatch and incorrectly changes CREATE/delegated dispatch. The prepare result already selected dispatch. Finish exactly once; its engine contains terminal total state counters, including committed authorization costs, and cannot be resumed or settled again. Store rejection reasons before using the convenience `transaction-runtime.run`, which maps rejection to Incomplete.

Record field order (positional Bend constructors and host codecs must agree):

```
T.Access{address: Word, keys: +List<Word>}
T.Auth{chainid: Word, address: Word, nonce: Word, parity: U32,
       r: Word, s: Word, authority: +Maybe<Word>}
T.Tx{kind: U32, sender: Word, nonce: Word, gas: Nat,
     to: +Maybe<Word>, value: Word, data: +List<U32>,
     chainid: +Maybe<Word>, fee_cap: Word, tip: Word,
     blob_fee_cap: Word, blobhashes: +List<Word>,
     access_list: +List<T.Access>, authorizations: +List<T.Authorization>}
F.Metadata{txgas: Nat, floor: Nat, gasprice: Word, priority: Word,
           sender: Word, coinbase: Word, snapshot: M.World, create: Bool,
           target: Word, entry_reservoir: Nat, committed_used: Word,
           committed_spilled: Nat}
F.GasSettlement{used: Nat, left: Nat, execution: Nat, state: Word}
```

`T.Transaction.<field>`, `T.Access.<field>`, `T.Authorization.<field>` are getters. Sender and authorization authority are recovered by a trusted signature adapter bound to the exact signed envelope / authorization signing hash. `None` authority means invalid recovery; scalar/parity/chain/nonce/code/state checks execute in Bend. This API accepts decoded, authenticated envelopes; it does not implement RLP decoding or secp256k1 recovery itself. Missing/incorrect recovery must never be supplied as a valid sender/authority by a codec. Legacy/type1 fee_cap and tip both equal gas_price; types2..4 use max_fee and max_priority_fee. Addresses are canonical zero-extended 160-bit Words; data are bytes. Absent typed fields must be canonical as described in transaction-types.bend.

The unchanged `M.Context` has block gaslimit but no remaining block execution/state/blob capacities. The block adapter must validate those before prepare and supply chainid/basefee/blobbasefee and block context. Native Bend Nat has a declared 48-bit host bound; this is not a consensus restriction on EELS Uint. Transaction gas can exceed 2^24: only intrinsic/floor and the initial execution grant use that cap. Host guards/representation failures are not EVM OOG. Complete applicable corpus execution and unrestricted EELS Uint are outstanding conformance gates; focused tests alone do not establish 100% conformance.

Preparation resets original storage to current storage and clears transaction-local logs/refund/selfdestructs/transient/warm/created. Authorizations run sequentially before dispatch; committed state gas is saved in metadata, refundable execution counters reset, and the post-authorization world is the execution rollback snapshot. Top CREATE resets destination storage/original, marks created, increments destination nonce, and executes initcode with empty input. Finish deploys successful returned code, restores execution rollback on failures, applies capped refund/floor, credits sender/coinbase without ETH transfer logs, and clears selfdestructed code/nonce/storage while preserving remaining balance.

The isolated sourcecopy restores toolchain-debug TypeScript/foreign effects and full/precompile.js (source adapter), plus root `gas.bend`, a required transitive import of full/gas.bend. Broader legacy regression sources/adapters and their artifacts were used in sibling `evm-bend-transactions-regression-scratch`, then removed from the transaction sourcecopy. Existing main evm-bend was never edited. Evidence log: full/transaction-regression.log (452 legacy VM backend comparisons and 436 supported evm2 comparisons; explicitly listed legacy unsupported cases are not Amsterdam passes).

`F.Metadata.<field>` and `F.GasSettlement.<field>` getters are provided. Refund reporting is separately available as `F.refunds(txgas, floor, execution_left, reservoir, signed_refund_counter) -> F.RefundSettlement{txgas,before_refund,capped_refund,effective_refund,floor_charge}`, with corresponding getters. `World.modify` now implements immediate empty-account deletion through absent tombstones while preserving transaction access metadata; warmth/read/storage writes use ordinary `World.put`. Reviewable integration changes to four existing modules are in transaction-world-integration.patch. Tests distinguish modified empty accounts from merely warmed and untouched empty accounts, including rollback and zero-value SELFDESTRUCT.

Safe sum getters: `Preparation.engine/metadata/reason` return `+Maybe` of the corresponding field; `Completion.engine/world/gas` likewise return `None` for Incomplete. `Completion.world` returns `+Maybe<M.World>` directly. `Tx.refunds(metadata, completed_engine)` reports refunds from a terminal Completed engine without settling it again; this delegates to F.refunds using the saved transaction gas/floor and returned engine counters.

Byte-count/intrinsic/validation traversals use tail accumulators so valid initcode up to 131072 bytes does not overflow the JavaScript call stack. `transaction-bytes-integration.patch` records the shared `B.len` implementation change. Transaction entry's account reset also uses a tail accumulator while preserving account ordering. Native and JavaScript resource failures remain explicit host failures, never transaction OOG.
