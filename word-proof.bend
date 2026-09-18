import Base
import ./evmword.bend as E

# Every U32 embeds without truncation.
law from_u32_roundtrip:
  for x: U32
  {E.low_u32(E.from_u32(x)) == x : U32}
def from_u32_roundtrip(x):
  {==}

# Projection of addition to the low 32 bits preserves modular addition.
# This is a universal projection law, not a proof of all 256 carry bits.
law low_add:
  for x: E.Word
  for y: E.Word
  {E.low_u32(E.add(x, y)) == U32.add(E.low_u32(x), E.low_u32(y)) : U32}
def low_add(x, y):
  match x y:
    case E.W{a, b, c, d, e, f, g, h} E.W{i, j, k, l, m, n, o, p}:
      {==}
