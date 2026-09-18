# Host-bridge hardening progress

Signed-byte requests no longer require redundant transaction metadata. Signed fields override fixture annotations. Missing or inconsistent authority recovery is a host error; explicitly unrecoverable authority signatures remain null. Decoder errors must belong to the pinned wire/cryptographic vocabulary before they can produce transaction rejections. Bend semantic rejection mapping and 256-bit gas serialization are preserved.

Verified: 8 fixture-backed bridge tests and 11 runner tests pass. The exhaustive serialization/context audit checked 15,918 contexts and 15,898 decoded transactions, including both accepted gas values above Nat48; 7,329 authorizations were preserved, including 21 unrecoverable signatures. All 20 wire rejection commitments and 933 expected-rejection prestate commitments match. Zero unexpected bridge mismatches or host limits. These are bridge checks, not EVM execution passes.

The previous native and JS execution runs each passed 15,918/15,918 at commit 35db6bfb7464a12a8013f5ce61dde6876813be91. The adapter change invalidates reuse of that fingerprint for current source. Fresh execution gates are pending; remaining execution failures are not yet known. No binaries or Bend source changed.

```sh
python3 -m unittest discover -s conformance -p test_host_bridge.py -v
python3 -m unittest discover -s conformance -p test_runner.py -v
python3 conformance/audit_host_bridge.py
python3 -u conformance/full_state_gate.py --backend native --workers 12 --timeout 1200 --output state-gate-host-hardened
python3 -u conformance/full_state_gate.py --backend js --workers 12 --timeout 3600 --output state-gate-host-hardened
```

Audit caches, raw corpus, and binaries are excluded from publication. Summary: host-bridge-summary.json. Complete runs below must retain exact fingerprints and every fixture ID.
