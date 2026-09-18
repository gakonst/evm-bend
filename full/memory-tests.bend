import Base
import ./bytes.bend as B
import ./memory.bend as M
import ../evmword.bend as W

def bytes_eq(a: +List<U32>, +b: +List<U32>) -> Bool:
  match a:
    case Nil{}:
      Nat.is_eq(B.len(b), 0n)
    case Con{x, rest}:
      U32.is_eq(x, B.get(0n, b)) && Nat.is_gt(B.len(b), 0n) && bytes_eq(rest, B.drop(1n, b))

def check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def sample() -> W.Word:
  W.W{16909060, 84281096, 151653132, 219025168, 286397204, 353769240, 421141276, 488513312}

def main() -> IO(Unit):
  do IO<Unit>:
    check("bytes length/get/drop", Nat.is_eq(B.len([1, 2, 3]), 3n) && U32.is_eq(B.get(1n, [1, 258]), 2) && U32.is_eq(B.get(9n, [1]), 0) && bytes_eq(B.drop(8n, [1]), Nil{}))
    check("bytes take/slice zero fill", bytes_eq(B.take(4n, [1, 2]), [1, 2, 0, 0]) && bytes_eq(B.slice(1n, 4n, [1, 2, 3]), [2, 3, 0, 0]))
    check("bytes concat", bytes_eq(B.concat([1, 2], [3, 4]), [1, 2, 3, 4]))
    check("word roundtrip", W.eq(B.to_word(B.from_word(sample())), sample()))
    check("word endian", bytes_eq(B.take(4n, B.from_word(sample())), [29, 30, 31, 32]) && bytes_eq(B.drop(28n, B.from_word(sample())), [1, 2, 3, 4]))
    check("short word trailing zeros", W.eq(B.to_word([1]), W.W{0, 0, 0, 0, 0, 0, 0, 16777216}))
    check("empty memory zero fill", bytes_eq(M.read(M.empty(), 17n, 4n), [0, 0, 0, 0]) && Nat.is_eq(M.size(M.empty()), 0n))
    check("byte mask and expansion", U32.is_eq(M.read_byte(M.write_byte(M.empty(), 32n, 511), 32n), 255) && Nat.is_eq(M.size(M.write_byte(M.empty(), 32n, 511)), 64n))
    check("zero overwrite", U32.is_eq(M.read_byte(M.write_byte(M.write_byte(M.empty(), 1n, 7), 1n, 0), 1n), 0))
    check("overlap right", bytes_eq(M.read(M.copy(M.write(M.empty(), 0n, [1, 2, 3, 4, 5]), 1n, 0n, 4n), 0n, 5n), [1, 1, 2, 3, 4]))
    check("overlap left", bytes_eq(M.read(M.copy(M.write(M.empty(), 0n, [1, 2, 3, 4, 5]), 0n, 1n, 4n), 0n, 5n), [2, 3, 4, 5, 5]))
    check("copy source expansion", Nat.is_eq(M.size(M.copy(M.empty(), 0n, 64n, 1n)), 96n))
    check("zero length no expansion", Nat.is_eq(M.size(M.copy(M.empty(), 99n, 99n, 0n)), 0n) && Nat.is_eq(M.size(M.write(M.empty(), 99n, Nil{})), 0n))
    check("expand does not shrink", Nat.is_eq(M.size(M.expand(M.expand(M.empty(), 33n), 1n)), 64n))
    check("word memory endian", W.eq(M.load_word(M.store_word(M.empty(), 7n, sample()), 7n), sample()) && U32.is_eq(M.read_byte(M.store_word(M.empty(), 7n, sample()), 7n), 29) && U32.is_eq(M.read_byte(M.store_word(M.empty(), 7n, sample()), 38n), 4))
    check("memory cost rounding/quadratic", Nat.is_eq(M.memory_cost(0n), 0n) && Nat.is_eq(M.memory_cost(1n), 3n) && Nat.is_eq(M.memory_cost(33n), 6n) && Nat.is_eq(M.memory_cost(736n), 70n))
