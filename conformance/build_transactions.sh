#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export BEND_NO_TELEMETRY=1
python3 conformance/generate_tx_codec.py
./bend-local.sh full/transaction-main.bend -o evm-transaction-native
./bend-local.sh full/transaction-main.bend -o evm-transaction.js
python3 - <<'PY'
import re
from pathlib import Path
p=Path('evm-transaction.js')
p.write_text(re.sub(r'\$[\w$-]+',lambda m:m[0].replace('-','_'),p.read_text()))
PY
