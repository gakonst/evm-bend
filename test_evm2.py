#!/usr/bin/env python3
"""Compare recorded, hash-matched Bend executions with the real evm2 interpreter."""
import hashlib, json, pathlib, subprocess
ROOT = pathlib.Path(__file__).resolve().parent
ADAPTER = ROOT / 'evm2-adapter/target/debug/evm2-frame-adapter'

def parse_bend(line):
    status, gas, pc, words = line.split('|')
    stack = []
    for word in words.split(';'):
        if not word:
            continue
        assert word.startswith('W{') and word.endswith('}'), word
        limbs = list(map(int, word[2:-1].split(',')))
        assert len(limbs) == 8
        stack.append(sum(x << (32*i) for i, x in enumerate(limbs)))
    return {'status': status, 'gas': int(gas), 'pc': int(pc), 'stack': stack}


def main():
    revision = subprocess.check_output(['git', '-C', str(ROOT.parent/'evm2-reference'), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == '0a5314efb28cbef7dc1a83e38ac75860b974adcd', revision
    saved = json.loads((ROOT / 'tests-results.json').read_text())
    assert saved['success'], 'Run python test_vm.py first'
    for name, expected in saved['module_sha256'].items():
        actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        assert actual == expected, f'{name} changed: rerun test_vm.py'
    vectors = {x['name']: x for x in json.loads((ROOT/'tests-generated/vectors.json').read_text())}
    bend = {(x['name'], x['backend']): parse_bend(x['actual']) for x in saved['results']}
    eligible = [x for x in vectors.values() if bend[x['name'], 'js']['status'] != 'unsupported']
    skipped = [x['name'] for x in vectors.values() if bend[x['name'], 'js']['status'] == 'unsupported']
    proc = subprocess.run([str(ADAPTER)], input=''.join(json.dumps({'code':x['code'],'gas':x['gas']})+'\n' for x in eligible),
                          text=True, capture_output=True, timeout=120)
    assert proc.returncode == 0, proc.stderr
    rows = [json.loads(x) for x in proc.stdout.splitlines() if x.strip()]
    assert len(rows) == len(eligible), (len(rows),len(eligible), proc.stderr)
    failures, diagnostics, comparisons = [], [], []
    exceptional = {'out_of_gas','underflow','overflow','invalid'}
    for vector, raw in zip(eligible, rows):
        oracle = dict(raw)
        oracle['stack'] = [int(x,16) for x in raw['stack']]
        assert oracle['status'] in exceptional | {'halted'}, raw
        for backend in ['js','native']:
            observed = bend[vector['name'], backend]
            # Terminal stack/PC and fault subtype are diagnostic observations.
            # Success stack and remaining gas are compared exactly.
            want = {'halted':oracle['status']=='halted','gas':oracle['gas']}
            got = {'halted':observed['status']=='halted','gas':observed['gas']}
            if want['halted'] and got['halted']:
                want['stack'],got['stack'] = oracle['stack'],observed['stack']
            passed = want == got
            record = {'name':vector['name'],'backend':backend,'passed':passed}
            comparisons.append(record)
            if not passed:
                failures.append(dict(record,bend=observed,evm2=oracle))
            differences = {k:{'bend':observed[k],'evm2':oracle[k]} for k in ['status','pc','stack']
                           if observed[k]!=oracle[k] and (k!='stack' or not want['halted'])}
            if differences:
                diagnostics.append(dict(record,differences=differences))
    report = dict(reference='alloy-rs/evm2',commit='0a5314efb28cbef7dc1a83e38ac75860b974adcd',
                  fork='Shanghai',cases=len(eligible),backend_comparisons=len(comparisons),
                  passed=sum(x['passed'] for x in comparisons),skipped_unsupported=skipped,
                  failures=failures,diagnostic_differences=diagnostics,results=comparisons,
                  adapter_stderr=proc.stderr,success=not failures,
                  adapter_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in [ROOT/'evm2-adapter/src/main.rs', ROOT/'evm2-adapter/Cargo.lock']})
    (ROOT/'evm2-results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['cases','backend_comparisons','passed','skipped_unsupported','success']}))
    print('Diagnostic differences:',len(diagnostics))
    if failures:
        print(json.dumps(failures[:3],indent=2))
        raise SystemExit(1)

if __name__ == '__main__':
    main()
