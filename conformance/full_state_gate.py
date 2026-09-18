#!/usr/bin/env python3
"""Complete pinned state gate, parallel process-isolated executions and exact resume."""
import argparse,collections,concurrent.futures,json,os,sys,time
from pathlib import Path
import runner as R

def main():
 p=argparse.ArgumentParser();p.add_argument('--backend',choices=['native','js'],required=True);p.add_argument('--workers',type=int,default=8);p.add_argument('--timeout',type=float,default=1200);p.add_argument('--output',default='state-gate');p.add_argument('--resume',action='store_true');a=p.parse_args()
 rows=[r for r in R.read_inventory() if r['format']=='state_test']
 assert len(rows)==15918 and len({r['id'] for r in rows})==15918
 cmd=[sys.executable,str(R.HERE/'bend_adapter.py'),'--backend',a.backend,'--timeout',str(a.timeout)]
 fp=R.implementation_fingerprint(cmd,a.backend);out=R.HERE/a.output;out.mkdir(parents=True,exist_ok=True);journal=out/(a.backend+'.jsonl');previous={}
 if a.resume and journal.exists():
  for line in journal.read_text().splitlines():
   r=json.loads(line)
   if r.get('implementation_sha256')==fp:previous[r['id']]=r
 def run(row):
  start=time.monotonic()
  try:result=R.execute(row,cmd,{'state_test'},a.timeout)
  except Exception as e:result=dict(status='error',reason=type(e).__name__,detail=str(e))
  # Full actual state is useful for failures. Passed rows retain commitments.
  if result['status']=='pass':
   for v in result.get('variants',[]):
    v['actual']={k:v['actual'].get(k) for k in ('status','exception','exception_aliases','state_root','logs_hash','output','gas','frame_status')}
  return dict(row,backend=a.backend,implementation_sha256=fp,seconds=time.monotonic()-start,**result)
 todo=[r for r in rows if previous.get(r['id'],{}).get('status')!='pass' or previous[r['id']].get('fixture_hash')!=r['fixture_hash']]
 started=time.monotonic()
 def summary(final=False):
  counts=collections.Counter(r['status'] for r in previous.values());counts['not_run']=len(rows)-len(previous)
  stable=not final or R.implementation_fingerprint(cmd,a.backend)==fp
  manifest=json.loads((R.HERE/'corpus-manifest.json').read_text())
  value=dict(backend=a.backend,required=len(rows),recorded=len(previous),status_counts=dict(counts),implementation_sha256=fp,implementation_unchanged=stable,complete_pass=final and stable and counts['pass']==len(rows),release=manifest['release'],archive_sha256=manifest['archive_sha256'],command=cmd,seconds=time.monotonic()-started)
  dst=out/(a.backend+'-summary.json');tmp=dst.with_suffix('.tmp');tmp.write_text(json.dumps(value,indent=2)+'\n');tmp.replace(dst);print(json.dumps(value),flush=True);return value
 summary()
 with journal.open('a' if a.resume else 'w') as f,concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as pool:
  futures=[pool.submit(run,r) for r in todo]
  for i,future in enumerate(concurrent.futures.as_completed(futures)):
   r=future.result();previous[r['id']]=r;f.write(json.dumps(r,separators=(',',':'))+'\n');f.flush()
   if (i+1)%100==0:os.fsync(f.fileno());summary()
 return 0 if summary(True)['complete_pass'] else 1
if __name__=='__main__':raise SystemExit(main())
