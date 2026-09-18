# Amsterdam execution specification manifest

Target: the **pinned Amsterdam implementation snapshot**, not a claim that this fork has activated on mainnet. Amsterdam is the execution target requested for Glamsterdam. Preserve the existing Shanghai subset and its laws as a separate regression target.

Normative implementation source for this manifest is EELS commit `a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b`, subtree `src/ethereum/forks/amsterdam`. Cross-check reference: evm2 commit `0a5314efb28cbef7dc1a83e38ac75860b974adcd`. Source bodies, rather than inherited constant names or comments alone, determine which charge is actually applied. This document records specification requirements, not completed implementation or proof.

## Pinned source index

All EELS links below use [this immutable Amsterdam root](https://github.com/ethereum/execution-specs/tree/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam).

- [Opcode enumeration/dispatch](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/instructions/__init__.py)
- [Numeric gas constants, reservoir operations, allocation and settlement](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/gas.py)
- [Frame dispatch, exceptional/revert settlement, deployment](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/interpreter.py)
- [Storage instructions](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/instructions/storage.py)
- [CALL/CREATE/SELFDESTRUCT instructions](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/instructions/system.py)
- [Stack immediate decoding](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/stack.py), [stack instructions](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/instructions/stack.py), [jump map](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/runtime.py)
- [Environment instructions](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/instructions/environment.py), [block instructions including SLOTNUM](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/instructions/block.py)
- [Frame data, child incorporation, ETH transfer logs](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/__init__.py), [delegation processing](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/eoa_delegation.py)
- [Transaction validation/intrinsic gas](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/transactions.py), [transaction/block integration](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/fork.py), [state tracker](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/state_tracker.py)
- [All precompile dispatch](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/precompiled_contracts/mapping.py)
- [evm2 cumulative fork tables](https://github.com/alloy-rs/evm2/blob/0a5314efb28cbef7dc1a83e38ac75860b974adcd/crates/evm2/src/version/mod.rs), [feature definitions](https://github.com/alloy-rs/evm2/blob/0a5314efb28cbef7dc1a83e38ac75860b974adcd/crates/evm2/src/version/features.rs), [limits](https://github.com/alloy-rs/evm2/blob/0a5314efb28cbef7dc1a83e38ac75860b974adcd/crates/evm2/src/constants.rs)

## Execution conventions and complete opcode coverage

Stack notation below lists pop counts and push counts; the first popped operand is the top. Words wrap modulo 2^256; addresses use the low 160 bits. Stack maximum is 1024. Gas, offsets, lengths and intermediate bounds calculations do **not** wrap at 256 bits. Signed operations interpret two's complement. DIV/MOD/SDIV/SMOD with zero divisor return zero; SDIV truncates toward zero and its minimum/-1 case returns the minimum representation. ADDMOD/MULMOD use untruncated intermediate arithmetic and return zero for modulus zero. Shifts >=256 return zero except SAR returns all sign bits. CLZ(0)=256. BYTE numbers bytes from the most significant end; SIGNEXTEND indexes from the least significant byte. Comparisons push 0 or 1.

`w(n)=ceil(n/32)`. `M` is the incremental memory gas for all ranges touched by the instruction. Memory is zero initialized; `Cmem(a)=3a+floor(a*a/512)` for a words, and `M=Cmem(new)-Cmem(old)`. A zero-length range does not expand memory regardless of offset. Charge before host allocation. `A` is account access: warm 100, cold 3000; `S` is storage access: warm 100, cold 2100. `n` in dynamic gas means byte length, except in LOGn/DUPn/SWAPn names.

The following table covers every assigned opcode/range in this snapshot. All byte values not listed are **exceptional invalid opcode**, including 0xfe (INVALID); there is no runtime NotImplemented path in the complete interpreter.

| Byte(s) | Opcode(s) | Stack pop→push | Execution gas / operation |
|---|---|---|---|
| 00 | STOP | 0→0 | 0; successful empty-output halt |
| 01 | ADD | 2→1 | 3 |
| 02 | MUL | 2→1 | 5 |
| 03 | SUB | 2→1 | 3; top minus next |
| 04–07 | DIV, SDIV, MOD, SMOD | 2→1 | 5 each |
| 08–09 | ADDMOD, MULMOD | 3→1 | 8 each |
| 0a | EXP | 2→1 | 10+50*byte_length(exponent); base is top |
| 0b | SIGNEXTEND | 2→1 | 5 |
| 10–14 | LT, GT, SLT, SGT, EQ | 2→1 | 3 each |
| 15 | ISZERO | 1→1 | 3 |
| 16–18 | AND, OR, XOR | 2→1 | 3 each |
| 19 | NOT | 1→1 | 3 |
| 1a–1d | BYTE, SHL, SHR, SAR | 2→1 | 3 each |
| 1e | CLZ | 1→1 | 5 |
| 20 | KECCAK256 | 2→1 | 30+6*w(n)+M; Ethereum Keccak, not SHA3-256 |
| 30 | ADDRESS | 0→1 | 2 |
| 31 | BALANCE | 1→1 | A |
| 32–34 | ORIGIN, CALLER, CALLVALUE | 0→1 | 2 each |
| 35 | CALLDATALOAD | 1→1 | 3; zero-pad 32-byte big-endian read |
| 36 | CALLDATASIZE | 0→1 | 2 |
| 37 | CALLDATACOPY | 3→0 | 3+3*w(n)+M; zero-pad source |
| 38 | CODESIZE | 0→1 | 2; original executing code length |
| 39 | CODECOPY | 3→0 | 3+3*w(n)+M; zero-pad source |
| 3a | GASPRICE | 0→1 | 2; effective transaction gas price |
| 3b | EXTCODESIZE | 1→1 | A+100 = 200 warm / 3100 cold |
| 3c | EXTCODECOPY | 4→0 | A+100+3*w(n)+M |
| 3d | RETURNDATASIZE | 0→1 | 2 |
| 3e | RETURNDATACOPY | 3→0 | 3+3*w(n)+M; source offset+size must be <= return-data length, even for size zero |
| 3f | EXTCODEHASH | 1→1 | A; zero for EMPTY_ACCOUNT, otherwise stored code hash |
| 40 | BLOCKHASH | 1→1 | 20; previous 256 blocks only, zero otherwise |
| 41–46 | COINBASE, TIMESTAMP, NUMBER, PREVRANDAO, GASLIMIT, CHAINID | 0→1 | 2 each |
| 47 | SELFBALANCE | 0→1 | 5 |
| 48 | BASEFEE | 0→1 | 2 |
| 49 | BLOBHASH | 1→1 | 3; out-of-range index returns zero |
| 4a | BLOBBASEFEE | 0→1 | 2 |
| 4b | SLOTNUM | 0→1 | 2; block_env.slot_number, a supplied U64 slot number |
| 50 | POP | 1→0 | 2 |
| 51 | MLOAD | 1→1 | 3+M; 32-byte big-endian |
| 52 | MSTORE | 2→0 | 3+M; 32-byte big-endian |
| 53 | MSTORE8 | 2→0 | 3+M; low byte |
| 54 | SLOAD | 1→1 | S |
| 55 | SSTORE | 2→0 | S + conditional 10000 write; state gas/refunds below |
| 56 | JUMP | 1→0 | 8; validated destination |
| 57 | JUMPI | 2→0 | 10; validate target only if condition nonzero |
| 58 | PC | 0→1 | 2; opcode position |
| 59 | MSIZE | 0→1 | 2; allocated memory bytes |
| 5a | GAS | 0→1 | 2; execution gas remaining **after** its charge; excludes state reservoir |
| 5b | JUMPDEST | 0→0 | 1 |
| 5c | TLOAD | 1→1 | 100 |
| 5d | TSTORE | 2→0 | 100; static-context forbidden; no SSTORE stipend guard |
| 5e | MCOPY | 3→0 | 3+3*w(n)+M; expand source and destination; memmove overlap semantics |
| 5f | PUSH0 | 0→1 | 2 |
| 60–7f | PUSH1–PUSH32 | 0→1 | 3; right-zero-pad truncated big-endian immediate; PC += width+1 |
| 80–8f | DUP1–DUP16 | 0→1 | 3; require n inputs and output room, duplicate nth-from-top |
| 90–9f | SWAP1–SWAP16 | 0→0 | 3; require n+1 inputs; swap top and position n+1 |
| a0–a4 | LOG0–LOG4 | (2+n)→0 | 375+375*n+8*data_bytes+M; static-context forbidden |
| e6 | DUPN | 0→1 | 3; one immediate; detailed decoding below |
| e7 | SWAPN | 0→0 | 3; one immediate; detailed decoding below |
| e8 | EXCHANGE | 0→0 | 3; one immediate; detailed decoding below |
| f0 | CREATE | 3→1 | 12000+2*w(initcode_bytes)+M; child gas/state charges below |
| f1 | CALL | 7→1 | A+value/delegation/M+withheld child gas; below |
| f2 | CALLCODE | 7→1 | same execution schedule as CALL; no new-recipient state charge |
| f3 | RETURN | 2→0 | M; successful halt with memory slice |
| f4 | DELEGATECALL | 6→1 | A+delegation+M+withheld child gas; no value surcharge |
| f5 | CREATE2 | 4→1 | 12000+8*w(initcode_bytes)+M; includes 2 initcode + 6 hash per word |
| fa | STATICCALL | 6→1 | A+delegation+M+withheld child gas; no value surcharge |
| fd | REVERT | 2→0 | M; revert with output and unspent execution gas |
| fe | INVALID | — | exceptional halt, no surviving execution gas |
| ff | SELFDESTRUCT | 1→0 | 5000 + (cold beneficiary?3000:0) + conditional 9000; state charge below |

## Immediate decoding and control flow

DUPN/SWAPN accept immediate x in [0,90] or [128,255], otherwise exceptional invalid parameter; n=(x+145) mod 256. DUPN copies stack position n; SWAPN swaps positions 1 and n+1 (positions start at 1 at the top). EXCHANGE accepts x in [0,81] or [128,255]; let k=x XOR 143, q=k div 16, r=k mod 16. If q<r use (n,m)=(q+1,r+1), otherwise (r+1,29-q); exchange positions n+1 and m+1. Missing immediate reads as zero. These instructions advance PC by 2. Jumpdest analysis skips their one immediate byte, and every PUSH immediate; only actual 0x5b instructions are destinations. Falling off code succeeds like STOP. Invalid immediate, bad taken jump, stack underflow/overflow, static violation, invalid opcode and OOG are exceptional halts.

## Two gas dimensions (EIP-8037), exact frame settlement

Source: pinned `vm/gas.py`, `vm/__init__.py`, and `vm/interpreter.py` above. CPSB=1530; new account=120 bytes=183600 state gas; zero storage set=64 bytes=97920; new authorization indicator=23 bytes=35190; deployed code=1530 per byte. These are state charges, not execution surcharges.

**2^24=16777216 caps execution gas, not accepted transaction gas.** With intrinsic execution cost I and transaction gas T, E=T-I, execution grant=min(16777216-I,E), initial reservoir=E-execution grant. Validation requires I and calldata floor each <=16777216 and <=T. T may exceed 16777216; block admission additionally compares T to remaining state capacity and min(T,16777216) to remaining execution capacity. Do not impose a 24-bit transaction-gas or reservoir bound. EELS uses arbitrary nonnegative Uint for both gas types. A Nat48 representation is ample for ordinarily capped frame execution grants (including 2300 stipends), but a Nat48 reservoir needs an independently declared and validated host bound; the execution cap does not prove it. Cross-frame state refunds can also increase returned execution gas above its original grant, so conversions must remain checked.

A frame meter contains execution gas G, reservoir R, reservoir baseline B, signed execution refund F, refundable spill P, and committed spill C. Initially B=R, F=P=C=0. A state charge s draws min(R,s) from R, then the remainder from G and adds it to P; if R+G<s, OOG without partial debit. Execution charges draw G only. A state refund s first restores min(s,P) to G and subtracts it from P, then credits the remainder to R. State refunds are immediate pool credits, not F and not subject to the one-fifth execution-refund cap.

A child receives the entire remaining R (parent R becomes zero), with no 63/64 rule for state gas. On child success merge its G,R,P,F, logs, deletion set, and warm sets into parent, then repay min(R,P) from R into G, reducing P. This repayment is essential when a child refunds state charged by its parent. On failure the child first restores its refundable P into G, clears P and F, and sets R=B. REVERT preserves this resulting G and output; exceptional halt then burns all G and clears output. Parent absorbs returned gas even on failure, but not failed-child logs, warm additions, deletions, storage, transient storage, or other state changes. Parent opcode target warming survives that child failure.

Top-frame authorization commit sets C+=P, P=0, B=R. Dispatched-code rollback preserves that committed state and charges. Preparation failure before dispatch rolls back authorizations too, restores R to its entry grant and credits both P and C before exceptional execution-gas forfeiture. Net state usage = entry reservoir - returned R + P + C; it can be negative. Transaction pre-refund usage U=T-G-R; refund=min(U div 5,max(F,0)); sender usage=max(U-refund,calldata floor). Block state usage=max(net state usage,0), block execution usage=max(U-block state usage,calldata floor), before execution refunds (EIP-7778).

## Storage and journaling

Source: pinned `vm/instructions/storage.py`. Let o be transaction-original slot, c current slot, n new slot. SSTORE requires G>=max(access cost,2301), forbids static execution, and always charges warm100/cold2100 (not 2200). Add execution10000 exactly when o=c and c!=n. If c!=n: add refund11616 when o!=0,c!=0,n=0; subtract11616 when o!=0,c=0; add10000 when o=n. The clear refund is floor((10000+2100)*4800/5000)=11616, not4800. Charge state97920 when o=c=0 and n!=0; immediately refund state97920 when c!=n and o=n=0. Charge execution before state. Warm slots are keyed by (storage-context address,256-bit key). Recreated account storage is reset and treated as originally empty for refunds.

Persistent state, transient storage, account creation/deletion, nonces, balances and code need nested rollback. Original storage is transaction scoped. Transient storage starts empty each transaction, shares CALLCODE/DELEGATECALL storage context and rolls back with frames. Warm address/slot sets begin with sender, recipient, coinbase, all active precompiles, access-list entries, and recovered authorization authorities; child additions merge only on success. Account existence, empty account, alive account and deployability are distinct: alive means present and nonempty; deployable means nonce=0 and empty code hash (balance/storage alone do not prohibit creation).

## CALL family and EIP-7702 code resolution

Source: pinned `system.py`, `eoa_delegation.py`, `interpreter.py`. Pop arguments in table order: gas,target,[value],input offset,input length,output offset,output length. Expand the union of input/output memory ranges. Charge account access100/3000, plus11300 for nonzero CALL/CALLCODE value, plus delegation access if any. CALL with nonzero value is forbidden in static context; CALLCODE may retain nonzero value in static context because it transfers to itself. All children inherit static status; STATICCALL additionally sets it.

A delegation designation is exactly23 bytes `ef0100 || address20`. Resolve exactly one hop; charge additional warm100/cold3000 for delegated address and warm it. Execution uses delegated code while address, storage and balance context remain those of the original call operation. Disable precompile dispatch when reached through delegation: delegating to a precompile behaves as empty code. A second designation is ordinary bytecode (its 0xef is invalid), not recursive resolution. EXTCODE* inspect stored designation bytes/hash, not resolved code.

CALL charges state183600 when value!=0 and recipient is not alive. This state charge, including any spill, occurs before calculating child gas. Let remaining execution after all opcode charges be g; withhold h=min(requested gas,g-floor(g/64)). Child receives h plus2300 for value-bearing CALL/CALLCODE; parent withholds only h. Drain all reservoir. CALLCODE has no recipient-creation charge. Failure of depth+1>1024 or insufficient CALL/CALLCODE balance returns child gas including stipend and reservoir untouched, refunds any recipient state charge, pushes0 and leaves empty returndata. It still pays opcode costs. Top depth=0.

| Operation | Child address/storage | Child caller | Child value | Value movement |
|---|---|---|---|---|
| CALL | target | current address | argument | caller to target |
| CALLCODE | current address | current address | argument | self, balance checked |
| DELEGATECALL | current address | inherited caller | inherited value | none |
| STATICCALL | target | current address | zero | none |

Child success pushes1; REVERT/exception pushes0. Full child output becomes returndata, including REVERT output; copy only min(output capacity,returned length) into output memory, preserving the rest. Exceptional child output is empty. New recipient state charge refills if child fails. Parent resumes at next instruction; failed CALL is not itself exceptional unless opcode charges/checks failed.

Authorization tuple verification: chain id must equal current chain or0; nonce<2^64-1; parity0/1, 0<r<secp256k1 order, 0<s<=order/2; recover from Keccak(0x05 || RLP(chain id,address,nonce)). Invalid tuples are skipped. Recovered authority is warmed before code/nonce validation, even if those checks fail. Authority code must be empty or valid delegation and nonce must match. Process tuples sequentially; zero target clears code, otherwise store designation; increment authority nonce. Charge state183600 if authority leaf absent; execution9000 on its first unpaid account write (sender already paid, value-bearing transaction recipient already paid); state35190 for first net-new designation when none existed before transaction, at most once per authority, with no refund for later clearing. Applied authorizations survive dispatched-code failure, but preparation OOG rolls them all back.

## CREATE, CREATE2, SELFDESTRUCT and ETH transfer logs

CREATE address is low20 Keccak(RLP([creator,creator pre-increment nonce])); nonce0 uses RLP empty integer. CREATE2 address is low20 Keccak(0xff || creator20 || salt32 || Keccak(initcode)). Static create is exceptional. Opcode execution charge=12000+memory+2*ceil(init bytes/32); CREATE2 adds6*ceil(init bytes/32). Initcode length>131072 exceptionally OOG. Clear returndata. Insufficient balance, creator nonce==2^64-1, or depth+1>1024 pushes0 before destination warming/state charge/nonce increment/child gas withholding.

Warm destination; if not alive charge state183600. Withhold all-but-one-64th execution gas after that state charge. Collision means destination nonce!=0 or nonempty code hash: increment creator nonce, consume withheld gas, push0; no child or reservoir drain. Otherwise drain entire reservoir, increment creator nonce, reset destination storage, mark created-this-transaction, initialize destination nonce to1, transfer endowment and execute initcode with empty calldata. Existing destination balance is retained. Child failure restores destination state, but creator nonce persists unless its enclosing frame reverts; refund parent's new-account state charge. REVERT output becomes CREATE returndata; success clears returndata and pushes address.

Successful initcode output must have <=65536 bytes and must not start0xef. Runtime deployment charges execution6*ceil(bytes/32) for hashing and state1530*bytes, **not the inherited 200 execution-gas-per-byte constant**. Failed deposit/prefix/size check reverts created state, refills child state gas, burns child execution gas, clears output and returns0.

SELFDESTRUCT is static-forbidden. Charge execution5000 plus3000 if beneficiary cold (no100 warm surcharge); if origin balance!=0 and beneficiary not alive additionally charge execution9000 and state183600. Charge execution first. Transfer full balance; self-transfer leaves balance unchanged until possible final deletion. Schedule actual account/code/storage deletion only when origin was created during this transaction (EIP-6780). Halt successfully. No selfdestruct execution refund; no immediate general state-gas refund for destruction.

EIP-7708: every nonzero transfer between distinct addresses performed by CALL/top-level call, creation endowment, or SELFDESTRUCT emits a log from `0xfffffffffffffffffffffffffffffffffffffffe`; topics=[Keccak("Transfer(address,address,uint256)"),sender left-padded32,recipient left-padded32], data=amount32 big-endian. Emit before child code, no extra LOG opcode gas. CALLCODE/self transfers, zero transfers and DELEGATECALL do not emit. Logs roll back with the transfer/frame. Host gas payments and consensus balance changes are outside this opcode execution requirement.

## Transaction boundary and environment contract

A complete EVM entry point must either implement these transaction preparations or accept a clearly validated prepared environment. It must not silently substitute zero for unsupported environment values. Supply chain id, origin, effective gas price, coinbase, timestamp, block number, prevRandao, block gas limit, base fee, blob base fee/versioned hashes, previous256 block hashes, and U64 slot number. BLOCKHASH returns zero for current/future or older-than256 numbers; BLOBHASH indexes transaction hashes or zero. EIP-2935 history contract maintenance and block consensus processing are host responsibilities, not new opcode behavior.

Intrinsic base=12000; non-self call recipient adds3000 and, for nonzero value,6000; creation adds12000 plus2*ceil(initcode bytes/32). Standard calldata costs4 per zero byte/16 per nonzero byte. Access-list address costs2900 plus1280 data surcharge; each key2000 plus2048 surcharge; charge duplicate list entries too, though warming is set-valued. Authorization intrinsic=7816 per tuple (101*16+3000+3000+200), including invalid tuples. Calldata floor=intrinsic base including recipient component +64*calldata byte count +access-list data surcharge. Floor excludes authorization and initcode-word charges. Nonce must equal sender nonce and be<2^64-1; sender code must be empty or a valid delegation designation. Validate transaction type-specific signatures/fees/blob constraints at host boundary; opcode caller is not a consensus block validator.

## Precompile address map, gas and validation

Addresses are zero-extended20-byte addresses. Dispatch only the following18 addresses, all initially warm; no blanket reserved-range precompile behavior. Precompile gas is execution gas. Invalid input generally exceptionally fails and burns child execution gas; ECRECOVER/P256 invalid-signature results instead succeed with empty output as specified below. Cryptographic outputs must be actual calculations, not placeholders or input fixtures.

| Address | Operation | Gas | Input/output and validation |
|---|---|---|---|
| 0x01 | ECRECOVER | 3000 | Read128 right-zero-padded bytes, ignore excess: hash,v,r,s. v=27/28, 0<r,s<curve order (no low-s restriction here). Valid returns address padded32; invalid empty. |
| 0x02 | SHA256 | 60+12*w(n) | All input;32-byte digest. |
| 0x03 | RIPEMD160 | 600+120*w(n) | All input;20-byte digest left-padded32. |
| 0x04 | IDENTITY | 15+3*w(n) | Return input exactly. |
| 0x05 | MODEXP | Formula below | Three32-byte length headers, right-zero-pad operands, ignore excess; output modulus-length bytes. |
| 0x06 | BN254 ADD | 150 | Read128 padded bytes, ignore excess; canonical field points, infinity=(0,0); output64. |
| 0x07 | BN254 MUL | 6000 | Read96 padded bytes, ignore excess; point64/scalar32; output64. |
| 0x08 | BN254 PAIRING | 45000+34000*k | Length multiple192, including empty (true); canonical curve/subgroup-valid points;32-byte bool. |
| 0x09 | BLAKE2F | rounds | Exactly213 bytes, rounds first4 big-endian; final flag0/1; h,m,t little-endian words;64-byte compression output. |
| 0x0a | KZG POINT EVALUATION | 50000 | Exactly192: versioned hash32,z32,y32,commitment48,proof48; canonical scalars, valid commitment/proof and matching versioned SHA256 hash; return4096 and BLS scalar modulus, each32 bytes. |
| 0x0b | BLS G1 ADD | 375 | Exactly256 bytes, output128; curve check, no subgroup check. |
| 0x0c | BLS G1 MSM | floor(12000*k*D1[k]/1000) | Nonempty multiple160; subgroup checks; output128. |
| 0x0d | BLS G2 ADD | 600 | Exactly512 bytes, output256; curve check, no subgroup check. |
| 0x0e | BLS G2 MSM | floor(22500*k*D2[k]/1000) | Nonempty multiple288; subgroup checks; output256. |
| 0x0f | BLS PAIRING | 37700+32600*k | Nonempty multiple384; subgroup checks; output32 bool. |
| 0x10 | MAP Fp TO G1 | 5500 | Exactly64 canonical field bytes; output128. |
| 0x11 | MAP Fp2 TO G2 | 23800 | Exactly128 canonical field bytes; output256. |
| 0x0100 | P256VERIFY | 6900 | Exactly160 bytes: hash,r,s,x,y each32; valid secp256r1 signature returns32-byte1; invalid length/scalars/point/signature returns empty. |

MODEXP: each advertised length<=1024, else exceptional failure before computation. Let L=max(base length,modulus length), W=ceil(L/8), C=16 if L<=32 else2*W^2. Let H=integer first min(32,exponent length) exponent bytes; b=max(bit_length(H)-1,0). Iterations=max(1,b) for exponent length<=32, otherwise max(1,16*(exponent length-32)+b). Gas=max(500,C*iterations). Zero modulus yields all-zero modulus-length output; base length=modulus length=0 returns empty. All byte length arithmetic is checked before allocation.

BLS field elements use64-byte big-endian canonical values (top16 bytes zero), Fp2 order c0 then c1; G1=x,y, G2=x.c0,x.c1,y.c0,y.c1. Infinity is all-zero point. Scalars are32-byte integers, reduced by group arithmetic. Pairing and MSM require prime-order subgroup membership; ADD intentionally does not. Use exact pinned map-to-curve algorithms and infinity rules.

The complete128-entry discount schedules D1,D2 are copied below in k=1..128 order; use last value for k>128. Source: [BLS encoding and discount tables](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/precompiled_contracts/bls12_381/__init__.py). Other normative implementation sources: [MODEXP](https://github.com/ethereum/execution-specs/blob/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/precompiled_contracts/modexp.py), [precompile directory](https://github.com/ethereum/execution-specs/tree/a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam/vm/precompiled_contracts).

```text
D1=[1000,949,848,797,764,750,738,728,719,712,705,698,692,687,682,677,673,669,665,661,658,654,651,648,645,642,640,637,635,632,630,627,625,623,621,619,617,615,613,611,609,608,606,604,603,601,599,598,596,595,593,592,591,589,588,586,585,584,582,581,580,579,577,576,575,574,573,572,570,569,568,567,566,565,564,563,562,561,560,559,558,557,556,555,554,553,552,551,550,549,548,547,547,546,545,544,543,542,541,540,540,539,538,537,536,536,535,534,533,532,532,531,530,529,528,528,527,526,525,525,524,523,522,522,521,520,520,519]
D2=[1000,1000,923,884,855,832,812,796,782,770,759,749,740,732,724,717,711,704,699,693,688,683,679,674,670,666,663,659,655,652,649,646,643,640,637,634,632,629,627,624,622,620,618,615,613,611,609,607,606,604,602,600,598,597,595,593,592,590,589,587,586,584,583,582,580,579,578,576,575,574,573,571,570,569,568,567,566,565,563,562,561,560,559,558,557,556,555,554,553,552,552,551,550,549,548,547,546,545,545,544,543,542,541,541,540,539,538,537,537,536,535,535,534,533,532,532,531,530,530,529,528,528,527,526,526,525,524,524]
```

## Completeness evidence expected from implementation

This manifest is a requirement baseline, not an implementation completion claim. Validate every assigned opcode and invalid-byte class, all exceptional reasons, zero/huge offsets, immediate truncation/forbidden ranges, signed arithmetic boundaries, nested revert/success journals, cross-frame state spill refunds, static paths, delegation/precompile interactions, create collision/nonce/deposit limits, EIP-7708 log ordering, and positive/negative cryptographic precompile vectors against the pinned sources. Keep Shanghai behavior separately selectable and preserve its existing proofs/regressions. Block building, consensus validation, state-root trie construction and peer networking are outside this opcode-level completeness claim.
