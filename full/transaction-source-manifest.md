# Transaction source additions and boundaries

Original allowed source roots retained: full/, evmword.bend, word-ops.bend, word-spec.bend, toolchain-debug/, bend-local.sh, AGENTS.md, AMSTERDAM-SPEC.md, references/BendGuide.md.

Necessary transitive addition: root gas.bend (full/gas.bend imports its checked subtraction). Compiler TypeScript sources and source foreign effects were restored into toolchain-debug; full/precompile.js is the source-only crypto process adapter. No build artifacts were copied as implementation dependencies. Broader sources temporarily used by the mandated legacy check.sh regression were moved to sibling evm-bend-transactions-regression-scratch after passing; unrelated copied result JSON and generated files are not delivered as transaction sources.

Pinned EELS Python evidence copies in references/ come from a9792ab73b8195d5a8dc24b2ef6cca7687cd6b2b/src/ethereum/forks/amsterdam. Hashes in transaction-reference-sha256.txt. These are read-only normative evidence, never executed as foreign transaction or EVM semantics. evm2-reference HEAD was verified exactly 0a5314efb28cbef7dc1a83e38ac75860b974adcd. Main evm-bend was not modified.

Generated transaction test JS/native executables and logs are local verification products. Package Bend/source scripts/docs and evidence logs separately; exclude generated executables/JS from a clean source bundle. Reviewable integration patch modifies world.bend, call-selfdestruct.bend, create-enter.bend, create-finish.bend in the isolated copy only. Model record field order is unchanged. See transaction-api.md for transaction record order and getters.
