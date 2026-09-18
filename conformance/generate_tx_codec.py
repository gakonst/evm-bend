from pathlib import Path
s=['import Base','import ../evmword.bend as W','import ./model.bend as M','import ./codec.bend as C','import ./transaction-types.bend as T','']
records={'MaybeRead':('MR',[('value','+Maybe<W.Word>'),('reader','C.Reader')]),'AccessRead':('AR',[('value','T.Access'),('reader','C.Reader')]),'AccessesRead':('AS',[('value','+List<T.Access>'),('reader','C.Reader')]),'AuthRead':('UR',[('value','T.Authorization'),('reader','C.Reader')]),'AuthsRead':('US',[('value','+List<T.Authorization>'),('reader','C.Reader')]),'TxRead':('TR',[('value','T.Transaction'),('reader','C.Reader')])}
for typ,(cons,fields) in records.items():
 s+=['type '+typ+' is Data:','  '+cons+'{'+', '.join(n+': '+t for n,t in fields)+'}','']
 for name,ty in fields:s+=['def '+typ+'.'+name+'(x: '+typ+') -> '+ty+':','  match x:','    case '+cons+'{'+', '.join(n for n,t in fields)+'}: '+name,'']
s+=['''def optional_flag(flag: U32, r: C.Reader) -> MaybeRead:
  match flag:
    case 0: MR{None{},r}
    case 1:
      +w = C.word(r)
      MR{Some{C.WordRead.value(w)},C.WordRead.reader(w)}
    case other: MR{None{},C.R{Nil{},False{}}}

def optional(r: C.Reader) -> MaybeRead:
  +b = C.read_byte(r)
  optional_flag(C.ByteRead.value(b),C.ByteRead.reader(b))

def access(r: C.Reader) -> AccessRead:
  +a = C.word(r)
  +keys = C.words(C.WordRead.reader(a))
  AR{T.Access{C.WordRead.value(a),C.WordsRead.value(keys)},C.WordsRead.reader(keys)}

def accesses(n: Nat,r: C.Reader) -> AccessesRead:
  match n:
    case 0n: AS{Nil{},r}
    case 1n+p:
      +x = access(r)
      +tail = accesses(p,AccessRead.reader(x))
      AS{AccessRead.value(x) <> AccessesRead.value(tail),AccessesRead.reader(tail)}

def access_list(r: C.Reader) -> AccessesRead:
  +n = C.number(r)
  accesses(C.NumRead.value(n),C.NumRead.reader(n))

def auth(r: C.Reader) -> AuthRead:
  +chain = C.word(r)
  +address = C.word(C.WordRead.reader(chain))
  +nonce = C.word(C.WordRead.reader(address))
  +parity = C.number(C.WordRead.reader(nonce))
  +sig_r = C.word(C.NumRead.reader(parity))
  +sig_s = C.word(C.WordRead.reader(sig_r))
  +authority = optional(C.WordRead.reader(sig_s))
  UR{T.Auth{C.WordRead.value(chain),C.WordRead.value(address),C.WordRead.value(nonce),U32.from_nat(C.NumRead.value(parity)),C.WordRead.value(sig_r),C.WordRead.value(sig_s),MaybeRead.value(authority)},MaybeRead.reader(authority)}

def auths(n: Nat,r: C.Reader) -> AuthsRead:
  match n:
    case 0n: US{Nil{},r}
    case 1n+p:
      +x = auth(r)
      +tail = auths(p,AuthRead.reader(x))
      US{AuthRead.value(x) <> AuthsRead.value(tail),AuthsRead.reader(tail)}

def auth_list(r: C.Reader) -> AuthsRead:
  +n = C.number(r)
  auths(C.NumRead.value(n),C.NumRead.reader(n))
''']
fields=[('kind','C.read_byte','C.ByteRead'),('sender','C.word','C.WordRead'),('nonce','C.word','C.WordRead'),('gas','gas_number','C.NumRead'),('to','optional','MaybeRead'),('value','C.word','C.WordRead'),('data','C.blob','C.BytesRead'),('chainid','optional','MaybeRead'),('fee_cap','C.word','C.WordRead'),('tip','C.word','C.WordRead'),('blob_fee_cap','C.word','C.WordRead'),('blobhashes','C.words','C.WordsRead'),('access_list','access_list','AccessesRead'),('authorizations','auth_list','AuthsRead')]
s+=['def gas_number(r: C.Reader) -> C.NumRead:','  C.read_num(6n,r,0n)','', 'def transaction(r: C.Reader) -> TxRead:']
r='r'
for name,fn,typ in fields:s+=['  +'+name+' = '+fn+'('+r+')'];r=typ+'.reader('+name+')'
s+=['  TR{T.Tx{'+','.join(typ+'.value('+name+')' for name,fn,typ in fields)+'},'+r+'}','']
s+=['''type Input is Data:
  Input{tx: T.Transaction,world: M.World,context: M.Context,excess: W.Word,valid: Bool}

def decode(data: +List<U32>) -> Input:
  +ctx = C.context(C.R{data,True{}})
  +excess = C.word(C.ContextRead.reader(ctx))
  +accounts = C.accounts(C.WordRead.reader(excess))
  +tx = transaction(C.AccountsRead.reader(accounts))
  Input{TxRead.value(tx),M.World{C.AccountsRead.value(accounts),Nil{},W.zero(),Nil{}},C.ContextRead.value(ctx),C.WordRead.value(excess),C.valid(TxRead.reader(tx))}
''']
Path('full/transaction-codec.bend').write_text('\n'.join(s))
