import Base
import ./evmword.bend as L
import ./word-spec.bend as S

# EVM operand convention: arithmetic a op b; for shifts/byte/signextend the
# first argument is the shift count / index (the top stack item).
def bits_done(s: S.Word256) -> Word(256n):
  match s:
    case S.Bits{v}:
      v

def bits(w: L.Word) -> Word(256n):
  bits_done(S.of_limbs(w))

def low(n: Nat, -m: Nat, w: Word(Nat.add(n,m))) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      match w:
        case WCon{b,t}:
          WCon{b, low(p,m,t)}

def high(n: Nat, -m: Nat, w: Word(Nat.add(n,m))) -> Word(m):
  match n:
    case 0n:
      w
    case 1n+p:
      match w:
        case WCon{b,t}:
          high(p,m,t)

def of_bits(+v: Word(256n)) -> L.Word:
  +r1 = high(32n,224n,v)
  +r2 = high(32n,192n,r1)
  +r3 = high(32n,160n,r2)
  +r4 = high(32n,128n,r3)
  +r5 = high(32n,96n,r4)
  +r6 = high(32n,64n,r5)
  r7 = high(32n,32n,r6)
  L.W{U32{low(32n,224n,v)}, U32{low(32n,192n,r1)}, U32{low(32n,160n,r2)}, U32{low(32n,128n,r3)}, U32{low(32n,96n,r4)}, U32{low(32n,64n,r5)}, U32{low(32n,32n,r6)}, U32{r7}}

def sub(a: L.Word,b: L.Word) -> L.Word:
  of_bits(Word.sub(256n,bits(a),bits(b)))

def mul(a: L.Word,b: L.Word) -> L.Word:
  of_bits(Word.mul(256n,bits(a),bits(b)))

# Unsigned lexicographic comparison of the eight native 32-bit limbs.
# The most significant unequal limb decides; no 256-node bitvector is built.
def lt_limb(+a: U32,+b: U32,lower: Bool) -> Bool:
  Bool.or(U32.is_lt(a,b),Bool.and(U32.is_eq(a,b),lower))

def lt(a: L.Word,b: L.Word) -> Bool:
  match a b:
    case L.W{a,b,c,d,e,f,g,h} L.W{i,j,k,l,m,n,o,p}:
      lt_limb(h,p,lt_limb(g,o,lt_limb(f,n,lt_limb(e,m,lt_limb(d,l,lt_limb(c,k,lt_limb(b,j,U32.is_lt(a,i))))))))

def gt(a: L.Word,b: L.Word) -> Bool:
  lt(b,a)

def negative(w: L.Word) -> Bool:
  match w:
    case L.W{a,b,c,d,e,f,g,h}:
      U32.is_ge(h,2147483648)

def neg(w: L.Word) -> L.Word:
  sub(L.zero(),w)

def signed_lt(+a: L.Word,+b: L.Word, sa: Bool,sb: Bool) -> Bool:
  match sa sb:
    case False{} False{}:
      lt(a,b)
    case True{} True{}:
      lt(a,b)
    case True{} False{}:
      True{}
    case False{} True{}:
      False{}

def slt(+a: L.Word,+b: L.Word) -> Bool:
  signed_lt(a,b,negative(a),negative(b))

def sgt(a: L.Word,b: L.Word) -> Bool:
  slt(b,a)

def abs_if(w: L.Word,s: Bool) -> L.Word:
  match s:
    case True{}:
      neg(w)
    case False{}:
      w

def abs(+w: L.Word) -> L.Word:
  abs_if(w,negative(w))

# Long division visits numerator bits from most to least significant.
# Remainder has 256 bits; shifted-out carry is retained for the subtraction test.
law divide_go:
  for n: Nat
  for a: Word(n)
  for +b: Word(256n)
  Word(n) & Word(256n)

def divide_fin(-n: Nat,q: Word(n),s: Word(256n),b: Word(256n),take: Bool) -> Word(1n+n) & Word(256n):
  match take:
    case True{}:
      (WCon{True{},q},Word.sub(256n,s,b))
    case False{}:
      (WCon{False{},q},s)

