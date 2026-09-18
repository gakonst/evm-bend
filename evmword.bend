import Base

# EVM unsigned word: a is least significant, h is most significant.
type Word is Data:
  W{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

def zero() -> Word:
  W{0, 0, 0, 0, 0, 0, 0, 0}

def from_u32(x: U32) -> Word:
  W{x, 0, 0, 0, 0, 0, 0, 0}

def low_u32(w: Word) -> U32:
  match w:
    case W{a, b, c, d, e, f, g, h}:
      a

def bit(b: Bool) -> U32:
  match b:
    case False{}:
      0
    case True{}:
      1

# Input carry is 0 or 1. Either wrapping addition produces an output carry.
def carry(+x: U32, y: U32, cin: U32) -> U32:
  +s = U32.add(x, y)
  t = U32.add(s, cin)
  bit(Bool.or(U32.is_lt(s, x), U32.is_lt(t, s)))

# The ninth carry is intentionally discarded: arithmetic is modulo 2^256.
def add(x: Word, y: Word) -> Word:
  match x y:
    case W{+a, +b, +c, +d, +e, +f, +g, h} W{+i, +j, +k, +l, +m, +n, +o, p}:
      +c0 = carry(a, i, 0)
      +c1 = carry(b, j, c0)
      +c2 = carry(c, k, c1)
      +c3 = carry(d, l, c2)
      +c4 = carry(e, m, c3)
      +c5 = carry(f, n, c4)
      c6 = carry(g, o, c5)
      W{U32.add(a, i), U32.add(U32.add(b, j), c0), U32.add(U32.add(c, k), c1), U32.add(U32.add(d, l), c2), U32.add(U32.add(e, m), c3), U32.add(U32.add(f, n), c4), U32.add(U32.add(g, o), c5), U32.add(U32.add(h, p), c6)}

def eq(x: Word, y: Word) -> Bool:
  match x y:
    case W{a, b, c, d, e, f, g, h} W{i, j, k, l, m, n, o, p}:
      U32.is_eq(a, i) && U32.is_eq(b, j) && U32.is_eq(c, k) && U32.is_eq(d, l) && U32.is_eq(e, m) && U32.is_eq(f, n) && U32.is_eq(g, o) && U32.is_eq(h, p)

def is_zero(w: Word) -> Bool:
  eq(w, zero())

# Big-endian byte folding for PUSH: (acc * 256 + (byte & 255)) mod 2^256.
def shift_byte(acc: Word, byte: U32) -> Word:
  match acc:
    case W{+a, +b, +c, +d, +e, +f, +g, h}:
      W{U32.or(U32.shln(a, 8n), U32.and(byte, 255)), U32.or(U32.shln(b, 8n), U32.shrn(a, 24n)), U32.or(U32.shln(c, 8n), U32.shrn(b, 24n)), U32.or(U32.shln(d, 8n), U32.shrn(c, 24n)), U32.or(U32.shln(e, 8n), U32.shrn(d, 24n)), U32.or(U32.shln(f, 8n), U32.shrn(e, 24n)), U32.or(U32.shln(g, 8n), U32.shrn(f, 24n)), U32.or(U32.shln(h, 8n), U32.shrn(g, 24n))}

# Stable diagnostic representation: decimal limbs, least significant first.
def show(w: Word) -> String:
  match w:
    case W{a, b, c, d, e, f, g, h}:
      "W{" ++ U32.show(a) ++ "," ++ U32.show(b) ++ "," ++ U32.show(c) ++ "," ++ U32.show(d) ++ "," ++ U32.show(e) ++ "," ++ U32.show(f) ++ "," ++ U32.show(g) ++ "," ++ U32.show(h) ++ "}"
