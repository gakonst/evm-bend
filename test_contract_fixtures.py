"""Actual contract and crypto fixtures from pinned evm2, with Amsterdam oracle."""
import json,subprocess,evm,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent
cases=[]
for name in ['counter','uniswap_v2_pair','fibonacci-calldata','precompile-ecrecover','precompile-kzg-point-evaluation','precompile-p256verify','precompile-bn254','precompile-bls12-381']:
 x=next(iter(json.loads((ROOT.parent/'evm2-reference/data'/f'{name}.json').read_text()).values()));cases.append((name,x,x['transaction']['data'][0]))
x=next(iter(json.loads((ROOT.parent/'evm2-reference/data/erc20_transfer.json').read_text()).values()))
for name,data in [('erc20-approve','0x095ea7b3'+(0x1234).to_bytes(32,'big').hex()+(42).to_bytes(32,'big').hex()),('erc20-balance','0x70a08231'+(0x1234).to_bytes(32,'big').hex()),('erc20-transfer-revert','0xa9059cbb'+(0x1234).to_bytes(32,'big').hex()+(42).to_bytes(32,'big').hex())]:cases.append((name,x,data))
errors=[];checks=0
for name,x,data in cases:
 tx=x['transaction'];a=tx['to'];caller=tx['sender'];accounts={k:dict(v,nonce=int(v['nonce'],16)) for k,v in x['pre'].items()};code=accounts.get(a,{}).get('code','0x');raw=evm.data(data);gas=2000000
 case=dict(code=code,input=data,address=a,caller=caller,gas=gas,accounts=accounts,context=dict(number=1,timestamp=1,gaslimit=30000000,blobbasefee=1))
 ac=[dict(address=k,balance=v['balance'],nonce=v['nonce'],code=list(evm.data(v['code'])),storage=list(v['storage'].items())) for k,v in accounts.items()]
 intrinsic=15000+sum(4 if b==0 else 16 for b in raw)
 r=json.loads(subprocess.check_output(['revm-adapter/target/debug/revm-adapter'],input=json.dumps(dict(code=list(evm.data(code)),calldata=list(raw),target=a,caller=caller,gas=gas+intrinsic,accounts=ac,block=dict(number=1,timestamp=1))).encode()))
 for backend in ['native','js']:
  checks+=1;t=time.monotonic();b=evm.execute(case,backend)
  got=(b['status'],b['output'],gas-b['gas'],max(0,b['state_used']));want=({'halted':'success','revert':'revert','exception':'halt'}[r['status']],'0x'+bytes(r['output']).hex(),r['total_gas_spent']-intrinsic,r['state_gas_spent'])
  if got!=want:errors.append(dict(name=name,backend=backend,got=got,want=want))
  for slot in r['state']['storage']:
   value=b['accounts'][slot['address']]['storage'].get('0x'+int(slot['key'],16).to_bytes(32,'big').hex(),'0x0')
   if int(value,16)!=int(slot['value'],16):errors.append(dict(name=name,backend=backend,slot=slot,got=value))
  if len(b['logs'])!=len(r['logs']):errors.append(dict(name=name,backend=backend,logs='count'))
  print(name,backend,b['status'],round(time.monotonic()-t,3),flush=True)
 if name=='erc20-approve':(ROOT/'examples/erc20-approve.json').write_text(json.dumps(case,indent=2))
(ROOT/'contract-fixture-results.json').write_text(json.dumps(dict(cases=checks,failures=errors),indent=2));print('RESULT',checks,errors,flush=True)
raise SystemExit(bool(errors))
