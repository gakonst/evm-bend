# Lead handoff status

Transaction API compiles; field/getter contracts in transaction-api.md. Main model/main/compiler unchanged. Root required source allowlist restored with only gas.bend transitive addition; regression scratch moved outside sourcecopy. check.sh exited0: 452 legacy VM comparisons, 436 supported evm2 comparisons, mutation guards/proofs and demo passed (full/transaction-regression.log). These legacy counts do not establish Amsterdam corpus completion.

Current verified focused evidence: root acceptance execution13 JS/native; intrinsic10 JS/native; validation boundary additions being checked by root; validator29 native (fresh script); finish21 JS/native; auth15 unit +5 flow JS; flow8 JS; runtime3 JS. Native full compiler used high memory; optional runtime/auth-specific native attempts were cancelled, not passed. Root end-to-end native acceptance13 demonstrates compiled prepare/VM/finish.

Latest corrections: valid initcode limit131072; tail-recursive intrinsic/validation/byte len (agents2/6); immediate empty-account cleanup with absent tombstones preserving warm metadata; no fee transfer logs; selfdestruct balance preserved after fee credits. Nested CREATE storage-only collision/original-storage fixes now being tested by agent5 in isolated existing-module integration patch. No complete corpus or universal proof claim.
