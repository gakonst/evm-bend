# Goal: 100% passing EVM on Bend

The user's standing completion criterion is complete EVM conformance in Bend, targeting the pinned latest Amsterdam/Glamsterdam execution specification. Passing selected differential cases is a milestone, not completion.

Completion requires:

- Every required opcode, exceptional path, gas rule, call/create behavior, state transition and precompile behaves according to the pinned specification.
- The complete applicable execution-spec conformance corpus passes on both supported Bend backends, with no skipped required cases or unsupported required behavior. Record the corpus revision, total case count and complete results.
- Compare execution status, output, gas and refunds, logs, and complete resulting state. Resolve reference disagreements against the specification; do not alter expectations merely to make tests pass.
- Implement missing execution or transaction-boundary behavior needed by the applicable corpus. A prepared-frame runner alone is not the completion gate.
- Regressions, arithmetic checks and existing laws continue to pass. Keep the crypto and compiler trust boundaries explicit. Test-suite success is not an end-to-end correctness proof.

Current status: NOT COMPLETE. The existing passing differential and fixture suites establish a working baseline, not full conformance.

Prioritize reaching this goal before major performance optimization. Preserve conformance while optimizing afterward.