def divide_shift(-n: Nat,q: Word(n),+b: Word(256n),sr: Bool & Word(256n)) -> Word(1n+n) & Word(256n):
  match sr:
    case (out,+s):
      divide_fin(n,q,s,b,Bool.or(out,Cmp.is_ge(Word.cmp(256n,s,b))))

def divide_rec(-n: Nat,bit: Bool,+b: Word(256n),qr: Word(n) & Word(256n)) -> Word(1n+n) & Word(256n):
  match qr:
    case (q,r):
      divide_shift(n,q,b,Word.shl.out(256n,bit,r))

def divide_go(n,a,b):
  match n:
    case 0n:
      (WNil{},Word.zero(256n))
    case 1n+p:
      match a:
        case WCon{bit,tail}:
          divide_rec(p,bit,b,divide_go(p,tail,b))

def quotient(qr: Word(256n) & Word(256n)) -> L.Word:
  match qr:
    case (q,r):
      of_bits(q)

def remainder(-n: Nat,qr: Word(n) & Word(256n)) -> L.Word:
  match qr:
    case (q,r):
      of_bits(r)

def div_if(a: L.Word,b: L.Word,z: Bool) -> L.Word:
  match z:
    case True{}:
      L.zero()
    case False{}:
      quotient(divide_go(256n,bits(a),bits(b)))

def div(a: L.Word,+b: L.Word) -> L.Word:
  div_if(a,b,L.is_zero(b))

def mod_if(a: L.Word,b: L.Word,z: Bool) -> L.Word:
  match z:
    case True{}:
      L.zero()
    case False{}:
      remainder(256n,divide_go(256n,bits(a),bits(b)))

def mod(a: L.Word,+b: L.Word) -> L.Word:
  mod_if(a,b,L.is_zero(b))

def sdiv(+a: L.Word,+b: L.Word) -> L.Word:
  abs_if(div(abs(a),abs(b)),Bool.xor(negative(a),negative(b)))

def smod(+a: L.Word,b: L.Word) -> L.Word:
  abs_if(mod(abs(a),abs(b)),negative(a))

def addmod_if(a: L.Word,b: L.Word,m: L.Word,z: Bool) -> L.Word:
  match z:
    case True{}:
      L.zero()
    case False{}:
      x = S.concat(256n,1n,bits(a),WCon{False{},WNil{}})
      y = S.concat(256n,1n,bits(b),WCon{False{},WNil{}})
      remainder(257n,divide_go(257n,Word.add(257n,x,y),bits(m)))

def addmod(a: L.Word,b: L.Word,+m: L.Word) -> L.Word:
  addmod_if(a,b,m,L.is_zero(m))

def mulmod_if(a: L.Word,b: L.Word,m: L.Word,z: Bool) -> L.Word:
  match z:
    case True{}:
      L.zero()
    case False{}:
      x = S.concat(256n,256n,bits(a),Word.zero(256n))
      y = S.concat(256n,256n,bits(b),Word.zero(256n))
      remainder(512n,divide_go(512n,Word.mul(512n,x,y),bits(m)))

def mulmod(a: L.Word,b: L.Word,+m: L.Word) -> L.Word:
  mulmod_if(a,b,m,L.is_zero(m))

# Exponentiation by squaring consumes the exponent's 256 bits.
def exp_go(n: Nat,e: Word(n),+base: L.Word,acc: L.Word) -> L.Word:
  match n:
    case 0n:
      acc
    case 1n+p:
      match e:
        case WCon{False{},tail}:
          exp_go(p,tail,mul(base,base),acc)
        case WCon{True{},tail}:
          exp_go(p,tail,mul(base,base),mul(acc,base))

def exp(base: L.Word,exponent: L.Word) -> L.Word:
  exp_go(256n,bits(exponent),base,L.from_u32(1))

# Bitwise operations act independently on each limb.
def and(x: L.Word,y: L.Word) -> L.Word:
  match x y:
    case L.W{a,b,c,d,e,f,g,h} L.W{i,j,k,l,m,n,o,p}:
      L.W{U32.and(a,i),U32.and(b,j),U32.and(c,k),U32.and(d,l),U32.and(e,m),U32.and(f,n),U32.and(g,o),U32.and(h,p)}

