# EVM in Bend — Amsterdam

An EVM transaction and frame interpreter written in Bend 2.0.5, targeting the pinned Amsterdam execution fork of Glamsterdam. Opcode execution, 256-bit arithmetic, Keccak, memory, account/storage journals, nested calls, creation and gas accounting are Bend. Standard cryptographic precompiles use an explicit Rust host adapter backed by evm2. Python only serializes JSON/binary inputs and normalizes output.

This is a correctness-first experimental implementation, **not an end-to-end proved EVM or a production client**. The earlier Shanghai subset and its laws remain regression material; `full/main.bend` is the current interpreter.

## Current status

**Goal: 100% of applicable Amsterdam EVM conformance tests passing in Bend. This goal has not been reached.**

The pinned official corpus contains 40,911 required state, blockchain and transaction cases. The current integration gate targets all **15,918 state fixtures on native and JavaScript**, without skipped cases or host errors counted as passes. Full native and JavaScript results are tracked in [conformance/STATE-PROGRESS.md](conformance/STATE-PROGRESS.md); the repaired source passed all 15,918 native cases and its fresh full JavaScript gate is running. Blockchain and standalone transaction execution remain unfinished. Engine/sync API fixtures are separately inventoried.

`full/transaction-main.bend` performs transaction preparation and settlement in Bend. Signed envelopes are decoded and cryptographically verified by the strict Rust wire/crypto helper; transaction semantics remain in Bend. Total gas is a 256-bit Word, including accepted values beyond the runtime Nat range. Expected rejections use the pinned EEST exception-matching contract. Supplementary decoded-envelope and prepared-frame regressions are rerun against the integrated source; they do not replace the official state gate.

See [GOAL.md](GOAL.md), [VALIDATION.md](VALIDATION.md) and [conformance/README.md](conformance/README.md) for scope and limitations.

## Build and try

Requires Python 3, Bun, Rust/Cargo and Clang. Clone the pinned evm2 dependency beside this repository:

```sh
git clone https://github.com/gakonst/evm-bend.git
git clone https://github.com/alloy-rs/evm2.git evm2-reference
git -C evm2-reference checkout 0a5314efb28cbef7dc1a83e38ac75860b974adcd
cd evm-bend
cargo build --locked --manifest-path precompile-host/Cargo.toml
python3 evm.py --build examples/return-42.json
python3 evm.py --backend js --build examples/return-42.json
```

## Run on Omarchy

```sh
cd /srv/nanocodex/workspace/evm-bend
python3 evm.py examples/return-42.json
python3 evm.py examples/storage.json
python3 evm.py --backend js examples/return-42.json
```

`return-42.json` returns a 32-byte word ending in `2a`, with 999982 execution gas remaining. Output includes status, exceptional reason, stack, output bytes, memory, execution gas, state reservoir/spill/usage, refund counter, logs and account state.

Build after source changes:

```sh
PATH=/srv/nanocodex/.cargo/bin:$PATH cargo build --locked --manifest-path precompile-host/Cargo.toml
python3 evm.py --build
python3 evm.py --backend js --build
```

The precompile adapter requires the adjacent pinned `../evm2-reference` checkout. The local Bend copy requires Bun, and native builds require Clang. `BEND` and `BUN` can override the default tools. `evm.py` does not automatically rebuild an existing executable after edits: run the build commands explicitly.

## Execution contract

The JSON entry point executes a **prepared frame**, starting at PC 0 with an empty stack. It is not an Ethereum transaction decoder, signature verifier, block executor or trie database. The caller supplies bytecode/calldata, block context, account balances/nonces/code/storage, original storage, warmth, transient storage and the state-gas reservoir. Gas supplied is execution gas available at frame entry, after transaction intrinsic charges. Top-level value transfer, authorization processing and transaction fee settlement are caller responsibilities. Child calls and creations perform their own transfers, delegation and journaling in Bend.

All assigned opcode families are implemented, including CLZ, SLOTNUM, DUPN/SWAPN/EXCHANGE, PUSH0, MCOPY, transient storage and blob environment operations. All 18 active precompile addresses (1–17 and 0x100) dispatch through the crypto helper. Creation implements CREATE/CREATE2 address derivation, initcode execution and deployment charges. Amsterdam state gas, repricing and transfer logs are included.

`accounts` is a mapping from 160-bit address to `{balance, nonce, code, storage, original_storage, transient, warm, exists, created, warm_slots}`. Numeric words accept integers or hexadecimal strings. `context` contains origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes and blockhashes. Omitted fields have explicit synthetic-test defaults; a chain integration must populate the real environment.

