import re,subprocess,pathlib,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text(); chunks=re.split(r'(?=^def )',s,flags=re.M); defs={re.match(r'def ([\w.]+)',c)[1]:c for c in chunks[1:]}; prefix=chunks[0]
def closure(k,seen):
 if k in seen:return
 seen.add(k)
 for dep in defs:
  if re.search(r'(?<![\w.])'+re.escape(dep)+r'\(',defs[k]) and dep!=k:closure(dep,seen)
for k in defs:
 seen=set();closure(k,seen)
 pathlib.Path('full/call-probe.bend').write_text(prefix+''.join(defs[d] for d in defs if d in seen))
 try:r=subprocess.run(['/srv/nanocodex/.bend/bin/bend','full/call-probe.bend'],capture_output=True,text=True,timeout=10,env={**__import__('os').environ,'BEND_NO_TELEMETRY':'1'})
 except subprocess.TimeoutExpired:print(k,'TIMEOUT',flush=True);break
 print(k,r.returncode,r.stdout[:300]+r.stderr[:300],flush=True)
 if r.returncode:break
