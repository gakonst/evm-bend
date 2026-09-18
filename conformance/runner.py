#!/usr/bin/env python3
"""Resumable complete-corpus gate. Required cases never disappear as skips.

An adapter receives inputs only, not expected post-state roots. It must execute
Bend and use an independent commitment helper to return state_root/logs_hash.
Absent capabilities are BLOCKED, never PASS. All required cases retain a row.
"""
import argparse,collections,hashlib,json,os,shlex,subprocess,time,signal
from functools import lru_cache
from pathlib import Path
HERE=Path(__file__).resolve().parent
STATUSES={'pass','fail','blocked','error','not_run'}

def read_inventory():
 with (HERE/'inventory.jsonl').open() as f:
  for line in f:
   row=json.loads(line)
   if row['scope']=='required':yield row

@lru_cache(maxsize=4)
def fixture_file(path):
 p=HERE/'fixtures'/path
 if not p.resolve().is_relative_to((HERE/'fixtures').resolve()):raise ValueError('unsafe fixture path')
 return json.loads(p.read_text())

def fixture(row):
 unit=fixture_file(row['json_path'])[row['id']]
 if unit.get('_info',{}).get('hash')!=row['fixture_hash']:raise ValueError('fixture metadata digest differs from pinned index')
 return unit

def state_input(unit,post):
 tx=dict(unit['transaction']);i=post['indexes']
 tx['data']=tx['data'][i['data']];tx['gasLimit']=tx['gasLimit'][i['gas']];tx['value']=tx['value'][i['value']]
 if 'accessLists' in tx:
  tx['accessList']=tx.pop('accessLists')[i['data']]
 # Public fixture signing material is not needed when an explicit sender exists.
 # Never send fixture expected output/post-state to the execution adapter.
 if tx.get('sender'):tx.pop('secretKey',None)
 request=dict(format='state_test',fork='Amsterdam',env=unit['env'],pre=unit['pre'],transaction=tx)
 if 'txbytes' in post:request['txbytes']=post['txbytes']
 return request

def exceptions(value):
 if not value:return {None}
 if isinstance(value,list):return set(value)
 return set(value.split('|'))

def compare_state(unit,post,actual):
 errors=[]
 if actual.get('exception') not in exceptions(post.get('expectException')):errors.append(dict(field='exception',expected=post.get('expectException'),actual=actual.get('exception')))
 for src,dst in [('hash','state_root'),('logs','logs_hash')]:
  if actual.get(dst)!=post[src]:errors.append(dict(field=dst,expected=post[src],actual=actual.get(dst)))
 if 'out' in unit and actual.get('output')!=unit['out']:errors.append(dict(field='output',expected=unit['out'],actual=actual.get('output')))
 return errors

def adapter_call(command,request,timeout):
 p=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
 try:stdout,stderr=p.communicate(json.dumps(request,separators=(',',':')),timeout=timeout)
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGKILL);p.communicate();raise
 p.stdout=stdout;p.stderr=stderr
 if p.returncode:raise RuntimeError(f'adapter exit {p.returncode}: {p.stderr[-2000:]}')
 result=json.loads(p.stdout)
 if not isinstance(result,dict):raise ValueError('adapter result must be an object')
 return result

