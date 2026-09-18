#!/usr/bin/env python3
"""Independent integer oracle for the implemented Shanghai subset.
Run: python3 test_vm.py
Not an official EELS or evm2 differential test. Generated inputs and full observed
states are retained in tests-generated/ and tests-results.json. No dependencies.
"""
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
BEND = '/srv/nanocodex/.bend/bin/bend'
SEED = 0x5A17
ADD_SEED = 0xADD256
MASK = (1 << 256) - 1

def oracle(code, gas):
    """Python integers; no Bend word/decoder arithmetic reused. Stack top first."""
    pc, stack = 0, []
    while True:
        op = code[pc] if pc < len(code) else 0
        width = op - 95 if 96 <= op <= 127 else 0
        cost = 3 if width or op == 1 else 2 if op in (80, 95) else 0
        if gas < cost:
            status, gas = 'out_of_gas', 0
            break
        gas -= cost
        if op == 0:
            status = 'halted'
            break
        if op == 254:
            status, gas = 'invalid', 0
            break
        if op not in (1, 80, 95) and not width:
            status = 'unsupported'
            break
        if op in (1, 80) and len(stack) < (2 if op == 1 else 1):
            status, gas = 'underflow', 0
            break
        if (width or op == 95) and len(stack) >= 1024:
            status, gas = 'overflow', 0
            break
        if width or op == 95:
            payload = bytes(code[pc + 1:pc + 1 + width])
            stack.insert(0, int.from_bytes(payload.ljust(width, b'\0'), 'big'))
            pc += 1 + width
        elif op == 1:
            a, b = stack.pop(0), stack.pop(0)
            stack.insert(0, (a + b) & MASK)
            pc += 1
        else:
            stack.pop(0)
            pc += 1
    words = ''.join('W{' + ','.join(str((x >> (32*i)) & 0xffffffff) for i in range(8)) + '};' for x in stack)
    return f'{status}|{gas}|{pc}|{words}'

