from pathlib import Path
parts=['''import Base
import ../evmword.bend as W
import ./model.bend as M

type Reader is Data:
  R{data: +List<U32>, ok: Bool}
''']
records={
'ByteRead':('BR',[('value','U32'),('reader','Reader')]),
'NumRead':('NR',[('value','Nat'),('reader','Reader')]),
'WordRead':('WR',[('value','W.Word'),('reader','Reader')]),
'BytesRead':('BS',[('value','+List<U32>'),('reader','Reader')]),
'WordsRead':('WS',[('value','+List<W.Word>'),('reader','Reader')]),
'SlotsRead':('SS',[('value','+List<M.Slot>'),('reader','Reader')]),
'HashesRead':('HS',[('value','+List<M.BlockHash>'),('reader','Reader')]),
'ContextRead':('CR',[('value','M.Context'),('reader','Reader')]),
'AccountRead':('AR',[('value','M.Account'),('reader','Reader')]),
'AccountsRead':('AS',[('value','+List<M.Account>'),('reader','Reader')]),
'EngineRead':('ER',[('value','M.Engine'),('reader','Reader')]),
}
for typ,(cons,fields) in records.items():
 parts.append(f'\ntype {typ} is Data:\n  {cons}{{'+', '.join(f'{n}: {t}' for n,t in fields)+'}\n')
 for n,t in fields:
  parts.append(f'\ndef {typ}.{n}(r: {typ}) -> {t}:\n  match r:\n    case {cons}{{'+', '.join(x for x,_ in fields)+f'}}:\n      {n}\n')
parts.append('''
def read_byte(r: Reader) -> ByteRead:
  match r:
    case R{Nil{}, ok}:
      BR{0, R{Nil{}, False{}}}
    case R{Con{b, rest}, ok}:
      BR{b, R{rest, ok}}

def read_num(n: Nat, r: Reader, acc: Nat) -> NumRead:
  match n:
    case 0n:
      NR{acc, r}
    case 1n+p:
      +b = read_byte(r)
      read_num(p, ByteRead.reader(b), Nat.add(Nat.mul(acc, 256n), U32.to_nat(ByteRead.value(b))))

def number(r: Reader) -> NumRead:
  read_num(4n, r, 0n)

def read_word(n: Nat, r: Reader, acc: W.Word) -> WordRead:
  match n:
    case 0n:
      WR{acc, r}
    case 1n+p:
      +b = read_byte(r)
      read_word(p, ByteRead.reader(b), W.shift_byte(acc, ByteRead.value(b)))

def word(r: Reader) -> WordRead:
  read_word(32n, r, W.zero())

def reverse_bytes(xs: +List<U32>, acc: +List<U32>) -> +List<U32>:
  match xs:
    case Nil{}: acc
    case Con{x, rest}: reverse_bytes(rest, x <> acc)

def read_bytes_acc(n: Nat, r: Reader, acc: +List<U32>) -> BytesRead:
  match n:
    case 0n: BS{reverse_bytes(acc, Nil{}), r}
    case 1n+p:
      +b = read_byte(r)
      read_bytes_acc(p, ByteRead.reader(b), ByteRead.value(b) <> acc)

def read_bytes(n: Nat, r: Reader) -> BytesRead:
  read_bytes_acc(n, r, Nil{})

def blob(r: Reader) -> BytesRead:
  +n = number(r)
  read_bytes(NumRead.value(n), NumRead.reader(n))

def read_words(n: Nat, r: Reader) -> WordsRead:
  match n:
    case 0n:
      WS{Nil{}, r}
    case 1n+p:
      +w = word(r)
      +rest = read_words(p, WordRead.reader(w))
      WS{WordRead.value(w) <> WordsRead.value(rest), WordsRead.reader(rest)}

def words(r: Reader) -> WordsRead:
  +n = number(r)
  read_words(NumRead.value(n), NumRead.reader(n))

def read_slots(n: Nat, r: Reader) -> SlotsRead:
  match n:
    case 0n:
      SS{Nil{}, r}
    case 1n+p:
      +key = word(r)
      +value = word(WordRead.reader(key))
      +rest = read_slots(p, WordRead.reader(value))
      SS{M.Slot{WordRead.value(key), WordRead.value(value)} <> SlotsRead.value(rest), SlotsRead.reader(rest)}

def slots(r: Reader) -> SlotsRead:
  +n = number(r)
  read_slots(NumRead.value(n), NumRead.reader(n))

def read_hashes(n: Nat, r: Reader) -> HashesRead:
  match n:
    case 0n:
      HS{Nil{}, r}
    case 1n+p:
      +key = word(r)
      +value = word(WordRead.reader(key))
      +rest = read_hashes(p, WordRead.reader(value))
      HS{M.BH{WordRead.value(key), WordRead.value(value)} <> HashesRead.value(rest), HashesRead.reader(rest)}

def hashes(r: Reader) -> HashesRead:
  +n = number(r)
  read_hashes(NumRead.value(n), NumRead.reader(n))

def as_bool(n: U32) -> Bool:
  U32.is_ne(n, 0)
''')
def sequence(name,rettype,fields,body):
 out=[f'\ndef {name}(r: Reader) -> {rettype}:']
 prev='r'
 for field,reader,typ in fields:
  out.append(f'  +{field} = {reader}({prev})')
  prev=f'{typ}.reader({field})'
 out.append('  '+body.replace('{rest}',prev))
 parts.append('\n'.join(out)+'\n')
