#!/usr/bin/env python3
"""JSON interface to the native Bend Amsterdam frame interpreter.

This process serializes inputs and renders outputs. EVM execution happens in the
compiled Bend program; cryptographic precompiles use the explicit host helper.
"""
import argparse, re, json, os, pathlib, struct, subprocess, sys, tempfile
ROOT=pathlib.Path(__file__).resolve().parent
BEND=pathlib.Path(os.environ.get('BEND',str(ROOT/'bend-local.sh')))
BUN=pathlib.Path(os.environ.get('BUN',__import__('shutil').which('bun') or str(pathlib.Path.home()/'.bun/bin/bun')))
MAX_GAS=1<<24
MAX_INPUT=16*1024*1024
MASK=(1<<256)-1

def number(x):
    return int(x,16) if isinstance(x,str) and x.lower().startswith('0x') else int(x)

def word(x):
    n=number(x)
    if not 0<=n<=MASK: raise ValueError('word outside uint256')
    return n.to_bytes(32,'big')

def address(x):
    n=number(x)
    if not 0<=n<1<<160: raise ValueError('address outside uint160')
    return n

def data(x):
    if isinstance(x,str): return bytes.fromhex(x.removeprefix('0x'))
    return bytes(x)

def count(n):
    if not 0<=n<1<<32: raise ValueError('length outside uint32')
    return struct.pack('>I',n)

def blob(x):
    x=data(x);return count(len(x))+x

def words(xs):
    return count(len(xs))+b''.join(word(x) for x in xs)

def slots(xs):
    rows=xs.items() if isinstance(xs,dict) else xs
    rows=list(rows)
    return count(len(rows))+b''.join(word(k)+word(v) for k,v in rows)

def encode(case):
    if case.get('fork','Amsterdam').lower() not in ('amsterdam','glamsterdam'):
        raise ValueError('this executable targets the pinned Amsterdam snapshot')
    gas=number(case.get('gas',1_000_000));reservoir=number(case.get('reservoir',0))
    if not 0<=gas<=MAX_GAS or not 0<=reservoir<=MAX_GAS:
        raise ValueError('gas/reservoir must be within the Amsterdam transaction gas cap 2^24')
    addr=address(case.get('address','0x1000000000000000000000000000000000000000'))
    caller=address(case.get('caller','0x2000000000000000000000000000000000000000'))
    ctx=dict(case.get('context',{}))
    origin=address(ctx.get('origin',case.get('origin',caller)))
    ctx_fields=[origin,ctx.get('gasprice',0),address(ctx.get('coinbase',0)),ctx.get('timestamp',0),ctx.get('number',0),ctx.get('prevrandao',0),ctx.get('gaslimit',MAX_GAS),ctx.get('chainid',1),ctx.get('basefee',0),ctx.get('blobbasefee',0),ctx.get('slotnum',0)]
    accounts={address(k):dict(v) for k,v in case.get('accounts',{}).items()}
    if 'code' in case:
        code=data(case['code'])
        accounts.setdefault(addr,{}).setdefault('code',code)
    else: code=data(accounts.get(addr,{}).get('code',b''))
    # A raw frame starts after transaction entry: sender/recipient/coinbase and
    # all active precompiles are warm. Fixtures can override warmth explicitly.
    warm={origin,caller,addr,address(ctx.get('coinbase',0)),*range(1,18),256}
    for a in warm: accounts.setdefault(a,{'exists':False}).setdefault('warm',True)
    for a in case.get('warm_addresses',[]): accounts.setdefault(address(a),{'exists':False})['warm']=True
    initial= count(gas)+count(reservoir)+blob(code)+blob(case.get('input',b''))+word(addr)+word(caller)+word(case.get('value',0))+bytes([bool(case.get('static',False))])
    context=b''.join(word(x) for x in ctx_fields)+words(ctx.get('blobhashes',[]))+slots(ctx.get('blockhashes',{}))
    rows=[]
    for a,acc in sorted(accounts.items()):
        storage=acc.get('storage',{})
        nonce=number(acc.get('nonce',0))
        if not 0<=nonce<1<<64: raise ValueError('nonce outside uint64')
        rows.append(word(a)+word(acc.get('balance',0))+word(nonce)+blob(acc.get('code',b''))+slots(storage)+slots(acc.get('original_storage',storage))+slots(acc.get('transient',{}))+bytes([bool(acc.get('warm',False)),bool(acc.get('exists',True)),bool(acc.get('created',False))])+words(acc.get('warm_slots',[])))
    encoded=initial+context+count(len(rows))+b''.join(rows)
    if len(encoded)>=MAX_INPUT: raise ValueError('host input limit: 16 MiB')
    return encoded

