#!/usr/bin/env python3
"""Serialize fixture inputs for Bend transactions; never execute EVM in Python."""
import argparse,json,os,pathlib,subprocess,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import evm
ORACLE=ROOT/'revm-adapter/target/debug/revm-adapter'
class Unsupported(Exception):pass

def crypto(request):
 p=subprocess.run([str(ORACLE)],input=json.dumps(request),capture_output=True,text=True,check=True)
 r=json.loads(p.stdout)
 if r.get('status')=='error':raise RuntimeError(r.get('reason'))
 return r

def optional(x):return b'\0' if x is None else b'\1'+evm.word(x)

def encode_context(env):
 fields=[0,0,env.get('currentCoinbase',0),env.get('currentTimestamp',0),env.get('currentNumber',0),env.get('currentRandom',0),env.get('currentGasLimit',0),env.get('currentChainID',env.get('currentChainId',1)),env.get('currentBaseFee',0),0,env.get('slotNumber',0)]
 return b''.join(evm.word(x) for x in fields)+evm.words([])+evm.slots(env.get('blockHashes',{}))+evm.word(env.get('currentExcessBlobGas',0))

def encode_accounts(pre):
 rows=[]
 for address,acc in sorted(pre.items()):
  storage=acc.get('storage',{})
  rows.append(evm.word(address)+evm.word(acc.get('balance',0))+evm.word(acc.get('nonce',0))+evm.blob(acc.get('code','0x'))+evm.slots(storage)+evm.slots(storage)+evm.slots({})+bytes([0,1,0])+evm.words([]))
 return evm.count(len(rows))+b''.join(rows)

def encode_transaction(t):
 if not t.get('sender'):raise Unsupported('sender_signature_recovery_not_yet_integrated')
 gas=evm.number(t['gasLimit'])
 if gas<0 or gas>=1<<48:raise Unsupported('gas_exceeds_current_Bend_Nat_representation')
 if t.get('type') is not None:kind=evm.number(t['type'])
 else:kind=4 if 'authorizationList' in t else 3 if 'maxFeePerBlobGas' in t or 'blobVersionedHashes' in t else 2 if 'maxFeePerGas' in t else 1 if t.get('accessList') is not None else 0
 if not 0<=kind<=255:raise Unsupported('transaction_type_outside_wire_byte')
 fee=t.get('gasPrice',0) if kind<2 else t.get('maxFeePerGas',0)
 tip=t.get('gasPrice',0) if kind<2 else t.get('maxPriorityFeePerGas',0)
 accesses=t.get('accessList') or []
 access=evm.count(len(accesses))+b''.join(evm.word(a['address'])+evm.words(a.get('storageKeys',[])) for a in accesses)
 authorizations=t.get('authorizationList') or []
 recovered=crypto({'mode':'recover_authorizations','authorizations':authorizations})['authorities'] if authorizations else []
 auth=[]
 for a,authority in zip(authorizations,recovered):
  parity=evm.number(a.get('yParity',a.get('v',0)))
  # Values outside this representation remain explicit host limitations.
  if not 0<=parity<1<<32:raise Unsupported('authorization_parity_exceeds_wire_u32')
  auth.append(evm.word(a['chainId'])+evm.word(a['address'])+evm.word(a['nonce'])+evm.count(parity)+evm.word(a['r'])+evm.word(a['s'])+optional(authority))
 chain=t.get('chainId')
 if chain is None and kind>0:chain=1
 to=t.get('to') or None
 return bytes([kind])+evm.word(t['sender'])+evm.word(t.get('nonce',0))+gas.to_bytes(6,'big')+optional(to)+evm.word(t.get('value',0))+evm.blob(t.get('data','0x'))+optional(chain)+evm.word(fee)+evm.word(tip)+evm.word(t.get('maxFeePerBlobGas',0))+evm.words(t.get('blobVersionedHashes',[]))+access+evm.count(len(auth))+b''.join(auth)

def execute(request,backend='native',timeout=120):
 if request.get('format')!='state_test':raise Unsupported('Bend_entrypoint_for_'+str(request.get('format'))+'_not_yet_integrated')
 if request.get('fork')!='Amsterdam':raise Unsupported('fork_not_Amsterdam')
 if 'txbytes' in request:raise Unsupported('signed_envelope_codec_not_yet_integrated')
 env=request['env']
 if 'currentBeaconRoot' in env or 'previousHash' in env:raise Unsupported('pre_transaction_system_calls_not_yet_integrated')
 binary=encode_context(env)+encode_accounts(request['pre'])+encode_transaction(request['transaction'])
 if len(binary)>=16*1024*1024:raise Unsupported('fixture_exceeds_current_16MiB_wire_limit')
 target=ROOT/('evm-transaction-native' if backend=='native' else 'evm-transaction.js')
 if not target.exists():raise Unsupported('transaction_executable_not_built')
 with tempfile.NamedTemporaryFile(prefix='evm-tx-',dir=ROOT) as f:
  f.write(binary);f.flush()
  cmd=[str(target)] if backend=='native' else [str(evm.BUN),str(target)]
  env=dict(os.environ,BEND_EVM_INPUT=f.name,BEND_NO_TELEMETRY='1',BEND_EVM_PRECOMPILE_HOST=str(ROOT/'precompile-host/target/debug/bend-evm-precompile-host'))
  p=subprocess.run(cmd,capture_output=True,text=True,timeout=timeout,env=env,cwd=ROOT)
  if p.returncode:raise RuntimeError(f'Bend exited {p.returncode}: {p.stderr[-1000:]}')
  raw=json.loads(p.stdout)
 if raw['status']=='host_error':return raw
 if raw['status']=='rejected':
  # Preserve precise validation reason; canonical EEST mapping is integrated
  # alongside transaction validation, never accept an arbitrary rejection.
  return dict(status='unsupported',reason='EEST_rejection_mapping_pending',bend_reason=raw['reason'])
 if raw['status']!='executed':raise ValueError('unknown Bend transaction status')
 frame=evm.normalize(raw['frame']);alloc={}
 for a,x in frame['accounts'].items():
  if x['exists']:alloc[a]=dict(nonce=x['nonce'],balance=x['balance'],code=x['code'],storage={k:v for k,v in x['storage'].items() if evm.number(v)})
 roots=crypto(dict(mode='commitment',alloc=alloc,logs=frame['logs']))
 return dict(status='executed',exception=None,state_root=roots['state_root'],logs_hash=roots['logs_hash'],post_state=alloc,output=frame['output'],logs=frame['logs'],gas=raw['transaction_gas'],frame_status=frame['status'])

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--backend',choices=['native','js'],default='native');ap.add_argument('--timeout',type=float,default=120);a=ap.parse_args()
 try:result=execute(json.load(sys.stdin),a.backend,a.timeout)
 except Unsupported as e:result=dict(status='unsupported',reason=str(e))
 except Exception as e:result=dict(status='host_error',reason=type(e).__name__,detail=str(e))
 print(json.dumps(result,separators=(',',':')))
if __name__=='__main__':main()
