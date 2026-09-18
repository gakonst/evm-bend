import evm,time,json,statistics
from pathlib import Path
rows=[]
for n in [10,100,1000]:
 # PUSH2 n; loop: DUP1 ISZERO PUSH1 end JUMPI PUSH1 1 SWAP1 SUB PUSH1 loop JUMP; end: POP STOP.
 code='61'+n.to_bytes(2,'big').hex()+'5b8015601157600190036003565b5000'
 # end JUMPDEST is offset16, fixed below.
 code=code.replace('601157','601057')
 for backend in ['native','js']:
  times=[]
  for _ in range(3):
   t=time.perf_counter();r=evm.execute({'code':code,'gas':1000000},backend);times.append(time.perf_counter()-t)
   assert r['status']=='success',r
  rows.append(dict(backend=backend,iterations=n,gas_spent=1000000-r['gas'],median_seconds=statistics.median(times)))
Path('benchmark-results.json').write_text(json.dumps(dict(scope='End-to-end JSON encode, process startup, Bend execution, state decode; not isolated interpreter throughput',rows=rows),indent=2));print(rows)
