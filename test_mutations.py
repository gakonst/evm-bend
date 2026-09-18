#!/usr/bin/env python3
"""Ensure the proof gate rejects semantic edits while laws stay fixed."""
import json, os, pathlib, shutil, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parent
BEND = '/srv/nanocodex/.bend/bin/bend'
ENV = dict(os.environ, BEND_NO_TELEMETRY='1')
mutations = [
    ('stack limit 1025', 'core.bend', 'List.length(&2, W.Word, stack), 1024n', 'List.length(&2, W.Word, stack), 1025n'),
    ('incorrect gas subtraction', 'gas.bend', 'Some{gas}', 'Some{0n}'),
    ('ADD overcharge', 'core.bend', 'case Add{}:\n      3n', 'case Add{}:\n      4n'),
    ('POP keeps the top', 'core.bend', 'S{gas, 1n+pc, rest, Running{}}', 'S{gas, 1n+pc, a <> rest, Running{}}'),
    ('fault preserves gas', 'core.bend', 'fault(pc, stack, BadOpcode{})', 'S{gas, pc, stack, BadOpcode{}}'),
]
results = []
for label, file, old, new in mutations:
    with tempfile.TemporaryDirectory(prefix='proof-mutation-', dir=ROOT) as tmp:
        tmp = pathlib.Path(tmp)
        for p in ROOT.glob('*.bend'):
            shutil.copy2(p, tmp / p.name)
        p = tmp / file
        src = p.read_text()
        assert src.count(old) == 1, (label, src.count(old))
        p.write_text(src.replace(old, new))
        result = subprocess.run([BEND, 'PROOF.bend'], cwd=tmp, env=ENV, capture_output=True, text=True, timeout=60)
        diagnostic = result.stdout + result.stderr
        assert result.returncode != 0 and 'expected' in diagnostic and 'observed' in diagnostic, (label, diagnostic)
        assert any(s in diagnostic for s in ['LAWS.', 'Laws.', 'push_bounded', 'push_branch']), (label, diagnostic)
        results.append({'mutation': label, 'rejected': True, 'diagnostic': diagnostic})
        print('Rejected:', label)
(ROOT / 'mutation-results.json').write_text(json.dumps(results, indent=2) + '\n')
