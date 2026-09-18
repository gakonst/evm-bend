#!/usr/bin/env python3
"""Pin and inventory the upstream release without dropping failing/unsupported cases."""
import argparse,collections,hashlib,json,tarfile
from pathlib import Path,PurePosixPath
HERE=Path(__file__).resolve().parent
SHA='aed315489163dc67c4e5607d7bbb8902e8329afe939be58193b125f2e81a85d4'
TAG='tests-glamsterdam-devnet@v8.1.4'
APPLICABLE={'state_test','blockchain_test','transaction_test'}
SCOPE_REASON='Engine API request/response and sync protocol format; separately inventoried, not an EVM interpreter API. Execution equivalents are covered by state/blockchain formats.'
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--extract',action='store_true');a=ap.parse_args()
 release=json.loads((HERE/'release.json').read_text());idx=json.loads((HERE/'upstream-index.json').read_text())
 records=idx['test_cases'];counts=collections.Counter((x['fork'],x['format']) for x in records)
 selected=[]
 for t in records:
  if t['fork']=='Amsterdam':
   t=dict(t);t['scope']='required' if t['format'] in APPLICABLE else 'protocol_api';t['scope_reason']='Amsterdam execution/transaction conformance' if t['scope']=='required' else SCOPE_REASON;selected.append(t)
 paths={t['json_path'] for t in selected if t['scope']=='required'}
 manifest=dict(release=TAG,release_commit=release['target_commitish'],archive_sha256=SHA,upstream_root_hash=idx['root_hash'],upstream_cases=idx['test_count'],amsterdam_cases=len(selected),required_cases=sum(t['scope']=='required' for t in selected),protocol_api_cases=sum(t['scope']=='protocol_api' for t in selected),counts=[dict(fork=f,format=k,count=n) for (f,k),n in sorted(counts.items())],required_files=len(paths),scope_note=SCOPE_REASON)
 (HERE/'corpus-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 with (HERE/'inventory.jsonl').open('w') as out:
  for t in selected:out.write(json.dumps(t,separators=(',',':'))+'\n')
 if a.extract:
  archive=HERE/'fixtures_glamsterdam-devnet.tar.gz'
  with archive.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
  if digest!=SHA:raise ValueError('archive digest mismatch')
  found=set();total=0
  with tarfile.open(archive,'r|gz') as tar:
   for m in tar:
    p=PurePosixPath(m.name)
    if p.parts[0]!='fixtures' or '..' in p.parts or p.is_absolute():raise ValueError('unsafe archive path')
    rel=str(PurePosixPath(*p.parts[1:]))
    if rel not in paths:continue
    if not m.isfile():raise ValueError('selected fixture is not regular file')
    dst=HERE/'fixtures'/rel;dst.parent.mkdir(parents=True,exist_ok=True)
    with tar.extractfile(m) as src,dst.open('wb') as out:
     while block:=src.read(1024*1024):out.write(block)
    found.add(rel);total+=m.size
    if len(found)%500==0:print('extracted',len(found),'/',len(paths),flush=True)
  if found!=paths:raise ValueError(f'missing fixtures: {paths-found}')
  manifest['extracted_bytes']=total;manifest['extraction_complete']=True
  (HERE/'corpus-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({k:v for k,v in manifest.items() if k!='counts'},indent=2))
if __name__=='__main__':main()
