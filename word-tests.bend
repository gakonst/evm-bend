import Base
import ./evmword.bend as E

law max_plus_one:
  {E.add(E.W{4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295}, E.from_u32(1)) == E.zero() : E.Word}
def max_plus_one():
  {==}

law carry_cascade:
  {E.add(E.W{4294967295, 4294967295, 4294967295, 0, 0, 0, 0, 0}, E.from_u32(1)) == E.W{0, 0, 0, 1, 0, 0, 0, 0} : E.Word}
def carry_cascade():
  {==}

law carry_into_wrapping_sum:
  {E.add(E.W{4294967295, 4294967295, 0, 0, 0, 0, 0, 0}, E.W{1, 4294967295, 0, 0, 0, 0, 0, 0}) == E.W{0, 4294967295, 1, 0, 0, 0, 0, 0} : E.Word}
def carry_into_wrapping_sum():
  {==}

law zero_detection:
  {E.is_zero(E.zero()) == True{} : Bool}
def zero_detection():
  {==}

law high_nonzero_detection:
  {E.is_zero(E.W{0, 0, 0, 0, 0, 0, 0, 1}) == False{} : Bool}
def high_nonzero_detection():
  {==}

def main() -> Bool:
  E.is_zero(E.add(E.W{4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295}, E.from_u32(1)))

law push_two_bytes:
  {E.shift_byte(E.shift_byte(E.zero(), 18), 52) == E.from_u32(4660) : E.Word}
def push_two_bytes():
  {==}

law push_limb_crossing:
  {E.shift_byte(E.W{4294967295, 0, 0, 0, 0, 0, 0, 0}, 18) == E.W{4294967058, 255, 0, 0, 0, 0, 0, 0} : E.Word}
def push_limb_crossing():
  {==}

law push_overflow:
  {E.shift_byte(E.W{4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295}, 255) == E.W{4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295} : E.Word}
def push_overflow():
  {==}

law diagnostic_show:
  {E.show(E.from_u32(42)) == "W{42,0,0,0,0,0,0,0}" : String}
def diagnostic_show():
  {==}