def execute(row,command,capabilities,timeout):
 fmt=row['format']
 if not command:return dict(status='not_run',reason='no_execution_adapter_configured')
 if fmt not in capabilities:return dict(status='blocked',reason='adapter_missing_'+fmt)
 unit=fixture(row)
 if fmt=='state_test':
  posts=unit['post']['Amsterdam'];results=[]
  for n,post in enumerate(posts):
   actual=adapter_call(command,state_input(unit,post),timeout)
   if actual.get('status') in ('unsupported','host_error'):
    results.append(dict(post_index=n,status='blocked' if actual['status']=='unsupported' else 'error',reason=actual.get('reason','unspecified'),actual=actual));continue
   if actual.get('status') not in ('executed','rejected'):raise ValueError('invalid state adapter status: '+str(actual.get('status')))
   failures=compare_state(unit,post,actual)
   results.append(dict(post_index=n,status='fail' if failures else 'pass',failures=failures,actual=actual))
  status=next((s for s in ['error','blocked','fail'] if any(x['status']==s for x in results)),'pass')
  return dict(status=status,post_variants=len(posts),variants=results)
 if fmt=='transaction_test':
  expected=unit['result']['Amsterdam'];actual=adapter_call(command,dict(format=fmt,fork='Amsterdam',txbytes=unit['txbytes']),timeout)
  if actual.get('status') in ('unsupported','host_error'):return dict(status='blocked' if actual['status']=='unsupported' else 'error',reason=actual.get('reason'))
  failures=[]
  if actual.get('exception') not in exceptions(expected.get('exception')):failures.append(dict(field='exception',expected=expected.get('exception'),actual=actual.get('exception')))
  for k in ['intrinsicGas','sender','hash']:
   if k in expected and actual.get(k)!=expected[k]:failures.append(dict(field=k,expected=expected[k],actual=actual.get(k)))
  return dict(status='fail' if failures else 'pass',failures=failures,actual=actual)
 # Blockchain validation includes sequential state, system calls, and invalid
 # blocks. An adapter must return independent final roots and block outcomes.
 request={k:v for k,v in unit.items() if k not in ('_info','postState','postStateHash','lastblockhash','blocks')}
 request['blocks']=[{k:v for k,v in block.items() if k not in ('expectException','receipts')} for block in unit['blocks']]
 request.update(format=fmt,fork='Amsterdam')
 actual=adapter_call(command,request,timeout)
 if actual.get('status') in ('unsupported','host_error'):return dict(status='blocked' if actual['status']=='unsupported' else 'error',reason=actual.get('reason'))
 failures=[]
 results=actual.get('blocks',[])
 if len(results)!=len(unit['blocks']):failures.append(dict(field='block_count',expected=len(unit['blocks']),actual=len(results)))
 for n,(block,result) in enumerate(zip(unit['blocks'],results)):
  expected_exception=block.get('expectException')
  if result.get('exception') not in exceptions(expected_exception):failures.append(dict(field=f'blocks[{n}].exception',expected=expected_exception,actual=result.get('exception')))
  if expected_exception:continue
  header=block.get('blockHeader',{})
  for src,dst in [('stateRoot','state_root'),('gasUsed','gas_used'),('receiptTrie','receipts_root'),('transactionsTrie','transactions_root'),('bloom','logs_bloom'),('blockAccessListHash','block_access_list_hash'),('requestsHash','requests_hash'),('hash','block_hash')]:
   if src not in header:continue
   got=result.get(dst);want=header[src]
   if dst=='gas_used' and got is not None:
    got=integer(got);want=integer(want)
   if got!=want:failures.append(dict(field=f'blocks[{n}].{dst}',expected=want,actual=got))
  if 'receipts' in block and result.get('receipts')!=block['receipts']:failures.append(dict(field=f'blocks[{n}].receipts',expected='fixture receipts',actual='different receipts'))
 for src,dst in [('postStateHash','state_root'),('lastblockhash','last_block_hash')]:
  if src in unit and actual.get(dst)!=unit[src]:failures.append(dict(field=dst,expected=unit[src],actual=actual.get(dst)))
 if 'postState' in unit:
  # Canonicalize before exact full-account/storage equality, not a changed-slot subset.
  if canonical_alloc(actual.get('post_state',{}))!=canonical_alloc(unit['postState']):failures.append(dict(field='post_state',expected='fixture full allocation',actual='different allocation'))
 return dict(status='fail' if failures else 'pass',failures=failures,actual=actual)

def integer(v):return int(v,16) if isinstance(v,str) and v.startswith('0x') else int(v)
def canonical_alloc(alloc):
 return {integer(a):dict(nonce=integer(x['nonce']),balance=integer(x['balance']),code=bytes.fromhex(x['code'].removeprefix('0x')),storage={integer(k):integer(v) for k,v in x.get('storage',{}).items() if integer(v)}) for a,x in alloc.items()}

