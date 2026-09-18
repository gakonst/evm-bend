import re
p='full/state-ops.bend';s=open(p).read();parts=re.split(r'(?=^def )',s,flags=re.M);header=parts.pop(0);defs={re.match(r'def (\w+)',x)[1]:x for x in parts};done=set();out=[]
def visit(k):
 if k in done:return
 done.add(k)
 for name in re.findall(r'(?<![.\w])(\w+)\(',defs[k].split('\n',1)[1]):
  if name in defs and name!=k:visit(name)
 out.append(defs[k])
for k in defs:visit(k)
open(p,'w').write(header+''.join(out))
