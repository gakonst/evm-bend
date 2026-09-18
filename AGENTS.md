# Bend Amsterdam EVM

The user explicitly requires a complete Amsterdam/Glamsterdam interpreter, then speed optimization. The earlier Shanghai subset remains regression coverage only. Target the pinned snapshot in AMSTERDAM-SPEC.md, not an unspecified future mainnet activation.

Read references/BendGuide.md before editing Bend. Keep theorem statements unchanged when repairing implementations; do not weaken laws to make proofs pass. No unsafe annotations, proof holes, unchecked axioms, or foreign opcode semantics. The crypto-only precompile adapter is an explicit trusted boundary.

Run appropriate full interpreter differentials and existing ./check.sh regressions after semantic changes. Distinguish universal laws, concrete tests, differential evidence, and outstanding proof obligations. Host resource exhaustion must not masquerade as EVM OOG. Do not claim a complete correctness proof or production readiness.

bend-local.sh uses a project-local copy of Bend 2.0.5 with a bounded native value-layout workaround. The installed toolchain remains unchanged; preserve and document the patch separately.
