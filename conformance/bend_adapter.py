#!/usr/bin/env python3
"""Serialize fixture inputs for Bend transactions; never execute EVM in Python."""
import argparse,json,os,pathlib,subprocess,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import evm
from rejection_mapping import rejection_exception,rejection_aliases
ORACLE=ROOT/'revm-adapter/target/debug/revm-adapter'
ENVELOPE=ROOT/'envelope-host/target/debug/evm-bend-envelope'
class Unsupported(Exception):pass

# Only the pinned envelope decoder's structural/cryptographic vocabulary may
# produce a transaction rejection here. Semantic Bend errors are mapped later.
WIRE_CRYPTO_EXCEPTIONS=frozenset('TransactionException.'+name for name in (
 'TYPE_NOT_SUPPORTED','ADDRESS_TOO_SHORT','ADDRESS_TOO_LONG',
 'NONCE_OVERFLOW','GASLIMIT_OVERFLOW','VALUE_OVERFLOW','INVALID_CHAINID',
 'INVALID_SIGNATURE_VRS','EC_RECOVERY_FAIL',
 'RLP_INVALID_SIGNATURE_R','RLP_INVALID_SIGNATURE_S',
 'RLP_LEADING_ZEROS_GASLIMIT','RLP_LEADING_ZEROS_GASPRICE',
 'RLP_LEADING_ZEROS_VALUE','RLP_LEADING_ZEROS_NONCE','RLP_LEADING_ZEROS_R',
 'RLP_LEADING_ZEROS_S','RLP_LEADING_ZEROS_V','RLP_LEADING_ZEROS_BASEFEE',
 'RLP_LEADING_ZEROS_PRIORITY_FEE','RLP_LEADING_ZEROS_DATA_SIZE',
 'RLP_LEADING_ZEROS_NONCE_SIZE','RLP_TOO_FEW_ELEMENTS','RLP_TOO_MANY_ELEMENTS',
 'RLP_ERROR_EOF','RLP_ERROR_SIZE','RLP_ERROR_SIZE_LEADING_ZEROS',
 'RLP_INVALID_DATA','RLP_INVALID_GASLIMIT','RLP_INVALID_NONCE','RLP_INVALID_TO',
 'RLP_INVALID_ACCESS_LIST_ADDRESS_TOO_LONG','RLP_INVALID_ACCESS_LIST_ADDRESS_TOO_SHORT',
 'RLP_INVALID_ACCESS_LIST_STORAGE_TOO_LONG','RLP_INVALID_ACCESS_LIST_STORAGE_TOO_SHORT',
 'RLP_INVALID_HEADER','RLP_INVALID_VALUE',
 'TYPE_4_INVALID_AUTHORITY_SIGNATURE','TYPE_4_INVALID_AUTHORITY_SIGNATURE_S_TOO_HIGH',
 'TYPE_4_INVALID_AUTHORIZATION_FORMAT',
))

def signed_authorities(transaction):
 # Missing recovery data is a broken host contract, not a failed signature.
 # Only an explicit null returned by crypto recovery means unrecoverable.
 recovered=[]
 authorizations=transaction['authorizationList']
 if not isinstance(authorizations,list):raise ValueError('envelope authorizationList must be an array')
 for authorization in authorizations:
  authority=authorization['authority']
  recovery_error=authorization['recoveryError']
  if (authority is None)!=(recovery_error is not None):
   raise ValueError('inconsistent envelope authority recovery result')
  if authority is None:
   if not isinstance(recovery_error,dict) or recovery_error.get('category')!='crypto' or recovery_error.get('exception') not in ('TransactionException.TYPE_4_INVALID_AUTHORITY_SIGNATURE','TransactionException.TYPE_4_INVALID_AUTHORITY_SIGNATURE_S_TOO_HIGH'):
    raise ValueError('invalid envelope authority crypto error')
  else:evm.address(authority)
  recovered.append(authority)
 return recovered


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

