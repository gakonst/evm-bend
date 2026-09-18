import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ../word-spec.bend as S

# Full-width product before division. A result beyond a 256-bit context word
# is a host/environment error, never an EVM exceptional halt.
def quotient_fits(ok: Bool,q: Word(512n)) -> +Maybe<W.Word>:
  match ok:
    case True{}: Some{O.of_bits(O.low(256n,256n,q))}
    case False{}: None{}

def quotient_checked(qr: Word(512n) & Word(256n)) -> +Maybe<W.Word>:
  match qr:
    case (+q,r):
      quotient_fits(Cmp.is_eq(Word.cmp(256n,O.high(256n,256n,q),Word.zero(256n))),q)

def muldiv(a: W.Word,b: W.Word,d: W.Word) -> +Maybe<W.Word>:
  x = S.concat(256n,256n,O.bits(a),Word.zero(256n))
  y = S.concat(256n,256n,O.bits(b),Word.zero(256n))
  quotient_checked(O.divide_go(512n,Word.mul(512n,x,y),O.bits(d)))

type Progress is Data:
  EnvDone{value: +Maybe<W.Word>}
  EnvContinue{numerator: W.Word,denominator: W.Word,index: Nat,acc: W.Word,output: W.Word}

def next(value: +Maybe<W.Word>,numerator: W.Word,denominator: W.Word,index: Nat,output: W.Word) -> Progress:
  match value:
    case None{}: EnvDone{None{}}
    case Some{acc}: EnvContinue{numerator,denominator,index,acc,output}

def step(overflow: Bool,+numerator: W.Word,+denominator: W.Word,+index: Nat,acc: W.Word,output: W.Word) -> Progress:
  match overflow:
    case True{}: EnvDone{None{}}
    case False{}: next(muldiv(acc,numerator,O.mul(denominator,O.from_nat(index))),numerator,denominator,1n+index,output)

def nonzero(zero: Bool,numerator: W.Word,+denominator: W.Word,index: Nat,+acc: W.Word,+output: W.Word) -> Progress:
  match zero:
    case True{}: EnvDone{Some{O.div(output,denominator)}}
    case False{}:
      +sum = W.add(output,acc)
      step(O.lt(sum,output),numerator,denominator,index,acc,sum)

def loop(fuel: Nat,progress: Progress) -> +Maybe<W.Word>:
  match fuel:
    case 0n: None{}
    case 1n+p:
      match progress:
        case EnvDone{value}: value
        case EnvContinue{numerator,denominator,index,+acc,output}:
          loop(p,nonzero(W.is_zero(acc),numerator,denominator,index,acc,output))

def blobbasefee(excess: W.Word) -> +Maybe<W.Word>:
  loop(U32.to_nat(4096),EnvContinue{excess,W.from_u32(11684671),1n,W.from_u32(11684671),W.zero()})