def integer(limbs): return sum(n<<(32*i) for i,n in enumerate(limbs))
def hexword(w): return '0x'+integer(w).to_bytes(32,'big').hex()
def hexaddr(w): return '0x'+integer(w).to_bytes(32,'big')[-20:].hex()
def hexbytes(xs): return '0x'+bytes(xs).hex()
def signed(w):
    n=integer(w); return n-(1<<256) if n>>(255) else n

def normalize(raw):
    if 'error' in raw: return raw
    out={k:v for k,v in raw.items() if k not in ('accounts','logs','stack','memory','output','refund','state_used','selfdestructs')}
    out.update(stack=[hexword(x) for x in raw['stack']],memory=hexbytes(raw['memory']),output=hexbytes(raw['output']),refund=signed(raw['refund']),state_used=signed(raw['state_used']),selfdestructs=[hexaddr(x) for x in raw['selfdestructs']])
    out['logs']=[dict(address=hexaddr(x['address']),topics=[hexword(t) for t in x['topics']],data=hexbytes(x['data'])) for x in raw['logs']]
    out['accounts']={hexaddr(a['address']):dict(balance=hexword(a['balance']),nonce=integer(a['nonce']),code=hexbytes(a['code']),storage={hexword(k):hexword(v) for k,v in a['storage']},transient={hexword(k):hexword(v) for k,v in a['transient']},exists=a['exists'],created=a['created'],warm=a['warm'],warm_slots=[hexword(x) for x in a['warm_slots']]) for a in raw['accounts']}
    return out

def build(backend='native'):
    target=ROOT/('evm-native' if backend=='native' else 'evm-full.js')
    subprocess.run([str(BEND),str(ROOT/'full/main.bend'),'-o',str(target)],check=True,cwd=ROOT,env=dict(os.environ,BEND_NO_TELEMETRY='1'))
    if backend == 'js': target.write_text(re.sub(r'\$[\w$-]+',lambda m:m[0].replace('-','_'),target.read_text()))
    return target

def execute(case,backend='native',timeout=120):
    encoded=encode(case)
    target=ROOT/('evm-native' if backend=='native' else 'evm-full.js')
    if not target.exists(): build(backend)
    with tempfile.NamedTemporaryFile(prefix='evm-input-',dir=ROOT) as f:
        f.write(encoded);f.flush()
        cmd=[str(target)] if backend=='native' else [str(BUN),str(target)]
        env=dict(os.environ,BEND_EVM_INPUT=f.name,BEND_NO_TELEMETRY='1',BEND_EVM_PRECOMPILE_HOST=str(ROOT/'precompile-host/target/debug/bend-evm-precompile-host'))
        result=subprocess.run(cmd,capture_output=True,text=True,env=env,timeout=timeout,cwd=ROOT)
        if result.returncode: raise RuntimeError(f'Bend process exited {result.returncode}: {result.stderr[-4000:]}')
        return normalize(json.loads(result.stdout))

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('input',nargs='?',help='JSON case file; stdin when omitted')
    ap.add_argument('--backend',choices=['native','js'],default='native')
    ap.add_argument('--build',action='store_true')
    ap.add_argument('--timeout',type=float,default=120)
    args=ap.parse_args()
    if args.build:
        build(args.backend)
        if not args.input:return
    case=json.loads(pathlib.Path(args.input).read_text() if args.input else sys.stdin.read())
    print(json.dumps(execute(case,args.backend,args.timeout),indent=2))

if __name__=='__main__':main()
