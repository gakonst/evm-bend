#!/usr/bin/env python3
"""Deterministic Python bigint differential tests of pure Bend word arithmetic."""
import os, random, subprocess, pathlib
ROOT=pathlib.Path(__file__).resolve().parent
BEND=os.environ.get('BEND',str(ROOT/'bend-local.sh'))
MASK=(1<<256)-1
rng=random.Random(256)
cases=[]
def w(x): return 'W.W{'+','.join(str((x>>(32*i))&0xffffffff) for i in range(8))+'}'
def signed(x): return x-(1<<256) if x>>255 else x
def add(op,args,result,kind='word'):
    expr='O.'+op+'('+','.join(('Nat.add(Nat.mul(U32.to_nat('+str(x>>32)+'),Nat.add(U32.to_nat(4294967295),1n)),U32.to_nat('+str(x&0xffffffff)+'))') if op=='from_nat' else w(x) for x in args)+')'
    show={'word':'W.show','bool':'Bool.show','nat':'Nat.show'}[kind]
    expected=w(result)[2:] if kind=='word' else ('True' if result else 'False') if kind=='bool' else str(result)
    cases.append((expr,show,expected,op,args))
edge=[0,1,2,31,32,255,256,(1<<32)-1,1<<32,(1<<48)-1,1<<48,(1<<255)-1,1<<255,MASK-1,MASK]
pairs=[(a,b) for a in edge for b in edge]+[(rng.getrandbits(256),rng.getrandbits(256)) for _ in range(40)]
for a,b in pairs:
    sa,sb=signed(a),signed(b)
    q=(abs(sa)//abs(sb))*(-1 if (sa<0)!=(sb<0) else 1) if sb else 0
    for op,r in [('sub',a-b),('mul',a*b),('div',a//b if b else 0),('mod',a%b if b else 0),('sdiv',q),('smod',(abs(sa)%abs(sb))*(-1 if sa<0 else 1) if sb else 0),('bit_and',a&b),('bit_or',a|b),('bit_xor',a^b)]: add(op,[a,b],r&MASK)
    for op,r in [('lt',a<b),('gt',a>b),('slt',sa<sb),('sgt',sa>sb)]: add(op,[a,b],r,'bool')
for a in edge+[rng.getrandbits(256) for _ in range(20)]:
    add('bit_not',[a],a^MASK);add('clz',[a],256-a.bit_length());add('to_nat',[a],a&((1<<48)-1),'nat');add('fits_nat',[a],a<(1<<48),'bool')
    for b in [0,1,7,8,15,31,32,63,127,248,255,256,257,MASK]:
        add('shl',[b,a],(a<<b)&MASK if b<256 else 0)
        add('shr',[b,a],a>>b if b<256 else 0)
        add('sar',[b,a],(signed(a)>>min(b,256))&MASK)
        add('byte',[b,a],(a>>(8*(31-b)))&255 if b<32 else 0)
        bits=8*(b+1)
        r=a if b>=31 else ((a&((1<<bits)-1)) | (MASK^((1<<bits)-1)) if a&(1<<(bits-1)) else a&((1<<bits)-1))
        add('signextend',[b,a],r)
for a in edge:
    for b in [0,1,2,3,255,256,MASK]: add('exp',[a,b],pow(a,b,1<<256))
for a,b in [(MASK,MASK),(1<<255,1<<255),(MASK,2),(0,MASK)]+pairs[::7]:
    for m in [0,1,2,3,1<<255,MASK,rng.getrandbits(256)]:
        add('addmod',[a,b,m],(a+b)%m if m else 0)
        add('mulmod',[a,b,m],(a*b)%m if m else 0)
for a in [0,1,(1<<32)-1,1<<32,(1<<48)-1]:add('from_nat',[a],a)
# Bounded batches avoid enormous generated compiler functions.
import json, time
quick=os.environ.get('BEND_WORD_TEST_QUICK')=='1'
if quick:
    chosen=[]
    for op in dict.fromkeys(c[3] for c in cases):
        group=[c for c in cases if c[3]==op]
        chosen += [group[0],group[len(group)//2],group[-1]]
    cases=chosen
summary={'cases':len(cases),'quick':quick,'seed':256,'backends':{}}
env=dict(os.environ,BEND_NO_TELEMETRY='1')
for backend in os.environ.get('BEND_WORD_BACKENDS','js,native').split(','):
    begin=int(os.environ.get('BEND_WORD_START','0'))
    for start in range(begin,len(cases),96):
        batch=cases[start:start+96]
        lines=['import Base','import ./evmword.bend as W','import ./word-ops.bend as O', 'def main() -> IO(Unit):','  do IO<Unit>:']
        lines += ['    IO.print('+show+'('+expr+'))' for expr,show,*_ in batch]
        source=ROOT/'word-ops-tests-generated.bend';source.write_text('\n'.join(lines)+'\n')
        target=ROOT/('word-ops-tests-bin'+('.js' if backend=='js' else ''))
        subprocess.run([BEND,str(source),'-o',str(target)],check=True,env=env,cwd=ROOT,stdout=subprocess.PIPE,timeout=120)
        if backend=='js':
            import re
            target.write_text(re.sub(r'\$[\w$-]+',lambda m:m[0].replace('-','_'),target.read_text()))
        cmd=[os.path.expanduser('~/.bun/bin/bun'),str(target)] if backend=='js' else [str(target)]
        proc=subprocess.run(cmd,check=True,env=env,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=120)
        actual=proc.stdout.splitlines()
        assert len(actual)==len(batch),(backend,start,len(actual),len(batch),actual[:3],proc.stderr)
        for i,(got,(_,_,want,op,args)) in enumerate(zip(actual,batch)):
            assert got==want,(backend,start+i,op,args,got,want)
        print(f'{backend}: {start+len(batch)}/{len(cases)} passed',flush=True)
    summary['backends'][backend]={'start':begin,'end':len(cases),'passed':len(cases)-begin}
(ROOT/('word-ops-resume-results.json' if os.environ.get('BEND_WORD_START') else 'word-ops-results.json')).write_text(json.dumps(summary,indent=2)+'\n')
