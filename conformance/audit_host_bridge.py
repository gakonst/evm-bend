#!/usr/bin/env python3
"""Full-corpus bridge audit; no external EVM execution."""
import collections,hashlib,json,pathlib,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent;MAIN=HERE.parent
ROOT=HERE/'host-bridge-audit';ROOT.mkdir(exist_ok=True)
sys.path[:0]=[str(HERE),str(MAIN)]
import bend_adapter as A
import runner as R
N=A.evm.number
class Reader:
 def __init__(self,b):self.b=b;self.i=0
 def take(self,n):
  b=self.b[self.i:self.i+n];assert len(b)==n;self.i+=n;return b
 def n(self,size):return int.from_bytes(self.take(size),'big')
 def word(self):return self.n(32)
 def count(self):return self.n(4)
 def blob(self):return self.take(self.count())
 def words(self):return [self.word() for _ in range(self.count())]
 def slots(self):return [(self.word(),self.word()) for _ in range(self.count())]
 def optional(self):
  flag=self.n(1);assert flag in (0,1);return self.word() if flag else None
 def end(self):assert self.i==len(self.b),(self.i,len(self.b))
def read_tx(b):
 r=Reader(b);d=dict(type=r.n(1),sender=r.word(),nonce=r.word(),gasLimit=r.word(),to=r.optional(),value=r.word(),data=r.blob(),chainId=r.optional(),fee=r.word(),tip=r.word(),maxFeePerBlobGas=r.word(),blobVersionedHashes=r.words())
 d['accessList']=[dict(address=r.word(),storageKeys=r.words()) for _ in range(r.count())]
 d['authorizationList']=[dict(chainId=r.word(),address=r.word(),nonce=r.word(),yParity=r.count(),r=r.word(),s=r.word(),authority=r.optional()) for _ in range(r.count())];r.end();return d

def compare_tx(t,authorities):
 actual=read_tx(A.encode_transaction(t,authorities));kind=N(t['type'])
 expected={k:N(t[k]) for k in ('type','sender','nonce','gasLimit','value')}
 expected.update(to=N(t['to']) if t.get('to') else None,data=A.evm.data(t['data']),chainId=N(t['chainId']) if t.get('chainId') is not None else None,fee=N(t.get('gasPrice',0) if kind<2 else t.get('maxFeePerGas',0)),tip=N(t.get('gasPrice',0) if kind<2 else t.get('maxPriorityFeePerGas',0)),maxFeePerBlobGas=N(t.get('maxFeePerBlobGas',0)),blobVersionedHashes=[N(x) for x in t.get('blobVersionedHashes',[])],accessList=[dict(address=N(x['address']),storageKeys=[N(k) for k in x['storageKeys']]) for x in t.get('accessList',[])],authorizationList=[dict(chainId=N(x['chainId']),address=N(x['address']),nonce=N(x['nonce']),yParity=N(x.get('yParity',x['v'])),r=N(x['r']),s=N(x['s']),authority=N(a) if a is not None else None) for x,a in zip(t.get('authorizationList',[]),authorities)])
 assert actual==expected

def compare_pre(pre):
 r=Reader(A.encode_accounts(pre));actual={}
 for _ in range(r.count()):
  a=r.word();balance=r.word();nonce=r.word();code=r.blob();storage=r.slots();original=r.slots();transient=r.slots();flags=r.take(3);warm=r.words()
  assert flags==bytes([0,1,0]) and not transient and not warm and original==storage
  assert a not in actual;actual[a]=(balance,nonce,code,dict(storage))
 r.end();expected={N(a):(N(x['balance']),N(x['nonce']),A.evm.data(x['code']),{N(k):N(v) for k,v in x['storage'].items()}) for a,x in pre.items()};assert actual==expected

def compare_context(env):
 r=Reader(A.encode_context(env))
 fields=[r.word() for _ in range(11)]
 expected=[0,0,N(env.get('currentCoinbase',0)),N(env.get('currentTimestamp',0)),N(env.get('currentNumber',0)),N(env.get('currentRandom',0)),N(env.get('currentGasLimit',0)),N(env.get('currentChainID',env.get('currentChainId',1))),N(env.get('currentBaseFee',0)),0,N(env.get('slotNumber',0))]
 assert fields==expected
 assert r.words()==[]
 assert r.slots()==[(N(k),N(v)) for k,v in env.get('blockHashes',{}).items()]
 assert r.word()==N(env.get('currentExcessBlobGas',0));r.end()

