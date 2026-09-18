import Base
import ../evmword.bend as W
import ./model.bend as M

type Reader is Data:
  R{data: +List<U32>, ok: Bool}

type ByteRead is Data:
  BR{value: U32, reader: Reader}

def ByteRead.value(r: ByteRead) -> U32:
  match r:
    case BR{value, reader}:
      value

def ByteRead.reader(r: ByteRead) -> Reader:
  match r:
    case BR{value, reader}:
      reader

type NumRead is Data:
  NR{value: Nat, reader: Reader}

def NumRead.value(r: NumRead) -> Nat:
  match r:
    case NR{value, reader}:
      value

def NumRead.reader(r: NumRead) -> Reader:
  match r:
    case NR{value, reader}:
      reader

type WordRead is Data:
  WR{value: W.Word, reader: Reader}

def WordRead.value(r: WordRead) -> W.Word:
  match r:
    case WR{value, reader}:
      value

def WordRead.reader(r: WordRead) -> Reader:
  match r:
    case WR{value, reader}:
      reader

type BytesRead is Data:
  BS{value: +List<U32>, reader: Reader}

def BytesRead.value(r: BytesRead) -> +List<U32>:
  match r:
    case BS{value, reader}:
      value

def BytesRead.reader(r: BytesRead) -> Reader:
  match r:
    case BS{value, reader}:
      reader

type WordsRead is Data:
  WS{value: +List<W.Word>, reader: Reader}

def WordsRead.value(r: WordsRead) -> +List<W.Word>:
  match r:
    case WS{value, reader}:
      value

def WordsRead.reader(r: WordsRead) -> Reader:
  match r:
    case WS{value, reader}:
      reader

type SlotsRead is Data:
  SS{value: +List<M.Slot>, reader: Reader}

def SlotsRead.value(r: SlotsRead) -> +List<M.Slot>:
  match r:
    case SS{value, reader}:
      value

def SlotsRead.reader(r: SlotsRead) -> Reader:
  match r:
    case SS{value, reader}:
      reader

type HashesRead is Data:
  HS{value: +List<M.BlockHash>, reader: Reader}

def HashesRead.value(r: HashesRead) -> +List<M.BlockHash>:
  match r:
    case HS{value, reader}:
      value

def HashesRead.reader(r: HashesRead) -> Reader:
  match r:
    case HS{value, reader}:
      reader

type ContextRead is Data:
  CR{value: M.Context, reader: Reader}

def ContextRead.value(r: ContextRead) -> M.Context:
  match r:
    case CR{value, reader}:
      value

def ContextRead.reader(r: ContextRead) -> Reader:
  match r:
    case CR{value, reader}:
      reader

type AccountRead is Data:
  AR{value: M.Account, reader: Reader}

def AccountRead.value(r: AccountRead) -> M.Account:
  match r:
    case AR{value, reader}:
      value

def AccountRead.reader(r: AccountRead) -> Reader:
  match r:
    case AR{value, reader}:
      reader

type AccountsRead is Data:
  AS{value: +List<M.Account>, reader: Reader}

def AccountsRead.value(r: AccountsRead) -> +List<M.Account>:
  match r:
    case AS{value, reader}:
      value

def AccountsRead.reader(r: AccountsRead) -> Reader:
  match r:
    case AS{value, reader}:
      reader

type EngineRead is Data:
  ER{value: M.Engine, reader: Reader}

def EngineRead.value(r: EngineRead) -> M.Engine:
  match r:
    case ER{value, reader}:
      value

def EngineRead.reader(r: EngineRead) -> Reader:
  match r:
    case ER{value, reader}:
      reader

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

def context(r: Reader) -> ContextRead:
  +v0 = word(r)
  +v1 = word(WordRead.reader(v0))
  +v2 = word(WordRead.reader(v1))
  +v3 = word(WordRead.reader(v2))
  +v4 = word(WordRead.reader(v3))
  +v5 = word(WordRead.reader(v4))
  +v6 = word(WordRead.reader(v5))
  +v7 = word(WordRead.reader(v6))
  +v8 = word(WordRead.reader(v7))
  +v9 = word(WordRead.reader(v8))
  +v10 = word(WordRead.reader(v9))
  +blobs = words(WordRead.reader(v10))
  +blocks = hashes(WordsRead.reader(blobs))
  CR{M.Ctx{WordRead.value(v0), WordRead.value(v1), WordRead.value(v2), WordRead.value(v3), WordRead.value(v4), WordRead.value(v5), WordRead.value(v6), WordRead.value(v7), WordRead.value(v8), WordRead.value(v9), WordRead.value(v10), WordsRead.value(blobs), HashesRead.value(blocks)}, HashesRead.reader(blocks)}

def account(r: Reader) -> AccountRead:
  +address = word(r)
  +balance = word(WordRead.reader(address))
  +nonce = word(WordRead.reader(balance))
  +code = blob(WordRead.reader(nonce))
  +storage = slots(BytesRead.reader(code))
  +original = slots(SlotsRead.reader(storage))
  +transient = slots(SlotsRead.reader(original))
  +warm = read_byte(SlotsRead.reader(transient))
  +exists = read_byte(ByteRead.reader(warm))
  +created = read_byte(ByteRead.reader(exists))
  +keys = words(ByteRead.reader(created))
  AR{M.Account{WordRead.value(address), WordRead.value(balance), WordRead.value(nonce), BytesRead.value(code), SlotsRead.value(storage), SlotsRead.value(original), SlotsRead.value(transient), as_bool(ByteRead.value(warm)), as_bool(ByteRead.value(exists)), as_bool(ByteRead.value(created)), WordsRead.value(keys)}, WordsRead.reader(keys)}

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

def engine(r: Reader) -> EngineRead:
  +gas = number(r)
  +reservoir = number(NumRead.reader(gas))
  +code = blob(NumRead.reader(reservoir))
  +input = blob(BytesRead.reader(code))
  +address = word(BytesRead.reader(input))
  +caller = word(WordRead.reader(address))
  +value = word(WordRead.reader(caller))
  +static = read_byte(WordRead.reader(value))
  +ctx = context(ByteRead.reader(static))
  +world = accounts(ContextRead.reader(ctx))
  ER{M.Engine{M.Frame.set_is_static(M.initial_frame(BytesRead.value(code), NumRead.value(gas), BytesRead.value(input), WordRead.value(address), WordRead.value(caller), WordRead.value(value)), as_bool(ByteRead.value(static))), M.World{AccountsRead.value(world), Nil{}, W.zero(), Nil{}}, ContextRead.value(ctx), NumRead.value(reservoir), W.zero(), 0n}, AccountsRead.reader(world)}

def valid(r: Reader) -> Bool:
  match r:
    case R{Nil{}, ok}:
      ok
    case R{Con{b, rest}, ok}:
      False{}

def decode(data: +List<U32>) -> EngineRead:
  engine(R{data, True{}})
