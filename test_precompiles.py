import subprocess,json,evm,time
from pathlib import Path
A='0x0000000000000000000000000000000000002000'
def push(n):
 b=n.to_bytes(max(1,(n.bit_length()+7)//8),'big');return bytes([95+len(b)])+b
cases=[]
for a,size in [(1,128),(2,137),(3,73),(4,257),(5,96),(6,128),(7,96),(8,192),(9,213),(10,192),(11,256),(12,160),(13,512),(14,288),(15,384),(16,64),(17,128),(256,160)]:
 cases.extend([(a,bytes(size)),(a,b'abc')])
# MODEXP 2**5 mod 13 = 6, each integer length1.
cases.append((5,(1).to_bytes(32,'big')*3+bytes([2,5,13])))
results=[]
for backend in ['js','native']:
 for a,data in cases:
  code=push(len(data))+push(0)+push(0)+bytes([0x37])+push(512)+push(0)+push(len(data))+push(0)+push(a)+push(1000000)+bytes([0xfa,0x50,0x3d,0x60,0,0xf3])
  intrinsic=15000+sum(4 if v==0 else 16 for v in data)
  r=json.loads(subprocess.check_output(['revm-adapter/target/debug/revm-adapter'],input=json.dumps(dict(code=list(code),calldata=list(data),gas=2000000+intrinsic)).encode()))
  b=evm.execute(dict(code=list(code),input=list(data),address=A,gas=2000000),backend)
  got=(b['status'],b['output'],2000000-b['gas']);want=('success','0x'+bytes(r['output']).hex(),r['total_gas_spent']-intrinsic)
  if got!=want:results.append(dict(backend=backend,address=a,size=len(data),got=got,want=want))
 print(backend,len(cases),'cases',len(results),'failures',flush=True)
Path('precompile-results.json').write_text(json.dumps(dict(cases=len(cases)*2,failures=results),indent=2))
raise SystemExit(bool(results))