def encode_transaction(t, verified_authorities=None):
 if not t.get('sender'):raise Unsupported('sender_signature_recovery_not_yet_integrated')
 gas=evm.number(t['gasLimit'])
 if gas<0 or gas>=1<<256:raise Unsupported('gas_exceeds_Word_representation')
 if t.get('type') is not None:kind=evm.number(t['type'])
 else:kind=4 if 'authorizationList' in t else 3 if 'maxFeePerBlobGas' in t or 'blobVersionedHashes' in t else 2 if 'maxFeePerGas' in t else 1 if t.get('accessList') is not None else 0
 if not 0<=kind<=255:raise Unsupported('transaction_type_outside_wire_byte')
 fee=t.get('gasPrice',0) if kind<2 else t.get('maxFeePerGas',0)
 tip=t.get('gasPrice',0) if kind<2 else t.get('maxPriorityFeePerGas',0)
 accesses=t.get('accessList') or []
 access=evm.count(len(accesses))+b''.join(evm.word(a['address'])+evm.words(a.get('storageKeys',[])) for a in accesses)
 authorizations=t.get('authorizationList') or []
 recovered=verified_authorities if verified_authorities is not None else (crypto({'mode':'recover_authorizations','authorizations':authorizations})['authorities'] if authorizations else [])
 if len(recovered)!=len(authorizations):raise ValueError('authorization recovery count mismatch')
 auth=[]
 for a,authority in zip(authorizations,recovered):
  parity=evm.number(a.get('yParity',a.get('v',0)))
  # Values outside this representation remain explicit host limitations.
  if not 0<=parity<1<<32:raise Unsupported('authorization_parity_exceeds_wire_u32')
  auth.append(evm.word(a['chainId'])+evm.word(a['address'])+evm.word(a['nonce'])+evm.count(parity)+evm.word(a['r'])+evm.word(a['s'])+optional(authority))
 chain=t.get('chainId')
 if chain is None and kind>0:chain=1
 to=t.get('to') or None
 return bytes([kind])+evm.word(t['sender'])+evm.word(t.get('nonce',0))+evm.word(gas)+optional(to)+evm.word(t.get('value',0))+evm.blob(t.get('data','0x'))+optional(chain)+evm.word(fee)+evm.word(tip)+evm.word(t.get('maxFeePerBlobGas',0))+evm.words(t.get('blobVersionedHashes',[]))+access+evm.count(len(auth))+b''.join(auth)

def execute(request,backend='native',timeout=120):
 if request.get('format')!='state_test':raise Unsupported('Bend_entrypoint_for_'+str(request.get('format'))+'_not_yet_integrated')
 if request.get('fork')!='Amsterdam':raise Unsupported('fork_not_Amsterdam')
 authorities=None
 if 'txbytes' in request:
  if not ENVELOPE.exists():raise Unsupported('signed_envelope_executable_not_built')
  decoded=subprocess.run([str(ENVELOPE)],input=json.dumps(dict(mode='decode',txbytes=request['txbytes'])),capture_output=True,text=True,check=True,timeout=timeout)
  envelope=json.loads(decoded.stdout)
  if 'error' in envelope:
   error=envelope['error']
   if error.get('category') not in ('wire','crypto') or error.get('exception') not in WIRE_CRYPTO_EXCEPTIONS:raise ValueError('envelope host input error: '+str(error))
   roots=crypto(dict(mode='commitment',alloc=request['pre'],logs=[]))
   return dict(status='rejected',exception=error['exception'],state_root=roots['state_root'],logs_hash=roots['logs_hash'],post_state=request['pre'],output='0x',logs=[])
  transaction=envelope['decoded']
  authorities=signed_authorities(transaction)
 else:
  transaction=request['transaction']
 env=request['env']
 if 'currentBeaconRoot' in env or 'previousHash' in env:raise Unsupported('pre_transaction_system_calls_not_yet_integrated')
 binary=encode_context(env)+encode_accounts(request['pre'])+encode_transaction(transaction,authorities)
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
  try:exception=rejection_exception(raw['reason'])
  except KeyError:return dict(status='unsupported',reason='unmapped_Bend_rejection',bend_reason=raw['reason'])
  roots=crypto(dict(mode='commitment',alloc=request['pre'],logs=[]))
  return dict(status='rejected',exception=exception,exception_aliases=rejection_aliases(raw['reason']),bend_reason=raw['reason'],state_root=roots['state_root'],logs_hash=roots['logs_hash'],post_state=request['pre'],output='0x',logs=[])
 if raw['status']!='executed':raise ValueError('unknown Bend transaction status')
 frame=evm.normalize(raw['frame']);alloc={}
 for a,x in frame['accounts'].items():
  if x['exists']:alloc[a]=dict(nonce=x['nonce'],balance=x['balance'],code=x['code'],storage={k:v for k,v in x['storage'].items() if evm.number(v)})
 roots=crypto(dict(mode='commitment',alloc=alloc,logs=frame['logs']))
 return dict(status='executed',exception=None,state_root=roots['state_root'],logs_hash=roots['logs_hash'],post_state=alloc,output=frame['output'],logs=frame['logs'],gas={k:evm.integer(v) for k,v in raw['transaction_gas'].items()},frame_status=frame['status'])

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--backend',choices=['native','js'],default='native');ap.add_argument('--timeout',type=float,default=120);a=ap.parse_args()
 try:result=execute(json.load(sys.stdin),a.backend,a.timeout)
 except Unsupported as e:result=dict(status='unsupported',reason=str(e))
 except Exception as e:result=dict(status='host_error',reason=type(e).__name__,detail=str(e))
 print(json.dumps(result,separators=(',',':')))
if __name__=='__main__':main()
