#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/srv/nanocodex/.bend/bin:/srv/nanocodex/.bun/bin:$PATH"
bend full/call-tests.bend -o full/call-tests.js
# Bend's JS emitter currently preserves hyphens in imported module identifiers.
python - <<'PY'
import re
p='full/call-tests.js'
s=open(p).read()
s=re.sub(r'\$[\w$-]+',lambda m:m[0].replace('-','_'),s)
open(p,'w').write(s)
PY
bun full/call-tests.js | tee full/call-test-results.log