def or(x: L.Word,y: L.Word) -> L.Word:
  match x y:
    case L.W{a,b,c,d,e,f,g,h} L.W{i,j,k,l,m,n,o,p}:
      L.W{U32.or(a,i),U32.or(b,j),U32.or(c,k),U32.or(d,l),U32.or(e,m),U32.or(f,n),U32.or(g,o),U32.or(h,p)}

def xor(x: L.Word,y: L.Word) -> L.Word:
  match x y:
    case L.W{a,b,c,d,e,f,g,h} L.W{i,j,k,l,m,n,o,p}:
      L.W{U32.xor(a,i),U32.xor(b,j),U32.xor(c,k),U32.xor(d,l),U32.xor(e,m),U32.xor(f,n),U32.xor(g,o),U32.xor(h,p)}

def not(x: L.Word) -> L.Word:
  match x:
    case L.W{a,b,c,d,e,f,g,h}:
      L.W{U32.not(a),U32.not(b),U32.not(c),U32.not(d),U32.not(e),U32.not(f),U32.not(g),U32.not(h)}

def iszero(w: L.Word) -> Bool:
  L.is_zero(w)

def bool_word(b: Bool) -> L.Word:
  L.from_u32(Bool.to_u32(b))

def ones() -> L.Word:
  L.W{4294967295,4294967295,4294967295,4294967295,4294967295,4294967295,4294967295,4294967295}

def shr1(x: L.Word) -> L.Word:
  match x:
    case L.W{a,+b,+c,+d,+e,+f,+g,+h}:
      L.W{U32.or(U32.shr(a),U32.shln(b,31n)),U32.or(U32.shr(b),U32.shln(c,31n)),U32.or(U32.shr(c),U32.shln(d,31n)),U32.or(U32.shr(d),U32.shln(e,31n)),U32.or(U32.shr(e),U32.shln(f,31n)),U32.or(U32.shr(f),U32.shln(g,31n)),U32.or(U32.shr(g),U32.shln(h,31n)),U32.shr(h)}

def sar1(x: L.Word) -> L.Word:
  match x:
    case L.W{a,+b,+c,+d,+e,+f,+g,+h}:
      L.W{U32.or(U32.shr(a),U32.shln(b,31n)),U32.or(U32.shr(b),U32.shln(c,31n)),U32.or(U32.shr(c),U32.shln(d,31n)),U32.or(U32.shr(d),U32.shln(e,31n)),U32.or(U32.shr(e),U32.shln(f,31n)),U32.or(U32.shr(f),U32.shln(g,31n)),U32.or(U32.shr(g),U32.shln(h,31n)),U32.or(U32.shr(h),U32.and(h,2147483648))}

def shl_count(n: Nat,+x: L.Word) -> L.Word:
  match n:
    case 0n:
      x
    case 1n+p:
      shl_count(p,L.add(x,x))

def shr_count(n: Nat,x: L.Word) -> L.Word:
  match n:
    case 0n:
      x
    case 1n+p:
      shr_count(p,shr1(x))

def sar_count(n: Nat,x: L.Word) -> L.Word:
  match n:
    case 0n:
      x
    case 1n+p:
      sar_count(p,sar1(x))

def shl_if(count: L.Word,x: L.Word,small: Bool) -> L.Word:
  match small:
    case False{}:
      L.zero()
    case True{}:
      shl_count(U32.to_nat(L.low_u32(count)),x)

def shr_if(count: L.Word,x: L.Word,small: Bool) -> L.Word:
  match small:
    case False{}:
      L.zero()
    case True{}:
      shr_count(U32.to_nat(L.low_u32(count)),x)

def sign_fill(s: Bool) -> L.Word:
  match s:
    case False{}:
      L.zero()
    case True{}:
      ones()

def sar_if(count: L.Word,x: L.Word,small: Bool) -> L.Word:
  match small:
    case False{}:
      sign_fill(negative(x))
    case True{}:
      sar_count(U32.to_nat(L.low_u32(count)),x)

