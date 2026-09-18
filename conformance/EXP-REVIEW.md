# Isolated EXP early-termination review

Only `word-ops.bend` differs from the frozen root/full Bend source snapshot. Main sources and binaries were not edited, no main processes were stopped, and nothing was integrated or published. Scratch root: `/omarchy-desktop/evm-bend-exp-fix` (host `/srv/nanocodex/workspace/evm-bend-exp-fix`).

## Change and reasoning

`exp_zero` checks whether the remaining dependent-width bit word is zero. `exp_stop` first returns the accumulator for a zero exponent, then returns zero for a zero base with a positive exponent. A deferred continuation performs the original squaring/multiplication only when needed. The original structurally decreasing 256-bit bound and modular multiplication remain intact. No foreign opcode implementation, unsafe annotation, theorem change, or proof weakening was introduced.

The maintained mathematical invariant is `acc * base^remaining_exponent (mod 2^256)`. Zero exponent gives `acc`, even with zero base; positive exponent with zero base gives zero. Thus `0^0 = 1` is preserved. High exponent bits are retained and tested. This reasoning and the concrete tests are not a new universal machine-checked correctness proof.

## Exact pinned fixtures

Rows come from `../evm-bend-state-triage/selected-inventory.jsonl` at zero-based indices 7655, 14190, and 804. Each has one Amsterdam post variant. The unchanged main adapter and runner were copied into scratch, and the main pinned fixtures and existing crypto/envelope helpers were used read-only. Every result checked the expected exception, state root, and logs hash; full actual state and comparisons are retained in `evidence/state-{backend}-{index}.json`.

| Index | Fixture | Native seconds | JS seconds | Result |
|---|---|---:|---:|---|
| 7655 | test_exp_power256 | 3.004314 | 3.432291 | pass both |
| 14190 | test_exp_power256_of256 (612 EXP opcodes) | 184.317957 | 332.660872 | pass both |
| 804 | test_create_address_dynamic_nonce | 14.309270 | 24.346515 | pass both |

Frozen main native observations: 7655: 98.710596s, 804: 459.257670s, 14190: 506.482903s. These are contextual observations, not controlled paired speedups; concurrent host workloads differed. The main frozen native gate later reported 15,918/15,918 pass. This patch was tested on the three selected state fixtures only; integration requires the parent’s full gate rerun.

## Validation

- Independent Python bigint `pow(base, exponent, 2**256)`: 320/320 EXP vectors on native and 320/320 on JS. Seed 612256; 126 edge combinations, 128 random full-width pairs, 64 random small-exponent pairs, and two extra cases. Includes zero, one, even/odd bases, maximum words, and exponents with bits 31, 32, 127, 128, 254, and 255 set.
- Existing complete arithmetic suite: 6,733/6,733 native and 6,733/6,733 JS. Python bigint oracle, seed 256, no skipped batches.
- Existing check.sh regressions executed through `run-check-isolated.sh`: proof/word checks, mutation rejection, 452/452 Python-oracle backend comparisons, 436/436 supported evm2-subset backend comparisons, and demo passed. The existing evm2 subset reports its eight unsupported cases as before. The wrapper uses `./bend-local.sh` for direct Bend commands and the existing read-only evm2 binary, avoiding cargo writes through the shared helper symlink. The mutation and VM suites were additionally rerun through `run-local-regression.py` with `./bend-local.sh`; the wrapper makes the mutation proof path absolute because bend-local.sh changes its working directory. The initial relative-path wrapper attempt checked the wrong unmutated file and was corrected; its error log is retained. Test sources were not edited.
- Full interpreter differential native: 624/624 passed, zero failures, 9.193339s.
- Full interpreter differential js: 624/624 passed, zero failures, 162.667820s.

Runtime logs: `evidence/arithmetic-full.log`, `evidence/frame-build-{native,js}.log`, and `evidence/full-differential-{native,js}.log`. Transaction native build: 157.645s; JS emit: 4.229s. JS identifiers normalized using `$[\w$-]+`, replacing identifier hyphens with underscores.

Complete arithmetic suite wall/user/sys timing (JS followed by native):

