import evm,json
from pathlib import Path
A='0x0000000000000000000000000000000000002000'
def push(n):
 b=n.to_bytes(max(1,(n.bit_length()+7)//8),'big');return bytes([95+len(b)])+b
cases=[('store','602a60005500',{}),('store-reset','602a600055600060005500',{}),('store-revert','602a60005560006000fd',{}),('store-fault','602a600055fe',{})]
for end in ['00','60006000fd','fe']:
 child='602a600055'+end
 code=push(0)*5+push(0x3000)+push(300000)+bytes([0xf1,0x50])+bytes.fromhex('602b60015500')
 cases.append(('child-'+end,code.hex(),{'0x3000':{'code':child}}))
failures=[];count=0
for backend in ['native','js']:
 for name,code,accounts in cases:
  baseline=evm.execute(dict(code=code,address=A,accounts=accounts,gas=1000000),backend)
  for reservoir in [1,50000,97920,300000]:
   count+=1;r=evm.execute(dict(code=code,address=A,accounts=accounts,gas=1000000,reservoir=reservoir),backend)
   keys=['status','output','refund','state_used','logs','accounts']
   errors=[k for k in keys if r[k]!=baseline[k]]
   if r['status']!='halt' and 1000000+reservoir-r['gas']-r['reservoir']!=1000000-baseline['gas']-baseline['reservoir']:errors.append('total-gas')
   if r['status'] in ['revert','halt'] and (r['state_used'] or r['state_spilled'] or r['reservoir']!=reservoir):errors.append('rollback-state-gas')
   if errors:failures.append(dict(name=name,backend=backend,reservoir=reservoir,errors=errors))
Path('frame-invariant-results.json').write_text(json.dumps(dict(cases=count,failures=failures),indent=2));print(count,failures)
raise SystemExit(bool(failures))