def decode_cache(raws):
 fingerprint=hashlib.sha256(A.ENVELOPE.read_bytes()).hexdigest();cache=ROOT/'decoded-cache.jsonl';meta=ROOT/'decoded-cache-meta.json'
 key=dict(binary=fingerprint,input=hashlib.sha256('\n'.join(raws).encode()).hexdigest())
 if not cache.exists() or not meta.exists() or json.loads(meta.read_text())!=key:
  with cache.open('w') as f:subprocess.run([str(A.ENVELOPE)],input=''.join(json.dumps(dict(mode='decode',txbytes=x))+'\n' for x in raws),text=True,stdout=f,stderr=subprocess.PIPE,check=True)
  meta.write_text(json.dumps(key))
 with cache.open() as f:outputs=[json.loads(l) for l in f]
 assert len(outputs)==len(raws);return dict(zip(raws,outputs))

def cases():
 for path in sorted((MAIN/'conformance/fixtures/state_tests').rglob('*.json')):
  for name,u in json.loads(path.read_text()).items():
   for i,post in enumerate(u['post']['Amsterdam']):yield name,i,u,post

def main():
 start=time.monotonic();cs=list(cases());raws=list(dict.fromkeys(p['txbytes'] for _,_,_,p in cs));decoded=decode_cache(raws)
 report=dict(scope='wire serialization/context/commitment only; no EVM semantic execution',state_cases=len(cs),unique_signed_bytes=len(raws),counts=collections.Counter(),failures=[],wire_rejections=[],host_limit_cases=[],metadata_mismatches=[],environment_keys=collections.Counter());rejections=[];unique_pres=set()
 for name,i,u,post in cs:
  req=R.state_input(u,post);out=decoded[post['txbytes']];report['environment_keys'].update(u['env'].keys())
  assert req['txbytes']==post['txbytes'] and 'post' not in req and 'out' not in req and '_info' not in req
  if post.get('expectException'):rejections.append((name,i,u,post))
  prehash=hashlib.sha256(json.dumps(u['pre'],sort_keys=True).encode()).hexdigest()
  try:
   compare_context(u['env']);report['counts']['context_lossless_serialization']+=1
   if prehash not in unique_pres:compare_pre(u['pre']);unique_pres.add(prehash)
   if 'error' in out:
    result=A.execute(req,timeout=30)
    assert result['status']=='rejected' and result['post_state']==u['pre']
    assert result['exception'] in R.exceptions(post.get('expectException'))
    assert not R.compare_state(u,post,result)
    report['wire_rejections'].append(dict(id=name,exception=result['exception'],state_root=result['state_root'],logs_hash=result['logs_hash']))
    report['counts']['genuine_wire_error_prestate_commitment_verified']+=1;continue
   t=out['decoded'];auth=A.signed_authorities(t);compare_tx(t,auth)
   report['counts']['decoded_tx_lossless_serialization']+=1;report['counts']['authorizations']+=len(auth);report['counts']['unrecoverable_authorizations']+=sum(a is None for a in auth)
   if req['transaction'].get('sender') and N(req['transaction']['sender'])!=N(t['sender']):report['metadata_mismatches'].append(dict(id=name,field='sender',fixture=req['transaction']['sender'],signed=t['sender']))
  except A.Unsupported as e:report['host_limit_cases'].append(dict(id=name,reason=str(e)));report['counts']['host_limit_explicit']+=1
  except Exception as e:report['failures'].append(dict(id=name,error=repr(e)))
 p=subprocess.run([str(A.ORACLE)],input=''.join(json.dumps(dict(mode='commitment',alloc=u['pre'],logs=[]))+'\n' for _,_,u,_ in rejections),text=True,capture_output=True,check=True)
 results=list(map(json.loads,p.stdout.splitlines()));assert len(results)==len(rejections)
 for (name,i,u,post),o in zip(rejections,results):
  if o.get('state_root')!=post['hash'] or o.get('logs_hash')!=post['logs']:report['failures'].append(dict(id=name,error='expected-rejection prestate commitment differs',actual=o,post_hash=post['hash']))
  else:report['counts']['expected_rejection_prestate_commitment_verified']+=1
 report['unique_pre_allocations_lossless']=len(unique_pres);report['seconds']=time.monotonic()-start
 (ROOT/'bridge-audit-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ('wire_rejections','metadata_mismatches')},indent=2));return bool(report['failures'])
if __name__=='__main__':raise SystemExit(main())