def implementation_fingerprint(command,backend):
 root=HERE.parent; h=hashlib.sha256()
 h.update(json.dumps([command,backend],sort_keys=True).encode())
 paths=list(root.glob('*.bend'))+list((root/'full').glob('*.bend'))+[root/'full/precompile.c',root/'full/precompile.js']
 paths += list(HERE.glob('*.py'))
 paths += [root/'evm.py',HERE/'bend_adapter.py',root/('evm-transaction-native' if backend=='native' else 'evm-transaction.js')]
 for folder,binary in [('envelope-host','evm-bend-envelope'),('revm-adapter','revm-adapter'),('precompile-host','bend-evm-precompile-host')]:
  paths += list((root/folder/'src').glob('*.rs'))+[root/folder/'Cargo.lock',root/folder/'target/debug'/binary]
 for path in sorted(set(paths)):
  if path.is_file():
   h.update(str(path.relative_to(root)).encode()+b'\0')
   with path.open('rb') as f:
    for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
 return h.hexdigest()

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--format',choices=['state_test','transaction_test','blockchain_test'],help='Conformance gate scope; omitted includes all required formats');ap.add_argument('--adapter',help='argv command receiving one JSON request on stdin; shell disabled');ap.add_argument('--capabilities',default='',help='comma-separated fixture formats actually supported by adapter');ap.add_argument('--backend',choices=['native','js'],default='native');ap.add_argument('--timeout',type=float,default=120);ap.add_argument('--match',default='');ap.add_argument('--limit',type=int);ap.add_argument('--resume',action='store_true');ap.add_argument('--validate-inputs',action='store_true');ap.add_argument('--output',default='results');args=ap.parse_args()
 command=shlex.split(args.adapter) if args.adapter else None
 capabilities=set(args.capabilities.split(',')) if command else set()
 rows=[r for r in read_inventory() if args.format is None or r['format']==args.format];out=HERE/args.output;out.mkdir(parents=True,exist_ok=True);journal=out/f'{args.backend}.jsonl';previous={}
 if args.resume and journal.exists():
  for line in journal.read_text().splitlines():
   r=json.loads(line);previous[r['id']]=r
 else:journal.write_text('')
 fingerprint=implementation_fingerprint(command,args.backend)
 selected=0;start=time.monotonic();failures=0
 with journal.open('a') as f:
  for n,row in enumerate(rows):
   old=previous.get(row['id'])
   if old and old.get('fixture_hash')!=row['fixture_hash']:raise ValueError('resume fixture hash mismatch')
   if args.resume and old and old['status']=='pass' and old.get('implementation_sha256')==fingerprint:continue
   base={k:row[k] for k in ['id','format','json_path','fixture_hash']};base['backend']=args.backend;base['implementation_sha256']=fingerprint
   wanted=args.match in row['id'] and (args.limit is None or selected<args.limit)
   if not wanted:
    if old:continue
    result=dict(status='not_run',reason='outside_this_invocation_filter')
   else:
    selected+=1;t=time.monotonic()
    try:
     if args.validate_inputs:fixture(row)
     result=execute(row,command,capabilities,args.timeout)
    except subprocess.TimeoutExpired:result=dict(status='error',reason='host_timeout')
    except Exception as e:result=dict(status='error',reason=type(e).__name__,detail=str(e))
    result['seconds']=time.monotonic()-t
   result=dict(base,**result);previous[row['id']]=result;f.write(json.dumps(result,separators=(',',':'))+'\n');f.flush()
   if result['status'] in ('error','fail'):failures+=1
   if (n+1)%1000==0:print('recorded',n+1,'/',len(rows),'failures',failures,flush=True)
 counts=collections.Counter(r['status'] for r in previous.values());manifest=json.loads((HERE/'corpus-manifest.json').read_text())
 summary=dict(scope=args.format or 'all_required',implementation_sha256=fingerprint,backend=args.backend,release=manifest['release'],archive_sha256=manifest['archive_sha256'],required=len(rows),recorded=len(previous),selected_this_run=selected,status_counts={s:counts[s] for s in sorted(STATUSES)},complete_pass=len(previous)==len(rows) and counts['pass']==len(rows) and all(r.get('implementation_sha256')==fingerprint for r in previous.values()),seconds=time.monotonic()-start,command=command)
 path=out/f'{args.backend}-summary.json';temp=path.with_suffix('.tmp');temp.write_text(json.dumps(summary,indent=2)+'\n');os.replace(temp,path);print(json.dumps(summary,indent=2))
 return 0 if summary['complete_pass'] else 1
if __name__=='__main__':raise SystemExit(main())