```text
real	18m25.880s
user	20m37.411s
sys	1m5.744s
```

## Exact hashes

- Original word-ops.bend: `7af1742deefd14339996bb33be0521b6786f64a47e2a5a2df44b5f60d9798b1e`
- Patched word-ops.bend: `27e790ae2751a9f0bd60643dec824498fdcc82efba727454e2292e88cf84354c`
- toolchain-debug/main.ts: `2a8c6fafcd855feec524cdc62a6f2411c430f0b7c93b875d72dfb022234191e7`
- toolchain-debug/base.bend: `b2d53bbd83639c3ae27260b318efa09de9df6006a556ac6ef41c104ea164917a`
- toolchain-debug/bend.ts: `fe3c2b0b306fccbe44efec349d8f339b6efdaceb090b3d3049c74a1a6015c859`
- toolchain-debug/comp.ts: `1e4e750fb70d14a896ef4ebe44726dd3fe2d0bd4a924c93842bf0365cc451728`
- bend-local.sh: `b6043e6038babe1b36bfeea548920d9d1593f0e723e2568330995e1262d6745f`
- conformance/bend_adapter.py: `f7bfe0b491f035915d96741c44fe44cc00e0626026e9a424f30f21a506d15faf`
- conformance/runner.py: `957316da131b863925fcf52eee067c7d6e942198f725f7ed89231a84160c898d`
- evidence/baseline-transaction-native: `58a65f4745d9d33035ab3dd7f8a9d0be13d1063ffd1c4dd80f2cc7367ad402a1`
- evm-transaction-native: `2f831c8ab3fded7d9f855e4204c8e7f9a2180cf59c3b970d30406fb248d17dc2`
- evm-transaction.js: `940ccfc4195984171df2b00ea29ed3e64daf81cd7d0833580d4c878c45b0a039`

All snapshot Bend source hashes are in `baseline-source-sha256.json`; patched hashes are in `evidence/patched-source-sha256.json`. Compiler/helper reuse is recorded in `evidence/build-provenance.json`.

## Exact implementation diff

```diff
--- a/word-ops.bend
+++ b/word-ops.bend
@@ -188,17 +188,42 @@
 def mulmod(a: L.Word,b: L.Word,+m: L.Word) -> L.Word:
   mulmod_if(a,b,m,L.is_zero(m))
 
-# Exponentiation by squaring consumes the exponent's 256 bits.
-def exp_go(n: Nat,e: Word(n),+base: L.Word,acc: L.Word) -> L.Word:
+# Exponentiation is modulo 2^256. Check the exponent first so 0^0 is 1.
+def exp_zero(n: Nat,e: Word(n)) -> Bool:
   match n:
     case 0n:
-      acc
+      True{}
     case 1n+p:
       match e:
         case WCon{False{},tail}:
-          exp_go(p,tail,mul(base,base),acc)
+          exp_zero(p,tail)
+        case WCon{True{},tail}:
+          False{}
+
+def exp_stop(ezero: Bool,bzero: Bool,acc: L.Word,next: Unit -> L.Word) -> L.Word:
+  match ezero:
+    case True{}:
+      acc
+    case False{}:
+      match bzero:
+        case True{}:
+          L.zero()
+        case False{}:
+          next(Unit{})
+
+# The original structurally decreasing 256-bit bound is retained.
+def exp_go(n: Nat,+e: Word(n),+base: L.Word,+acc: L.Word) -> L.Word:
+  match n:
+    case 0n:
+      acc
+    case 1n++p:
+      match e:
+        case WCon{False{},+tail}:
+          exp_stop(exp_zero(p,tail),L.is_zero(base),acc,
+            u => exp_go(p,tail,mul(base,base),acc))
         case WCon{True{},tail}:
-          exp_go(p,tail,mul(base,base),mul(acc,base))
+          exp_stop(False{},L.is_zero(base),acc,
+            u => exp_go(p,tail,mul(base,base),mul(acc,base)))
 
 def exp(base: L.Word,exponent: L.Word) -> L.Word:
   exp_go(256n,bits(exponent),base,L.from_u32(1))
```
