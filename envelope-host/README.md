# Signed Ethereum envelope boundary

Isolated crypto/serialization adapter for Bend's pinned Amsterdam target. No EVM,
REVM, intrinsic gas, account-state, balance, nonce-state, code or fee validation.
Nothing in this crate establishes full Amsterdam execution conformance.

## API

Build/test with `/srv/nanocodex/.cargo/bin/cargo build --locked` and `cargo test --locked`.
Library: `evm_bend_envelope::decode(raw: &[u8]) -> Result<serde_json::Value, WireError>`.
Binary: `target/debug/evm-bend-envelope`, streaming stdin/stdout JSONL, flush per line:

```json
{"mode":"decode","txbytes":"0x..."}
```

`mode` defaults to `decode`. Successful responses also contain `pendingReason`,
explicitly marking account/state/chain/gas/fee/execution validation as requiring
Bend. Expected fixture errors are never accepted as instructions to reject.
Each request yields exactly one of:

```json
{"decoded":{"type":"0x2","sender":"0x...","hash":"0x...","signingHash":"0x...","raw":"0x..."},"pendingReason":"requiresBend: account state, nonce validity, chain context, gas, fees and execution are not checked"}
{"error":{"category":"wire","exception":"TransactionException.RLP_ERROR_EOF","message":"..."}}
```

All unsigned integers are minimal hex strings (`0x0` for zero), including `type`. Bytes/addresses/hashes are lowercase, byte-preserving `0x` strings.
No JSON-number truncation. `to:""` means empty destination (EEST contract creation). Legacy unprotected
transactions have `chainId:null`; protected legacy v is preserved exactly and
chain id/parity derived using EIP-155. No expected network chain id is accepted:
Bend must compare the recovered envelope's chain id to its context.

Fields: `type`, `raw`, `hash` (Keccak of exact signed envelope), `signingHash`,
`sender`, `nonce`, `gasLimit`, `to`, `value`, `data`, `chainId`, `v`, `r`, `s`,
`yParity`; `gasPrice` for types 0/1; `maxPriorityFeePerGas` and
`maxFeePerGas` for 2/3/4; `maxFeePerBlobGas` for 3. Fee fields not present
in the wire format are omitted, not fabricated. Arrays always exist:

* `accessList`: `{address,storageKeys}` preserving order and duplicates.
* `blobVersionedHashes`: exact 32-byte hashes, no version/count validation.
* `authorizationList`: `{chainId,address,nonce,yParity,v,r,s,signingHash,authority,signer,recoveryError}`.

Authority recovery uses `keccak256(0x05 || rlp([chainId,address,nonce]))`.
`signer` aliases the independently recovered `authority`; no fixture signer annotations are read. A well-shaped authorization with a bad
signature remains decoded with `authority:null` and a typed `recoveryError`;
Bend decides its processing. Width-invalid tuples cannot be decoded and yield
canonical EEST authority-signature/format errors. Low-s is enforced for both
sender and authority recovery, never silently normalized.

`WireError.category` is `wire` or `crypto`; exceptions use the pinned EEST
TransactionException vocabulary. CLI JSON/mode/hex errors instead use category
`input`, `exception:null`; they are not Ethereum transaction exceptions.
Type-4 RLP shape failures map to the pinned corpus's
`TYPE_4_INVALID_AUTHORIZATION_FORMAT`. No semantic error is synthesized to match
fixture expectations.

## Widths and limits

Strict RLP rejects truncated/trailing input, nonminimal length encoding,
nonminimal single-byte encoding, integer leading zero, wrong node kinds, wrong
field counts, and fixed-width address/storage/hash violations. The root integration contract
explicitly requires nonce and gasLimit below 2^64; larger signed values yield
NONCE_OVERFLOW or GASLIMIT_OVERFLOW. Both remain hex words in JSON, never host
JSON numbers; Bend checks its narrower runtime limits. Nonce 2^64−1 still reaches
Bend for semantic validity checks. Transaction and authorization chainId, value,
signatures and blob fee retain full U256 width. Legacy chainId is derived from
its full U256 v without u64 narrowing. Ordinary fees retain EELS Uint precision,
including all U256 values; they are not narrowed to Alloy's u128 fee types.
Authorization nonce is U64 and parity U8. Empty type-3/4 destinations and empty
blob/authorization lists reach Bend. The full-U256 transaction chainId and all-type
U64 nonce/gas rules are the root's explicit wire integration contract; they
supersede the earlier adapter's narrower chain typedef interpretation.

Execution envelopes only: no blob sidecars or network-wrapper decoding.
Unknown EIP-2718 types fail. RLP lengths use checked usize arithmetic; nested
schema traversal is bounded/nonrecursive. CLI buffers one whole input line;
there is no application byte-size cap, timeout, or OOM recovery. Callers must
budget memory and treat process/resource failures as host failures, never EVM
OOG or transaction rejection. This is test evidence, not a formal proof.

## Validation and provenance

`python3 validate_corpus.py` reads the main corpus read-only, using
`post.Amsterdam[i].txbytes` for every state entry even if explicit sender exists.
`corpus-report.json` records every classification. Expected semantic failures
that decode are `requires_bend`, never passes. Decoded valid state cases still
require Bend execution. Fixture result sender/hash are checked where supplied.
State roots, gas and receipts are not checked.

`cargo test` exercises independently signed envelopes for all five types,
authority recovery, invalid scalars/parity/high-s, malformed RLP, width limits,
full-width chain/fee/value words, nonce/gas structural boundaries,
semantic-boundary preservation and 8192 deterministic arbitrary short inputs.
Alloy primitives is exactly pinned to 1.5.7 from evm2-reference's workspace
manifest, with k256 crypto. Cargo.lock pins the resolved dependency graph;
alloy-consensus is unnecessary because the explicit wire codec preserves Uint
fields that a narrower host transaction model could reject prematurely.

Specification/canonical exception source revision:
`ethereum/execution-specs@7341820b5b394b1934dfe7bb6f621fcdab7baf7f`, matching fixture
source URLs. Read `src/ethereum/forks/amsterdam/{transactions,fork_types}.py` and
`packages/testing/src/execution_testing/exceptions/exceptions/transaction.py`.
Corpus release is v8.1.4 as supplied by the parent. This crate does not modify,
execute or integrate into the main project. Parent should copy Cargo.toml,
Cargo.lock, src/, validate_corpus.py and this README into its chosen location.
