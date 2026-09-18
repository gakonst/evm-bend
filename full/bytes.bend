import Base
import ../evmword.bend as W

# Byte vectors use reusable lists of U32 values in [0,255]. Word conversion
# and element reads mask to eight bits. take/slice zero-pad; drop never pads.
# Tail recursion keeps valid 64/128 KiB code lengths safe on the JS backend.
def len_acc(bytes: +List<U32>, count: Nat) -> Nat:
  match bytes:
    case Nil{}:
      count
    case Con{byte, rest}:
      len_acc(rest, Nat.add(count, 1n))

def len(bytes: +List<U32>) -> Nat:
  len_acc(bytes, 0n)

def head(bytes: +List<U32>) -> U32:
  match bytes:
    case Nil{}:
      0
    case Con{b, rest}:
      U32.and(b, 255)

def drop(count: Nat, bytes: +List<U32>) -> +List<U32>:
  match count:
    case 0n:
      bytes
    case 1n+p:
      match bytes:
        case Nil{}:
          Nil{}
        case Con{b, rest}:
          drop(p, rest)

def get(index: Nat, bytes: +List<U32>) -> U32:
  head(drop(index, bytes))

def take(count: Nat, bytes: +List<U32>) -> +List<U32>:
  match count:
    case 0n:
      Nil{}
    case 1n+p:
      match bytes:
        case Nil{}:
          0 <> take(p, Nil{})
        case Con{b, rest}:
          U32.and(b, 255) <> take(p, rest)

def slice(offset: Nat, count: Nat, bytes: +List<U32>) -> +List<U32>:
  take(count, drop(offset, bytes))

def concat(a: +List<U32>, b: +List<U32>) -> +List<U32>:
  match a:
    case Nil{}:
      b
    case Con{x, rest}:
      U32.and(x, 255) <> concat(rest, b)

# Exactly 32 bytes are folded big-endian; a short vector has trailing zero bytes.
# Bytes beyond the first 32 are ignored.
def fold_word(count: Nat, bytes: +List<U32>, acc: W.Word) -> W.Word:
  match count:
    case 0n:
      acc
    case 1n+p:
      match bytes:
        case Nil{}:
          fold_word(p, Nil{}, W.shift_byte(acc, 0))
        case Con{b, rest}:
          fold_word(p, rest, W.shift_byte(acc, b))

def to_word(bytes: +List<U32>) -> W.Word:
  fold_word(32n, bytes, W.zero())

def limb_bytes(+x: U32, rest: +List<U32>) -> +List<U32>:
  U32.shrn(x, 24n) <> U32.and(U32.shrn(x, 16n), 255) <> U32.and(U32.shrn(x, 8n), 255) <> U32.and(x, 255) <> rest

def from_word(word: W.Word) -> +List<U32>:
  match word:
    case W.W{a, b, c, d, e, f, g, h}:
      limb_bytes(h, limb_bytes(g, limb_bytes(f, limb_bytes(e, limb_bytes(d, limb_bytes(c, limb_bytes(b, limb_bytes(a, Nil{}))))))))