def cases():
    out = []
    def add(name, code, gas):
        out.append(dict(name=name, code=list(code), gas=gas))
    for name, code, gas in [
        ('empty', [], 0), ('stop-retains-pc', [0,254], 9),
        ('add-oog-before-underflow', [1], 2), ('add-underflow', [1], 3),
        ('pop-oog-before-underflow', [80], 1), ('pop-underflow', [80], 2),
        ('one-add-underflow-retains-stack', [96,23,1], 6),
        ('one-add-oog-retains-stack', [96,23,1], 5),
        ('invalid-retains-stack', [96,23,254], 20), ('invalid-zero-gas', [254], 0),
        ('unsupported-retains-gas-stack', [96,23,2], 20),
        ('push0-exact', [95], 2), ('push0-oog', [95], 1),
        ('push1-exact', [96,7], 3), ('push1-oog', [96,7], 2),
        ('pop-exact', [95,80], 4), ('add-exact', [95,95,1], 7),
        ('payload-not-executed', [100,0,254,1,80,255], 3),
        ('full256-wrap', [127]+[255]*32+[96,1,1], 9),
    ]: add(name, code, gas)
    for bits in range(32,257,32):
        add(f'carry-{bits}', [127]+list(((1<<bits)-1).to_bytes(32,'big'))+[96,1,1], 9)
    for width in range(1,33):
        add(f'push-{width}-endian', [95+width]+[(i*31+width)%256 for i in range(width)], 3)
        add(f'push-{width}-truncated', [95+width]+[254]*(width//2), 3)
    for byte in [2,32,81,94,128,253,255]: add(f'unsupported-{byte}', [byte], 13)
    for count, gas in [(1024,2048),(1025,2050),(1025,2048),(1025,2049)]:
        add(f'stack-{count}-gas-{gas}', [95]*count, gas)
    rng = random.Random(SEED)
    for index in range(60):
        code = []
        for _ in range(rng.randrange(1,13)):
            op = rng.choice([95,96,99,111,127,1,80])
            code.append(op)
            if 96 <= op <= 127: code.extend(rng.randrange(256) for _ in range(op-95))
        if index % 4 == 0: code = code[:rng.randrange(len(code)+1)]
        if index % 5 == 0: code.append(rng.choice([0,254,255]))
        add(f'random-{index:02}', code, rng.choice([0,2,3,7,12,25,100]))
    add_rng = random.Random(ADD_SEED)
    for index in range(64):
        a, b = add_rng.getrandbits(256), add_rng.getrandbits(256)
        code = [127] + list(a.to_bytes(32, 'big')) + [127] + list(b.to_bytes(32, 'big')) + [1, 0]
        add(f'random-full256-add-{index:02}', code, 9 if index % 2 == 0 else 100)
    return out

def source(batch):
    text = '''import Base
import ./vm.bend as VM
import ./render.bend as R

def repeat(n: Nat, +byte: U32) -> +List<U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      byte <> repeat(p, byte)

def main() -> IO(Unit):
  do IO<Unit>:
'''
    for case in batch:
        code = case['code']
        expr = f'repeat({len(code)}n, 95)' if len(code) >= 1024 and set(code)=={95} else '['+', '.join(map(str,code))+']'
        text += f'    IO.print("{case["name"]}:" ++ R.state(VM.run({expr}, {case["gas"]}n)))\n'
    return text

def run(command, timeout):
    started = time.monotonic()
    try:
        p = subprocess.run(command, cwd=ROOT, env={**os.environ,'BEND_NO_TELEMETRY':'1'}, capture_output=True, text=True, timeout=timeout)
        return dict(command=list(map(str,command)), returncode=p.returncode, seconds=round(time.monotonic()-started,3), stdout=p.stdout, stderr=p.stderr)
    except subprocess.TimeoutExpired as e:
        def decode(v): return v.decode(errors='replace') if isinstance(v, bytes) else v or ''
        return dict(command=list(map(str,command)), returncode=None, seconds=round(time.monotonic()-started,3), stdout=decode(e.stdout), stderr=decode(e.stderr), error=f'timeout after {timeout}s')

def main():
    generated = ROOT/'tests-generated'
    generated.mkdir(exist_ok=True)
    vectors = cases()
    results = dict(seed=SEED, add_seed=ADD_SEED, random_full256_add_cases=64, oracle='independent Python big-integer Shanghai subset; not EELS or evm2', cases=len(vectors), backend_comparisons=0, passed=0, failures=[], commands=[], results=[])
    (generated/'vectors.json').write_text(json.dumps(vectors,indent=2)+'\n')
    results['module_sha256'] = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['core.bend','decode.bend','vm.bend','render.bend','evmword.bend','gas.bend']}
    for start in range(0,len(vectors),16):
        batch = vectors[start:start+16]
        # Sources live at project root so imports have the same resolution as main.
        src = ROOT/f'tests-batch-{start//16:02}.bend'
        src.write_text(source(batch))
        binary = generated/f'batch-{start//16:02}'
        commands = [('js',[BEND,str(src)],60),('build',[BEND,str(src),'-o',str(binary)],120),('native',[str(binary)],60)]
        build_ok = False
        for backend, command, timeout in commands:
            if backend == 'native' and not build_ok: continue
            record = run(command,timeout)
            record['backend'] = backend
            results['commands'].append(record)
            if backend == 'build':
                build_ok = record['returncode']==0
                if not build_ok: results['failures'].append(dict(batch=start,backend=backend,error=record))
                continue
            observed = dict(line.split(':',1) for line in record['stdout'].splitlines() if ':' in line and line.split(':',1)[0] in {c['name'] for c in batch})
            for case in batch:
                expected = oracle(case['code'],case['gas'])
                actual = observed.get(case['name'])
                ok = record['returncode']==0 and actual == expected
                result = dict(name=case['name'],backend=backend,expected=expected,actual=actual,passed=ok)
                results['results'].append(result)
                results['backend_comparisons'] += 1
                results['passed'] += int(ok)
                if not ok: results['failures'].append(result)
        (ROOT/'tests-results.json').write_text(json.dumps(results,indent=2)+'\n')
        print(f'Batch {start//16}: {results["passed"]}/{results["backend_comparisons"]} passed',flush=True)
    results['success'] = not results['failures'] and results['backend_comparisons']==2*len(vectors)
    (ROOT/'tests-results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps({k:results[k] for k in ['cases','backend_comparisons','passed','success']}))
    return 0 if results['success'] else 1

if __name__ == '__main__':
    sys.exit(main())
