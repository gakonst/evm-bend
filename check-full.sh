#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export BEND_NO_TELEMETRY=1
export PATH="/srv/nanocodex/.cargo/bin:$PATH"
cargo build --locked --manifest-path precompile-host/Cargo.toml
cargo build --locked --manifest-path revm-adapter/Cargo.toml
python3 evm.py --build
python3 evm.py --backend js --build
EVM_BACKEND=native python3 test_full_differential.py
EVM_BACKEND=js python3 test_full_differential.py
python3 test_precompiles.py
python3 test_frame_invariants.py
python3 test_contract_fixtures.py
python3 test_word_ops.py
./check.sh
