import Base
import ../evmword.bend as W
import ./bytes.bend as B

# Pure sparse byte memory. Only nonzero cells are stored; each index is unique.
# The caller validates Nat offsets and gas before memory access. Reading does
# not expand memory; writes and explicit expansion round active size to 32 bytes.
type Cell is Data:
  C{index: Nat, byte: U32}

type Mem is Data:
  M{active: Nat, cells: +List<Cell>}

def empty() -> Mem:
  M{0n, Nil{}}

def size(mem: Mem) -> Nat:
  match mem:
    case M{active, cells}:
      active

# ceil(bytes / 32), without an overflowing bytes + 31 intermediate.
def words(+bytes: Nat) -> Nat:
  Nat.add(Nat.div(bytes,32n),Nat.div(Nat.add(Nat.mod(bytes,32n),31n),32n))

def rounded(bytes: Nat) -> Nat:
  Nat.mul(words(bytes), 32n)

def memory_cost(new_bytes: Nat) -> Nat:
  +n = words(new_bytes)
  Nat.add(Nat.mul(3n, n), Nat.div(Nat.mul(n, n), 512n))

def maximum_choice(larger: Bool, a: Nat, b: Nat) -> Nat:
  match larger:
    case True{}:
      a
    case False{}:
      b

def maximum(+a: Nat, +b: Nat) -> Nat:
  maximum_choice(Nat.is_ge(a, b), a, b)

def expand(mem: Mem, new_size: Nat) -> Mem:
  match mem:
    case M{active, cells}:
      M{maximum(active, rounded(new_size)), cells}

def found(same: Bool, value: U32, fallback: U32) -> U32:
  match same:
    case True{}:
      value
    case False{}:
      fallback

def lookup(cells: +List<Cell>, +index: Nat) -> U32:
  match cells:
    case Nil{}:
      0
    case Con{C{at, byte}, rest}:
      found(Nat.is_eq(at, index), byte, lookup(rest, index))

def read_byte(mem: Mem, index: Nat) -> U32:
  match mem:
    case M{active, cells}:
      lookup(cells, index)

def keep(different: Bool, cell: Cell, rest: +List<Cell>) -> +List<Cell>:
  match different:
    case True{}:
      cell <> rest
    case False{}:
      rest

def erase(cells: +List<Cell>, +index: Nat) -> +List<Cell>:
  match cells:
    case Nil{}:
      Nil{}
    case Con{C{+at, byte}, rest}:
      keep(Nat.is_ne(at, index), C{at, byte}, erase(rest, index))

def insert(nonzero: Bool, index: Nat, byte: U32, cells: +List<Cell>) -> +List<Cell>:
  match nonzero:
    case True{}:
      C{index, byte} <> cells
    case False{}:
      cells

def store_cell(+index: Nat, value: U32, cells: +List<Cell>) -> +List<Cell>:
  +byte = U32.and(value, 255)
  insert(U32.is_ne(byte, 0), index, byte, erase(cells, index))

def write_byte(mem: Mem, +index: Nat, value: U32) -> Mem:
  match mem:
    case M{active, cells}:
      M{maximum(active, rounded(1n+index)), store_cell(index, value, cells)}

def read_loop(count: Nat, +mem: Mem, +offset: Nat) -> +List<U32>:
  match count:
    case 0n:
      Nil{}
    case 1n+p:
      read_byte(mem, offset) <> read_loop(p, mem, 1n+offset)

def read(mem: Mem, offset: Nat, len: Nat) -> +List<U32>:
  read_loop(len, mem, offset)

def write_loop(bytes: +List<U32>, mem: Mem, +offset: Nat) -> Mem:
  match bytes:
    case Nil{}:
      mem
    case Con{b, rest}:
      write_loop(rest, write_byte(mem, offset, b), 1n+offset)

def write(mem: Mem, offset: Nat, bytes: +List<U32>) -> Mem:
  write_loop(bytes, mem, offset)

# MCOPY touches both source and destination extents, but length zero touches
# neither. The source vector is read from the old immutable memory snapshot.
def copy_nonempty(+len: Nat, +mem: Mem, +dst: Nat, +src: Nat) -> Mem:
  match len:
    case 0n:
      mem
    case 1n+p:
      write(expand(mem, Nat.add(src, 1n+p)), dst, read(mem, src, 1n+p))

def copy(mem: Mem, dst: Nat, src: Nat, len: Nat) -> Mem:
  copy_nonempty(len, mem, dst, src)

def load_word(mem: Mem, offset: Nat) -> W.Word:
  B.to_word(read(mem, offset, 32n))

def store_word(mem: Mem, offset: Nat, word: W.Word) -> Mem:
  write(mem, offset, B.from_word(word))