sequence('context','ContextRead',[(f'v{i}','word','WordRead') for i in range(11)]+[('blobs','words','WordsRead'),('blocks','hashes','HashesRead')], 'CR{M.Ctx{'+', '.join(f'WordRead.value(v{i})' for i in range(11))+', WordsRead.value(blobs), HashesRead.value(blocks)}, {rest}}')
sequence('account','AccountRead',[('address','word','WordRead'),('balance','word','WordRead'),('nonce','word','WordRead'),('code','blob','BytesRead'),('storage','slots','SlotsRead'),('original','slots','SlotsRead'),('transient','slots','SlotsRead'),('warm','read_byte','ByteRead'),('exists','read_byte','ByteRead'),('created','read_byte','ByteRead'),('keys','words','WordsRead')], 'AR{M.Account{WordRead.value(address), WordRead.value(balance), WordRead.value(nonce), BytesRead.value(code), SlotsRead.value(storage), SlotsRead.value(original), SlotsRead.value(transient), as_bool(ByteRead.value(warm)), as_bool(ByteRead.value(exists)), as_bool(ByteRead.value(created)), WordsRead.value(keys)}, {rest}}')
parts.append('''
def read_accounts(n: Nat, r: Reader) -> AccountsRead:
  match n:
    case 0n:
      AS{Nil{}, r}
    case 1n+p:
      +a = account(r)
      +rest = read_accounts(p, AccountRead.reader(a))
      AS{AccountRead.value(a) <> AccountsRead.value(rest), AccountsRead.reader(rest)}

def accounts(r: Reader) -> AccountsRead:
  +n = number(r)
  read_accounts(NumRead.value(n), NumRead.reader(n))
''')
sequence('engine','EngineRead',[('gas','number','NumRead'),('reservoir','number','NumRead'),('code','blob','BytesRead'),('input','blob','BytesRead'),('address','word','WordRead'),('caller','word','WordRead'),('value','word','WordRead'),('static','read_byte','ByteRead'),('ctx','context','ContextRead'),('world','accounts','AccountsRead')], 'ER{M.Engine{M.Frame.set_is_static(M.initial_frame(BytesRead.value(code), NumRead.value(gas), BytesRead.value(input), WordRead.value(address), WordRead.value(caller), WordRead.value(value)), as_bool(ByteRead.value(static))), M.World{AccountsRead.value(world), Nil{}, W.zero(), Nil{}}, ContextRead.value(ctx), NumRead.value(reservoir), W.zero(), 0n}, {rest}}')
parts.append('''
def valid(r: Reader) -> Bool:
  match r:
    case R{Nil{}, ok}:
      ok
    case R{Con{b, rest}, ok}:
      False{}

def decode(data: +List<U32>) -> EngineRead:
  engine(R{data, True{}})
''')
Path('full/codec.bend').write_text(''.join(parts))
