import Base
import ./evmword.bend as W
import ./core.bend as E

# PUSH payload is big-endian; missing bytes at EOF are zero.
def payload(width: Nat, code: +List<U32>, acc: W.Word) -> W.Word & +List<U32>:
  match width:
    case 0n:
      (acc, code)
    case 1n+p:
      match code:
        case Nil{}:
          payload(p, Nil{}, W.shift_byte(acc, 0))
        case Con{b, rest}:
          payload(p, rest, W.shift_byte(acc, b))

def pack_push(width: Nat, p: W.Word & +List<U32>) -> E.Op & +List<U32>:
  match p:
    case (value, rest):
      (E.Push{width, value}, rest)


def push_range(is_push: Bool, +b: U32, code: +List<U32>) -> E.Op & +List<U32>:
  match is_push:
    case False{}:
      (E.Unsupported{b}, code)
    case True{}:
      +width = U32.to_nat((b - 95 : U32))
      pack_push(width, payload(width, code, W.zero()))

def opcode(+b: U32, code: +List<U32>) -> E.Op & +List<U32>:
  match b:
    case 0:
      (E.Stop{}, code)
    case 1:
      (E.Add{}, code)
    case 80:
      (E.Pop{}, code)
    case 95:
      (E.Push{0n, W.zero()}, code)
    case 254:
      (E.Invalid{}, code)
    case other:
      push_range(Bool.and(U32.is_ge(other, 96), U32.is_le(other, 127)), other, code)

def next(code: +List<U32>) -> E.Op & +List<U32>:
  match code:
    case Nil{}:
      (E.Stop{}, Nil{})
    case Con{b, rest}:
      opcode(b, rest)
