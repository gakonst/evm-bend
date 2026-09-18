"""Summarize actual required fixture inputs to guide implementation priorities."""
import collections,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
paths=collections.defaultdict(list)
for line in (HERE/'inventory.jsonl').read_text().splitlines():
 r=json.loads(line)
 if r['scope']=='required':paths[r['json_path']].append(r)
c=collections.Counter();maximum=collections.defaultdict(int)
def num(v):return int(v,16) if isinstance(v,str) and v.startswith('0x') else int(v)
for path,rows in paths.items():
 if not any(r['format']=='state_test' for r in rows):continue
 units=json.loads((HERE/'fixtures'/path).read_text())
 for r in rows:
  if r['format']!='state_test':continue
  u=units[r['id']];t=u['transaction'];posts=u['post']['Amsterdam'];c['state_fixtures']+=1;c['state_post_variants']+=len(posts)
  typ=t.get('type')
  if typ is None:typ=4 if 'authorizationList' in t else 3 if 'maxFeePerBlobGas' in t else 2 if 'maxFeePerGas' in t else 1 if 'accessLists' in t else 0
  else:typ=num(typ)
  c[f'type_{typ}']+=1
  if not t.get('to'):c['contract_creation']+=1
  if t.get('authorizationList'):c['with_authorizations']+=1
  if t.get('blobVersionedHashes'):c['with_blobs']+=1
  if any(p.get('expectException') for p in posts):c['expected_transaction_rejection']+=1
  if any(num(v)>2**24 for v in t['gasLimit']):c['gas_limit_above_old_frame_host_cap']+=1
  maximum['gas_limit']=max(maximum['gas_limit'],*[num(v) for v in t['gasLimit']])
  maximum['accounts']=max(maximum['accounts'],len(u['pre']))
  maximum['calldata_bytes']=max(maximum['calldata_bytes'],*[(len(v)-2)//2 for v in t['data']])
  maximum['pre_code_bytes']=max(maximum['pre_code_bytes'],*[(len(v['code'])-2)//2 for v in u['pre'].values()])
profile=dict(counts=dict(sorted(c.items())),maximum=dict(maximum))
(HERE/'input-profile.json').write_text(json.dumps(profile,indent=2)+'\n');print(json.dumps(profile,indent=2))
