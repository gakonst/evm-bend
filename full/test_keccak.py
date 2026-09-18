"""Concrete native/JS differential vectors; not a universal proof.
Run: full/.keccak-venv/bin/python full/test_keccak.py
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from Crypto.Hash import keccak

ROOT = Path(__file__).resolve().parent
BEND = Path.home() / '.bend/bin/bend'
ENV = dict(os.environ, BEND_NO_TELEMETRY='1')
cases = [('empty', b''), ('abc', b'abc')]
for n in [1, 31, 32, 64, 134, 135, 136, 137, 271, 272, 273, 512, 1024]:
    cases.append((f'pattern-{n}', bytes((i * 37 + 11) % 256 for i in range(n))))
source = 'import Base\nimport ./keccak.bend as K\nimport ../evmword.bend as W\n\ndef main() -> IO(Unit):\n  do IO<Unit>:\n'
expected = []
for name, data in cases:
    digest = keccak.new(digest_bits=256, data=data).digest()
    limbs = [int.from_bytes(digest[i:i+4], 'big') for i in range(28, -1, -4)]
    expected.append('W{' + ','.join(map(str, limbs)) + '}')
    source += '    IO.print(W.show(K.hash([' + ','.join(map(str, data)) + '])))\n'
path = ROOT / 'keccak-tests.bend'
path.write_text(source)
def run(args):
    p = subprocess.run(list(map(str,args)), cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=180)
    if p.returncode: raise RuntimeError(p.stdout + p.stderr)
    return p.stdout
run([BEND, ROOT / 'keccak.bend'])
results = {}
for backend in ['native', 'js']:
    target = ROOT / ('keccak-tests-native' if backend == 'native' else 'keccak-tests.js')
    run([BEND, path, '-o', target])
    output = run([target] if backend == 'native' else [shutil.which('node') or shutil.which('bun'), target])
    actual = re.findall(r'W\{[0-9,]+\}', output)
    assert actual == expected, (backend, actual, expected)
    results[backend] = {'passed': len(cases), 'vectors': [n for n, _ in cases]}
(ROOT / 'keccak-test-results.json').write_text(json.dumps(results, indent=2) + '\n')
print(json.dumps(results))
