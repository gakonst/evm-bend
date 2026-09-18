from pathlib import Path
import tarfile
files=[]
for p in Path('.').iterdir():
 if p.is_file() and p.suffix in ['.bend','.py','.sh','.md','.json','.patch'] and 'generated' not in p.name:files.append(p)
for folder in ['full','examples','toolchain-debug','precompile-host','envelope-host','revm-adapter','evm2-adapter']:
 for p in Path(folder).rglob('*'):
  if not p.is_file() or any(x in ('target','__pycache__') or x.startswith('.') for x in p.parts):continue
  if p.suffix in ['.bend','.py','.sh','.md','.json','.patch','.rs','.toml','.lock','.ts','.h','.c','.cu'] or folder=='toolchain-debug':files.append(p)
files.extend(p for p in Path('conformance').iterdir() if p.is_file() and (p.suffix in ('.py','.md') or p.name in ('corpus-manifest.json','input-profile.json','transaction-integration-js.json','transaction-integration-native.json')))
files.extend([Path('full/precompile.js'),Path('.gitignore'),Path('word-ops-full.log'),Path('word-ops-resume.log'),Path('regression-final.log')])
with tarfile.open('evm-bend-amsterdam-source.tar.gz','w:gz') as t:
 for p in sorted(set(files)):t.add(p,arcname='evm-bend/'+str(p),recursive=False)
print(len(set(files)),Path('evm-bend-amsterdam-source.tar.gz').stat().st_size)
