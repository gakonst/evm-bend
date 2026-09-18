from pathlib import Path
head='''import Base
import ../evmword.bend as W
import ./memory.bend as Mem
import ./input.bend as I

type Slot is Data:
  Slot{key: W.Word, value: W.Word}

type Log is Data:
  Log{address: W.Word, topics: +List<W.Word>, data: +List<U32>}

type BlockHash is Data:
  BH{number: W.Word, hash: W.Word}

# Action is explicit: the runner alone enters/unwinds child frames.
type Action is Data:
  Running{}
  Stopped{}
  Returned{}
  Reverted{}
  Fault{reason: U32}
  Call{kind: U32, gas: W.Word, target: W.Word, value: W.Word, in_offset: W.Word, in_size: W.Word, out_offset: W.Word, out_size: W.Word}
  Create{kind: U32, value: W.Word, offset: W.Word, size: W.Word, salt: W.Word}
  SelfDestruct{target: W.Word}
  Precompile{address: U32}
  HostLimit{}
'''
records = {
'Context':('Ctx',[('origin','W.Word'),('gasprice','W.Word'),('coinbase','W.Word'),('timestamp','W.Word'),('number','W.Word'),('prevrandao','W.Word'),('gaslimit','W.Word'),('chainid','W.Word'),('basefee','W.Word'),('blobbasefee','W.Word'),('slotnum','W.Word'),('blobhashes','+List<W.Word>'),('blockhashes','+List<BlockHash>')]),
'Account':('Account',[('address','W.Word'),('balance','W.Word'),('nonce','W.Word'),('code','+List<U32>'),('storage','+List<Slot>'),('original','+List<Slot>'),('transient','+List<Slot>'),('warm','Bool'),('exists','Bool'),('created','Bool'),('storage_warm','+List<W.Word>')]),
'World':('World',[('accounts','+List<Account>'),('logs','+List<Log>'),('refund','W.Word'),('selfdestructs','+List<W.Word>')]),
'Frame':('Frame',[('gas','Nat'),('pc','Nat'),('stack','+List<W.Word>'),('memory','Mem.Mem'),('code','+List<U32>'),('input','I.View'),('ret','+List<U32>'),('address','W.Word'),('caller','W.Word'),('value','W.Word'),('is_static','Bool'),('depth','Nat'),('action','Action'),('output','+List<U32>')]),
'Engine':('Engine',[('frame','Frame'),('world','World'),('context','Context'),('reservoir','Nat'),('state_used','W.Word'),('state_spilled','Nat')]),
'Parent':('Parent',[('frame','Frame'),('snapshot','World'),('kind','U32'),('out_offset','Nat'),('out_size','Nat'),('created_address','W.Word'),('state_used','W.Word'),('state_spilled','Nat')]),
'Machine':('Machine',[('engine','Engine'),('parents','+List<Parent>')])
}
parts=[head]
for typ,(cons,fields) in records.items():
 parts.append(f'\ntype {typ} is Data:\n  {cons}{{'+', '.join(f'{n}: {t}' for n,t in fields)+'}\n')
 for name,t in fields:
  if typ == 'Frame' and name == 'input':
   parts.append('\n'+'def Frame.input_view(x: Frame) -> I.View:\n  match x:\n    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:\n      input\n\ndef Frame.input(x: Frame) -> +List<U32>:\n  I.all(Frame.input_view(x))\n\ndef Frame.input_len(x: Frame) -> Nat:\n  I.len(Frame.input_view(x))\n\ndef Frame.input_read(x: Frame, offset: Nat, count: Nat) -> +List<U32>:\n  I.read(Frame.input_view(x),offset,count)\n\ndef memory_input(memory: Mem.Mem, offset: Nat, length: Nat) -> I.View:\n  I.Slice{memory,offset,length}\n\ndef empty_input() -> I.View:\n  I.Bytes{0n,Nil{}}\n\ndef Frame.set_input(x: Frame, new: +List<U32>) -> Frame:\n  match x:\n    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:\n      Frame{gas, pc, stack, memory, code, I.bytes(new), ret, address, caller, value, is_static, depth, action, output}\n')
   continue
  names=[n for n,_ in fields]
  pat=', '.join(names)
  parts.append(f'\ndef {typ}.{name}(x: {typ}) -> {t}:\n  match x:\n    case {cons}{{{pat}}}:\n      {name}\n')
  newpat=', '.join('new' if n==name else n for n in names)
  parts.append(f'\ndef {typ}.set_{name}(x: {typ}, new: {t}) -> {typ}:\n  match x:\n    case {cons}{{{pat}}}:\n      {cons}{{{newpat}}}\n')
parts.append('''
def default_context() -> Context:
  Ctx{W.zero(), W.zero(), W.zero(), W.zero(), W.zero(), W.zero(), W.from_u32(16777216), W.from_u32(1), W.zero(), W.zero(), W.zero(), Nil{}, Nil{}}

def empty_world() -> World:
  World{Nil{}, Nil{}, W.zero(), Nil{}}

def empty_account(address: W.Word) -> Account:
  Account{address, W.zero(), W.zero(), Nil{}, Nil{}, Nil{}, Nil{}, False{}, False{}, False{}, Nil{}}

def initial_frame(code: +List<U32>, gas: Nat, input: +List<U32>, address: W.Word, caller: W.Word, value: W.Word) -> Frame:
  Frame{gas, 0n, Nil{}, Mem.empty(), code, I.bytes(input), Nil{}, address, caller, value, False{}, 0n, Running{}, Nil{}}

# Fault codes: 1 OOG, 2 stack underflow, 3 overflow, 4 invalid opcode,
# 5 invalid jump, 6 static violation, 7 return-data bounds, 8 invalid immediate.
def fault(f: Frame, reason: U32) -> Frame:
  Frame.set_action(Frame.set_output(Frame.set_gas(f, 0n), Nil{}), Fault{reason})
''')
Path('full/model.bend').write_text(''.join(parts))
