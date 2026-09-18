#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export BEND_NO_TELEMETRY=1
export PATH="/srv/nanocodex/.bend/bin:/srv/nanocodex/.cargo/bin:$PATH"
bend PROOF.bend
bend word-tests.bend
bend word-tests-spec.bend
bend word-tests-vectors.bend
python test_mutations.py
python test_vm.py
cargo build --locked --manifest-path evm2-adapter/Cargo.toml
python test_evm2.py
bend main.bend -o evm-demo
./evm-demo
