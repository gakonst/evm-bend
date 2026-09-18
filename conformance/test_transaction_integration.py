"""Decoded-envelope integration differentials, separate from signed conformance."""
import copy,json,os,sys,time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from bend_adapter import execute,crypto
A='0x0000000000000000000000000000000000002000';S='0x0000000000000000000000000000000000001000'
def request(code='00',**tx):
 base=dict(sender=S,to=A,gasLimit=1000000,nonce=0,gasPrice=10,value=0,data='0x');base.update(tx)
 return dict(format='state_test',fork='Amsterdam',env=dict(currentCoinbase='0x0000000000000000000000000000000000003000',currentGasLimit=300000000,currentBaseFee=7,currentNumber=1,currentTimestamp=1,currentRandom='0x'+'00'*32,currentExcessBlobGas=0,slotNumber=1),pre={S:dict(nonce=0,balance=hex(10**30),code='0x',storage={}),A:dict(nonce=1,balance=0,code='0x'+code,storage={})},transaction=base)
cases=[]
for name,code in [('stop','00'),('return','602a60005260206000f3'),('revert','602a60005260206000fd'),('fault','fe'),('store','602a60005500'),('reset','602a600055600060005500'),('transient','602a60005d00')]:cases.append((name,request(code)))
cases+=[('value',request(value=42)),('large-reservoir',request('602a60005500',gasLimit=120000000)),('floor',request(data='0x'+'ff'*100)),('access',request(type=1,chainId=1,accessList=[dict(address=A,storageKeys=['0x'+'00'*32])])),('fee-market',request(type=2,chainId=1,maxFeePerGas=15,maxPriorityFeePerGas=2)),('blob',request(type=3,chainId=1,maxFeePerGas=15,maxPriorityFeePerGas=2,maxFeePerBlobGas=10,blobVersionedHashes=['0x01'+'00'*31]))]
for init in ['00','600160005360016000f3','60006000fd','fe']:
 cases.append(('create-'+init,request(to='',data='0x'+init)))
for excess in [0,11684671,23369342,100000000,1000000000]:
 r=request('4a60005260206000f3');r['env']['currentExcessBlobGas']=excess;cases.append(('blobfee-'+str(excess),r))
backend=os.environ.get('EVM_BACKEND','js');failures=[]
for name,r in cases:
 try:
  reference=crypto(r);actual=execute(r,backend)
  errors=[]
  for field in ['state_root','logs_hash','output','exception']:
   if actual.get(field)!=reference.get(field):errors.append(dict(field=field,actual=actual.get(field),expected=reference.get(field)))
  if actual.get('status')!='executed':errors.append(dict(actual=actual,expected='executed'))
  if actual.get('gas',{}).get('used')!=reference.get('gas_used'):errors.append(dict(field='gas',actual=actual.get('gas'),reference=reference.get('gas_used')))
  if errors:failures.append(dict(name=name,errors=errors))
  print(name,'FAIL' if errors else 'PASS',flush=True)
 except Exception as e:failures.append(dict(name=name,error=str(e)));print(name,'ERROR',str(e),flush=True)
Path(f'conformance/transaction-integration-{backend}.json').write_text(json.dumps(dict(cases=len(cases),failures=failures),indent=2));print('RESULT',len(cases),len(failures),flush=True)
raise SystemExit(bool(failures))
