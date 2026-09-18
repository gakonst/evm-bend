import sys,json,hashlib,gzip,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; C=ROOT/'conformance';sys.path.insert(0,str(C));import runner as R
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
backend=sys.argv[1];out=C/'state-gate-host-hardened';s=json.loads((out/f'{backend}-summary.json').read_text())
assert s['complete_pass'] and s['implementation_unchanged'] and s['status_counts']=={'pass':15918,'not_run':0}
assert R.implementation_fingerprint(s['command'],backend)==s['implementation_sha256']
manifest=C/'integrated-build-provenance.json';m=json.loads(manifest.read_text())
for p,h in m['sha256'].items():assert sha(ROOT/p)==h,p
inv={r['id']:r for r in R.read_inventory() if r['format']=='state_test'};assert len(inv)==15918
journal=out/f'{backend}.jsonl';seen=set();variants=0;actuals=collections.Counter()
with journal.open() as f:
 for line in f:
  r=json.loads(line);key=r['id'];assert key in inv and key not in seen;seen.add(key)
  assert r['fixture_hash']==inv[key]['fixture_hash'] and r['backend']==backend and r['implementation_sha256']==s['implementation_sha256'] and r['status']=='pass'
  u=R.fixture(inv[key]);posts=u['post']['Amsterdam'];assert len(r['variants'])==len(posts)==r['post_variants']
  assert [v['post_index'] for v in r['variants']]==list(range(len(posts)))
  for v,p in zip(r['variants'],posts):
   assert v['status']=='pass' and not v['failures'];a=v['actual'];assert a['status'] in ('executed','rejected')
   assert a['state_root'] and a['logs_hash'] and not R.compare_state(u,p,a)
   actuals[a['status']]+=1;variants+=1
assert seen==set(inv)
z=journal.with_suffix('.jsonl.gz');z.write_bytes(gzip.compress(journal.read_bytes(),compresslevel=9,mtime=0))
s.update(journal_sha256=sha(journal),journal_gzip_sha256=sha(z),journal_gzip_bytes=z.stat().st_size,post_variants=variants,actual_status_counts=dict(actuals),source_manifest_sha256=sha(manifest),adapter_sha256=sha(C/'bend_adapter.py'),inventory_sha256=sha(C/'inventory.jsonl'),transaction_binary_sha256=sha(ROOT/('evm-transaction-native' if backend=='native' else 'evm-transaction.js')),gate_command=['python3','-u','conformance/full_state_gate.py','--backend',backend,'--workers','12','--timeout','1200' if backend=='native' else '3600','--output','state-gate-host-hardened'],independent_audit=dict(all_required_ids_exactly_once=True,all_fixture_hashes_match_inventory=True,all_post_variants_recompared=True,all_commitments_present=True,current_fingerprint_matches=True,source_and_binary_manifest_matches=True))
(C/f'{backend}-host-hardened-summary.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(s,indent=2))
