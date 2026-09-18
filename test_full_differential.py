#!/usr/bin/env python3
"""Prepared Bend frame vs revm 43 Amsterdam transaction execution."""
import json,random,subprocess,os,time
from pathlib import Path
import evm
ROOT=Path(__file__).resolve().parent
A='0x0000000000000000000000000000000000002000';CALLER='0x0000000000000000000000000000000000001000'
RNG=random.Random(8037);MASK=(1<<256)-1
BACKEND=os.environ.get('EVM_BACKEND','js')
def push(x):
 b=x.to_bytes(max(1,(x.bit_length()+7)//8),'big');return bytes([95+len(b)])+b
def oracle(case):
 p=subprocess.run([str(ROOT/'revm-adapter/target/debug/revm-adapter')],input=json.dumps(case),capture_output=True,text=True,check=True);return json.loads(p.stdout)
def compare(name,code,accounts=None,calldata=b'',gas=1000000,context=None):
 accounts=dict(accounts or {});ctx={'number':1000,'timestamp':1234,'gaslimit':30000000,'chainid':1,'prevrandao':0,'basefee':0,'blobbasefee':1,'coinbase':0};ctx.update(context or {})
 ac=[dict(address='0x'+int(k,16).to_bytes(20,'big').hex(),balance=hex(evm.number(v.get('balance',0))),nonce=v.get('nonce',0),code=list(evm.data(v.get('code',''))),storage=list(v.get('storage',{}).items())) for k,v in accounts.items()]
 base={'caller':CALLER,'target':A,'calldata':list(calldata),'accounts':ac,'block':{'number':ctx['number'],'timestamp':ctx['timestamp'],'gas_limit':ctx['gaslimit'],'basefee':0,'beneficiary':'0x'+'00'*20,'prevrandao':'0x'+'00'*32}}
 intrinsic=15000+sum(4 if b==0 else 16 for b in calldata)
 r=oracle(dict(base,code=list(code),gas=gas+intrinsic))
 b=evm.execute(dict(code=list(code),address=A,caller=CALLER,input=list(calldata),gas=gas,context=ctx,accounts=accounts),BACKEND)
 expected={'halted':'success','revert':'revert','exception':'halt'}.get(r['status'],r['status'])
 errors=[]
 for field,got,want in [('status',b.get('status'),expected),('output',b.get('output'),'0x'+bytes(r['output']).hex()),('gas spent',gas-b.get('gas',gas),r.get('total_gas_spent',0)-intrinsic),('state gas',max(0,b.get('state_used',0)),r.get('state_gas_spent',0))]:
  if got!=want:errors.append((field,got,want))
 logs=[dict(address=x['address'],topics=[int(t,16) for t in x['topics']],data=bytes.fromhex(x['data'][2:])) for x in b.get('logs',[])]
 rlogs=[dict(address=x['address'],topics=[int(t,16) for t in x['topics']],data=bytes(x['data'])) for x in r['logs']]
 if logs!=rlogs:errors.append(('logs',repr(logs),repr(rlogs)))
 for slot in r['state']['storage']:
  got=b.get('accounts',{}).get(slot['address'],{}).get('storage',{}).get('0x'+int(slot['key'],16).to_bytes(32,'big').hex(),'0x0')
  if int(got,16)!=int(slot['value'],16):errors.append(('storage',got,slot))
 if errors: return dict(name=name,code=code.hex(),errors=errors,bend=b,reference=r)
 return None
cases=[]
def add(name,code,**kwargs):cases.append((name,bytes.fromhex(code) if isinstance(code,str) else code,kwargs))
ret=bytes.fromhex('60005260206000f3')
for op,n in [(1,2),(2,2),(3,2),(4,2),(5,2),(6,2),(7,2),(8,3),(9,3),(10,2),(11,2),(16,2),(17,2),(18,2),(19,2),(20,2),(21,1),(22,2),(23,2),(24,2),(25,1),(26,2),(27,2),(28,2),(29,2),(30,1)]:
 for j in range(5):
  args=[RNG.getrandbits(256) for _ in range(n)]
  if j==0:args=[0]*n
  if op==10:args[0]=j*19 # exponent is next stack item
  if op in (11,26,27,28,29):args[-1]=[0,1,31,255,256][j]
  add(f'op{op:02x}-{j}',b''.join(push(x) for x in args)+bytes([op])+ret)
for op in [0x30,0x32,0x33,0x34,0x36,0x38,0x3a,0x3d,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x4a,0x4b,0x58,0x59,0x5a,0x5f]:add(f'env{op:02x}',bytes([op])+ret)
for op in [0x35,0x40,0x49]:add(f'env{op:02x}',push(0)+bytes([op])+ret)
for name,code in [('sstore','602a60005560005460005260206000f3'),('sstore-reset','602a600055600060005500'),('transient','602a60005d60005c60005260206000f3'),('revert-storage','602a60005560006000fd'),('mcopy','602a6000526020600060205e60206020f3'),('keccak','602a600052602060002060005260206000f3'),('jump','6003565b602a60005260206000f3'),('badjump','60045600'),('invalid','fe'),('underflow','01'),('log','602a60005260206000a000'),('returnbounds','6001600060003e'),('dup','602a8060005260206000f3'),('swap','602a60019060005260206000f3')]:add(name,code)
for op in [0x31,0x3b,0x3f]:add(f'account{op:02x}',push(0x3000)+bytes([op])+ret,accounts={'0x3000':{'balance':123,'code':'602a00'}})
for kind in [0xf1,0xf2,0xf4,0xfa]:
 for end in ['f3','fd','fe']:
  child='602a60005260206000'+end
  code=push(32)+push(0)+push(0)+push(0)+(push(0) if kind in (0xf1,0xf2) else b'')+push(0x3000)+push(100000)+bytes([kind])+bytes.fromhex('5060206000f3')
  add(f'call{kind:02x}-{end}',code,accounts={'0x3000':{'code':child}})
for a in [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,256]:
 code=push(64)+push(0)+push(0)+push(0)+push(a)+push(100000)+bytes([0xfa])+bytes.fromhex('50603d5060206000f3')
 add(f'precompile{a}',code)
for op in [0xe6,0xe7,0xe8]:add(f'new-stack{op}',b''.join(push(x) for x in range(20))+bytes([op,0])+ret)
for name,init in [('create-empty','00'),('create-return','600160005360016000f3'),('create-revert','60006000fd')]:
 raw=bytes.fromhex(init);code=push(int.from_bytes(raw,'big'))+push(0)+bytes([0x52])+push(len(raw))+push(32-len(raw))+push(0)+bytes([0xf0])+ret;add(name,code)
# Every byte on an empty stack exercises dispatch, invalid bytes and underflow.
for op in range(256):add(f'empty-{op:02x}',bytes([op]))
for n in range(1,33):
 add(f'push{n}-full',bytes([95+n])+bytes(range(n))+ret)
 add(f'push{n}-truncated',bytes([95+n])+bytes(range(n//2)))
for op in range(0x80,0xa0):add(f'stack{op:02x}',b''.join(push(i+1) for i in range(18))+bytes([op])+ret)
for imm in [0,1,80,81,82,90,91,127,128,143,144,145,255]:
 for op in [0xe6,0xe7,0xe8]:add(f'imm{op:02x}-{imm}',b''.join(push(i+1) for i in range(40))+bytes([op,imm])+ret)
for name,code in [('zero-huge-memory',push(0)+push(MASK)+bytes([0xf3])),('huge-memory',push(1)+push(MASK)+bytes([0xf3])),('zero-huge-keccak',push(0)+push(MASK)+bytes([0x20])+ret),('huge-copy',push(1)+push(0)+push(MASK)+bytes([0x37])),('jump-into-push',bytes.fromhex('600456605b00')),('false-huge-jumpi',push(0)+push(MASK)+bytes([0x57,0]))]:add(name,code)
for end in ['00','60006000fd','fe']:
 child='602a60005560206000a0'+end
 code=push(0)+push(0)+push(0)+push(0)+push(0)+push(0x3000)+push(300000)+bytes([0xf1,0])
 add('journal-'+end,code,accounts={'0x3000':{'code':child}})
for value in [0,1,1001]:
 code=push(0)+push(0)+push(0)+push(0)+push(value)+push(0x3000)+push(100000)+bytes([0xf1])+ret
 add('transfer-'+str(value),code,accounts={A:{'balance':1000}})
for target in [0x3000,0x2000]:add('selfdestruct-'+hex(target),push(target)+bytes([0xff]),accounts={A:{'balance':1000}})
for val in [0,1,42]:
 add('sstore-existing-'+str(val),push(val)+push(0)+bytes([0x55,0]),accounts={A:{'storage':{'0x0':'0x2a'}}})
for target in [0x4000,4]:
 code=push(32)+push(0)+push(0)+push(0)+push(0)+push(0x3000)+push(300000)+bytes([0xf1,0x50])+bytes.fromhex('60206000f3')
 add('delegation-'+hex(target),code,accounts={'0x3000':{'code':'ef0100'+target.to_bytes(20,'big').hex()},'0x4000':{'code':'602a60005260206000f3'}})
for kind in [0xf1,0xf4,0xfa]:
 child='602a60005560005460005260206000f3'
 code=push(32)+push(0)+push(0)+push(0)+(push(0) if kind==0xf1 else b'')+push(0x3000)+push(300000)+bytes([kind,0x50])+bytes.fromhex('60206000f3')
 add('storage-context-'+hex(kind),code,accounts={'0x3000':{'code':child}})
for salt in [0,1,MASK]:
 init=bytes.fromhex('600160005360016000f3')
 code=push(int.from_bytes(init,'big'))+push(0)+bytes([0x52])+push(salt)+push(len(init))+push(32-len(init))+push(0)+bytes([0xf5])+ret
 add('create2-'+str(salt),code)
filter_text=os.environ.get('EVM_CASE_FILTER','')
if filter_text: cases=[c for c in cases if any(c[0].startswith(x) for x in filter_text.split(','))]
results=[];start=time.time()
for i,(name,code,kwargs) in enumerate(cases):
 try:r=compare(name,code,**kwargs)
 except Exception as e:r=dict(name=name,error=str(e))
 if r:results.append(r);print('FAIL',name,r.get('errors',r.get('error')),flush=True)
 elif i%25==0:print('PASS',i+1,'/',len(cases),flush=True)
summary=dict(backend=BACKEND,cases=len(cases),failures=results,seconds=time.time()-start)
(ROOT/f'full-differential-{BACKEND}{"-extra" if filter_text else ""}.json').write_text(json.dumps(summary,indent=2));print('RESULT',len(cases),len(results),flush=True)
raise SystemExit(bool(results))