def shl(+count: L.Word,x: L.Word) -> L.Word:
  shl_if(count,x,lt(count,L.from_u32(256)))

def shr(+count: L.Word,x: L.Word) -> L.Word:
  shr_if(count,x,lt(count,L.from_u32(256)))

def sar(+count: L.Word,x: L.Word) -> L.Word:
  sar_if(count,x,lt(count,L.from_u32(256)))

def byte_if(index: L.Word,x: L.Word,small: Bool) -> L.Word:
  match small:
    case False{}:
      L.zero()
    case True{}:
      n = U32.to_nat(U32.mul(U32.sub(31,L.low_u32(index)),8))
      L.from_u32(U32.and(L.low_u32(shr_count(n,x)),255))

def byte(+index: L.Word,x: L.Word) -> L.Word:
  byte_if(index,x,lt(index,L.from_u32(32)))

def signextend_fin(x: L.Word,mask: L.Word,s: Bool) -> L.Word:
  match s:
    case False{}:
      and(x,mask)
    case True{}:
      or(x,not(mask))

def signextend_if(index: L.Word,+x: L.Word,small: Bool) -> L.Word:
  match small:
    case False{}:
      x
    case True{}:
      +n = U32.mul(U32.add(L.low_u32(index),1),8)
      mask = shr_count(U32.to_nat(U32.sub(256,n)),ones())
      s = U32.is_ne(U32.and(L.low_u32(shr_count(U32.to_nat(U32.sub(n,1)),x)),1),0)
      signextend_fin(x,mask,s)

def signextend(+index: L.Word,x: L.Word) -> L.Word:
  signextend_if(index,x,lt(index,L.from_u32(32)))

# Bend runtime Nat is bounded by 2^48-1. Every runtime Nat embeds exactly.
# to_nat deliberately extracts the low 48 bits; fits_nat checks exactness.
def radix32() -> Nat:
  Nat.add(U32.to_nat(4294967295),1n)

def from_nat(+n: Nat) -> L.Word:
  L.W{U32.from_nat(n),U32.from_nat(Nat.div(n,radix32())),0,0,0,0,0,0}

def fits_nat(w: L.Word) -> Bool:
  match w:
    case L.W{a,b,c,d,e,f,g,h}:
      U32.is_le(b,65535) && U32.is_zero(c) && U32.is_zero(d) && U32.is_zero(e) && U32.is_zero(f) && U32.is_zero(g) && U32.is_zero(h)

def nat_overflow(w: L.Word) -> Bool:
  Bool.not(fits_nat(w))

def nat_low(w: L.Word) -> Nat:
  match w:
    case L.W{a,b,c,d,e,f,g,h}:
      Nat.add(U32.to_nat(a),Nat.mul(U32.to_nat(U32.and(b,65535)),radix32()))

def to_nat_if(w: L.Word,ok: Bool) -> Maybe<&2,Nat>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{nat_low(w)}

def checked_to_nat(+w: L.Word) -> Maybe<&2,Nat>:
  to_nat_if(w,fits_nat(w))

def to_nat(w: L.Word) -> Nat:
  nat_low(w)

def bit_and(a: L.Word,b: L.Word) -> L.Word:
  and(a,b)

def bit_or(a: L.Word,b: L.Word) -> L.Word:
  or(a,b)

def bit_xor(a: L.Word,b: L.Word) -> L.Word:
  xor(a,b)

def bit_not(a: L.Word) -> L.Word:
  not(a)

# Count from the most significant bit, returning 256 for zero.
def clz_inc(n: Nat,same: Bool) -> Nat:
  match same:
    case True{}:
      1n+n
    case False{}:
      n

def clz_step(+n: Nat,b: Bool,+tail_count: Nat) -> Nat:
  match b:
    case True{}:
      tail_count
    case False{}:
      clz_inc(tail_count,Nat.is_eq(n,tail_count))

def clz_go(n: Nat,w: Word(n)) -> Nat:
  match n:
    case 0n:
      0n
    case 1n++p:
      match w:
        case WCon{b,t}:
          clz_step(p,b,clz_go(p,t))

def clz(w: L.Word) -> L.Word:
  from_nat(clz_go(256n,bits(w)))
