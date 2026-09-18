import Base
import ../evmword.bend as W
import ./model.bend as M
import ./codec.bend as C
import ./transaction-types.bend as T
import ./transaction-wide.bend as Wide

type MaybeRead is Data:
  MR{value: +Maybe<W.Word>, reader: C.Reader}

def MaybeRead.value(x: MaybeRead) -> +Maybe<W.Word>:
  match x:
    case MR{value, reader}: value

def MaybeRead.reader(x: MaybeRead) -> C.Reader:
  match x:
    case MR{value, reader}: reader

type AccessRead is Data:
  AR{value: T.Access, reader: C.Reader}

def AccessRead.value(x: AccessRead) -> T.Access:
  match x:
    case AR{value, reader}: value

def AccessRead.reader(x: AccessRead) -> C.Reader:
  match x:
    case AR{value, reader}: reader

type AccessesRead is Data:
  AS{value: +List<T.Access>, reader: C.Reader}

def AccessesRead.value(x: AccessesRead) -> +List<T.Access>:
  match x:
    case AS{value, reader}: value

def AccessesRead.reader(x: AccessesRead) -> C.Reader:
  match x:
    case AS{value, reader}: reader

type AuthRead is Data:
  UR{value: T.Authorization, reader: C.Reader}

def AuthRead.value(x: AuthRead) -> T.Authorization:
  match x:
    case UR{value, reader}: value

def AuthRead.reader(x: AuthRead) -> C.Reader:
  match x:
    case UR{value, reader}: reader

type AuthsRead is Data:
  US{value: +List<T.Authorization>, reader: C.Reader}

def AuthsRead.value(x: AuthsRead) -> +List<T.Authorization>:
  match x:
    case US{value, reader}: value

def AuthsRead.reader(x: AuthsRead) -> C.Reader:
  match x:
    case US{value, reader}: reader

type TxRead is Data:
  TR{value: Wide.Transaction, reader: C.Reader}

def TxRead.value(x: TxRead) -> Wide.Transaction:
  match x:
    case TR{value, reader}: value

def TxRead.reader(x: TxRead) -> C.Reader:
  match x:
    case TR{value, reader}: reader

def optional_flag(flag: U32, r: C.Reader) -> MaybeRead:
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

def gas_number(r: C.Reader) -> C.NumRead:
  C.read_num(6n,r,0n)

def transaction(r: C.Reader) -> TxRead:
  +kind = C.read_byte(r)
  +sender = C.word(C.ByteRead.reader(kind))
  +nonce = C.word(C.WordRead.reader(sender))
  +gas = C.word(C.WordRead.reader(nonce))
  +to = optional(C.WordRead.reader(gas))
  +value = C.word(MaybeRead.reader(to))
  +data = C.blob(C.WordRead.reader(value))
  +chainid = optional(C.BytesRead.reader(data))
  +fee_cap = C.word(MaybeRead.reader(chainid))
  +tip = C.word(C.WordRead.reader(fee_cap))
  +blob_fee_cap = C.word(C.WordRead.reader(tip))
  +blobhashes = C.words(C.WordRead.reader(blob_fee_cap))
  +access_list = access_list(C.WordsRead.reader(blobhashes))
  +authorizations = auth_list(AccessesRead.reader(access_list))
  TR{Wide.WideTx{T.Tx{C.ByteRead.value(kind),C.WordRead.value(sender),C.WordRead.value(nonce),0n,MaybeRead.value(to),C.WordRead.value(value),C.BytesRead.value(data),MaybeRead.value(chainid),C.WordRead.value(fee_cap),C.WordRead.value(tip),C.WordRead.value(blob_fee_cap),C.WordsRead.value(blobhashes),AccessesRead.value(access_list),AuthsRead.value(authorizations)},C.WordRead.value(gas)},AuthsRead.reader(authorizations)}

type Input is Data:
  Input{tx: Wide.Transaction,world: M.World,context: M.Context,excess: W.Word,valid: Bool}

def decode(data: +List<U32>) -> Input:
  +ctx = C.context(C.R{data,True{}})
  +excess = C.word(C.ContextRead.reader(ctx))
  +accounts = C.accounts(C.WordRead.reader(excess))
  +tx = transaction(C.AccountsRead.reader(accounts))
  Input{TxRead.value(tx),M.World{C.AccountsRead.value(accounts),Nil{},W.zero(),Nil{}},C.ContextRead.value(ctx),C.WordRead.value(excess),C.valid(TxRead.reader(tx))}
