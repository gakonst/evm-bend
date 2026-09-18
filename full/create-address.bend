import Base
import ../evmword.bend as W
import ./bytes.bend as B
import ./keccak.bend as K
import ./world.bend as World

# RLP uses minimal big-endian integers; nonce zero is the empty string.
def trim_zero(bytes: +List<U32>) -> +List<U32>:
  match bytes:
    case Nil{}: Nil{}
    case Con{b,rest}:
      match b:
        case 0: trim_zero(rest)
        case other: other <> rest

def nonce_short(single: Bool, +bytes: +List<U32>) -> +List<U32>:
  match single:
    case True{}: bytes
    case False{}: U32.add(128,U32.from_nat(B.len(bytes))) <> bytes

def nonce(+word: W.Word) -> +List<U32>:
  +bytes = trim_zero(B.from_word(word))
  nonce_short(Bool.and(Nat.is_eq(B.len(bytes),1n),U32.is_lt(B.head(bytes),128)),bytes)

def create(sender: W.Word, n: W.Word) -> W.Word:
  +payload = B.concat(148 <> B.drop(12n,B.from_word(sender)),nonce(n))
  World.normalize_address(K.hash(U32.add(192,U32.from_nat(B.len(payload))) <> payload))

def create2(sender: W.Word, salt: W.Word, initcode: +List<U32>) -> W.Word:
  World.normalize_address(K.hash(255 <> B.concat(B.drop(12n,B.from_word(sender)),B.concat(B.from_word(salt),B.from_word(K.hash(initcode))))))