Successful execution returns the frame's journal. Transaction-final account deletion is represented by `selfdestructs`; `full/call-selfdestruct.bend` contains the finalizer for integration. Transient state/warmth clearing, refund caps, calldata floor gas and fees belong to transaction settlement. REVERT and exceptional exits restore the supplied initial world; REVERT preserves remaining execution gas and output, while exceptions burn execution gas. Host errors are distinct from EVM OOG.

Host limits: JSON binary input below 16 MiB; gas and reservoir each at most 2^24; runtime Nat representation 48 bits. These are explicit runner constraints. The interpreter has a fuel guard and the CLI has a timeout; neither is a protocol exception. Do not treat host limits as proof that an EVM execution should fail.

## Validation

- 616 prepared-frame cases plus 8 delegation/storage-context/CREATE2 cases match revm 43.0.0 Amsterdam on **both** native and JavaScript backends. Checks cover status, returned output, execution gas spent before transaction refund/floor settlement, state gas, logs and reference-reported storage writes.
- Every opcode byte is exercised on an empty stack, with additional positive arithmetic, memory, stack, environment, storage, nested-call and creation cases. This is not exhaustive execution-state coverage.
- 74 precompile comparisons across both backends include all 18 addresses and valid/malformed input examples. They are not exhaustive cryptographic test suites.
- 56 state-reservoir/spill/rollback metamorphic checks pass.
- 22 additional real contract/crypto fixture runs match revm on both backends: ERC-20 approval/balance/revert, counter, Uniswap V2 reserves, Fibonacci, and valid ECRECOVER/KZG/P256/curve examples. `examples/erc20-approve.json` is runnable.
- Pure Keccak passes 15 vectors on both backends, including rate boundaries.
- Existing Shanghai subset regressions pass 452 Python-oracle comparisons and 436 evm2 comparisons; five semantic mutants are rejected by the existing law gate.
- The full arithmetic test passes 6,733 deterministic cases on each backend (13,466 comparisons). Native execution resumed after a reconnect; `word-ops-results.json` records both verified ranges and their logs.

```sh
PATH=/srv/nanocodex/.cargo/bin:$PATH cargo build --locked --manifest-path revm-adapter/Cargo.toml
EVM_BACKEND=native python3 test_full_differential.py
EVM_BACKEND=js python3 test_full_differential.py
python3 test_precompiles.py
python3 test_frame_invariants.py
python3 test_contract_fixtures.py
python3 test_word_ops.py
./check.sh
```

The revm adapter is a transaction oracle. The harness subtracts Amsterdam intrinsic gas and aligns frame-entry gas; it compares pre-refund total spending, not the receipt's floor-adjusted gas. Both evm2 and revm are independent from Bend execution, but the precompile host itself uses evm2 crypto. Pins and normative rules are in `AMSTERDAM-SPEC.md`.

## Proof and trust boundary

Existing Bend laws prove limited stack/capacity, checked-gas and word specification properties. **Full limb refinement, opcode refinement, journal rollback, call/create correspondence, all Amsterdam gas rules and compiler correctness are not proved.** Passing differential tests does not close those obligations. No theorem statements were weakened to make the implementation pass.

The trusted boundary includes the Bend checker/compiler/runtime, project-local compiler layout workaround, C/JS effect shims, Rust crypto libraries and their setup data, and JSON input preparation. The supplied interpreter uses no foreign opcode execution.

## Compiler workaround and optimization baseline

The installed Bend compiler is unchanged. `bend-local.sh` uses `toolchain-debug/`, a copied 2.0.5 compiler. `toolchain-layout.patch` makes native layouts larger than 32 machine fields boxed, avoiding the compiler's 255-argument limit for 256-bit words and large frame records, and adds a diagnostic for oversized functions. A separate diagnostic change prints stack traces. No type-checking or proof rules are relaxed. The JS wrapper also repairs hyphens in generated module identifiers; the `evmword.bend` name avoids the C symbol collision between local `word.add` and Base `Word.add`.

The current memory and world structures favor clarity over speed. `benchmark.py` measures the entire invocation, including Python serialization, process startup and output parsing; it is not an isolated opcode throughput measurement. The initial 1,000-iteration arithmetic/control loop measured about 0.101 s native and 1.122 s JS on this Omarchy host. These are local, noisy baselines, not throughput claims against revm.

Next performance work should separate interpreter time from process/serialization overhead, then profile word arithmetic, jump decoding, memory and account lookup. Preserve differential tests and state-gas invariants while replacing representations. GPU acceleration is not assumed to improve a sequential single-frame interpreter.
