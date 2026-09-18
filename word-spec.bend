import Base
import ./evmword.bend as L

# Independent fixed-width bitvector specification. Bit zero is stored first.
type Word256 is Data:
  Bits{value: Word(256n)}

def zero() -> Word256:
  Bits{Word.zero(256n)}

def add(x: Word256, y: Word256) -> Word256:
  match x y:
    case Bits{a} Bits{b}:
      Bits{Word.add(256n, a, b)}

law add_comm:
  for x: Word256
  for y: Word256
  {add(x, y) == add(y, x) : Word256}
def add_comm(x, y):
  match x y:
    case Bits{a} Bits{b}:
      Equal.cong(Word(256n), Word256, w => Bits{w}, Word.add(256n, a, b), Word.add(256n, b, a), Word.add_comm(256n, a, b))

# Concatenate low bits followed by high bits without using machine arithmetic.
def concat(n: Nat, -m: Nat, lo: Word(n), hi: Word(m)) -> Word(Nat.add(n, m)):
  match n:
    case 0n:
      hi
    case 1n+p:
      match lo:
        case WCon{bit, tail}:
          WCon{bit, concat(p, m, tail, hi)}

def prepend(-n: Nat, lo: U32, hi: Word(n)) -> Word(Nat.add(32n, n)):
  match lo:
    case U32{bits}:
      concat(32n, n, bits, hi)

# Explicit representation map for the future full refinement theorem.
def of_limbs(w: L.Word) -> Word256:
  match w:
    case L.W{a, b, c, d, e, f, g, h}:
      Bits{prepend(224n, a, prepend(192n, b, prepend(160n, c, prepend(128n, d, prepend(96n, e, prepend(64n, f, prepend(32n, g, prepend(0n, h, WNil{}))))))))}

law zero_representation:
  {of_limbs(L.zero()) == zero() : Word256}
def zero_representation():
  {==}

# OUTSTANDING, deliberately not declared as an open law:
# for x,y:L.Word, of_limbs(L.add(x,y)) == add(of_limbs(x),of_limbs(y)).
# Needed bridge lemmas:
# 1. Generalized bitvector adc returning both its low result and final carry.
# 2. adc concatenation: addition over concatenated bitvectors splits into
#    low adc and high adc supplied with the low final carry (arbitrary carry-in).
# 3. A 32-bit adc result equals U32.add(U32.add(x,y),cin), cin in {0,1}.
# 4. Final carry equals (sum(x,y)<x) OR (sum(sum(x,y),cin)<sum(x,y)).
#    This needs unsigned comparison/overflow and carry-composition lemmas.
# 5. Instantiate the split lemma seven times; discard the 256th carry.
# add_comm proves only this reference's commutativity, not L.add's refinement.
