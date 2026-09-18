import Base
import ../evmword.bend as W
import ./bytes.bend as B

# Pure sparse byte memory indexed by a persistent 48-bit radix tree.
# Access visits at most 48 branches regardless of the number of stored bytes.
# The caller validates Nat offsets and gas before memory access. Reading does
# not expand memory; writes and explicit expansion round active size to 32 bytes.
type Cells is Data:
  Empty{}
  Byte{value: U32}
  Branch{left: Cells, right: Cells}

type Mem is Data:
  M{active: Nat, cells: Cells}

def empty() -> Mem:
  M{0n, Empty{}}

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

def child(high: Bool, cells: Cells) -> Cells:
  match high:
    case False{}:
      match cells:
        case Branch{left, right}: left
        case other: Empty{}
    case True{}:
      match cells:
        case Branch{left, right}: right
        case other: Empty{}

def branch(left: Cells, right: Cells) -> Cells:
  match left right:
    case Empty{} Empty{}: Empty{}
    case l r: Branch{l, r}

def replace(high: Bool, cells: Cells, value: Cells) -> Cells:
  match high:
    case False{}: branch(value, child(True{}, cells))
    case True{}: branch(child(False{}, cells), value)

def leaf(nonzero: Bool, byte: U32) -> Cells:
  match nonzero:
    case False{}: Empty{}
    case True{}: Byte{byte}

def leaf_value(cells: Cells) -> U32:
  match cells:
    case Byte{value}: value
    case other: 0

def lookup(depth: Nat, cells: Cells, +index: Nat, +divisor: Nat) -> U32:
  match depth:
    case 0n: leaf_value(cells)
    case 1n+p:
      match cells:
        case Empty{}: 0
        case other:
          lookup(p, child(Nat.is_ge(index, divisor), other), Nat.mod(index, divisor), Nat.div(divisor, 2n))

def store(depth: Nat, +cells: Cells, +index: Nat, +divisor: Nat, byte: U32) -> Cells:
  match depth:
    case 0n:
      +byte = U32.and(byte, 255)
      leaf(U32.is_ne(byte, 0), byte)
    case 1n+p:
      +high = Nat.is_ge(index, divisor)
      value = store(p, child(high, cells), Nat.mod(index, divisor), Nat.div(divisor, 2n), byte)
      replace(high, cells, value)

# Clearing an absent sparse branch is constant work, including all-zero words.
def clear(depth: Nat, +cells: Cells, +index: Nat, +divisor: Nat) -> Cells:
  match depth:
    case 0n: Empty{}
    case 1n+p:
      match cells:
        case Empty{}: Empty{}
        case other:
          +high = Nat.is_ge(index,divisor)
          value = clear(p,child(high,other),Nat.mod(index,divisor),Nat.div(divisor,2n))
          replace(high,other,value)

def write_cells(nonzero: Bool,cells: Cells,index: Nat,byte: U32) -> Cells:
  match nonzero:
    case False{}: clear(48n,cells,index,Nat.mul(U32.to_nat(2147483648),U32.to_nat(65536)))
    case True{}: store(48n,cells,index,Nat.mul(U32.to_nat(2147483648),U32.to_nat(65536)),byte)

def read_byte(mem: Mem, index: Nat) -> U32:
  match mem:
    case M{active, cells}: lookup(48n, cells, index, Nat.mul(U32.to_nat(2147483648), U32.to_nat(65536)))

def write_byte(mem: Mem, +index: Nat, +value: U32) -> Mem:
  match mem:
    case M{active, cells}:
      M{maximum(active, rounded(1n+index)), write_cells(U32.is_ne(U32.and(value,255),0),cells,index,value)}

def read_loop(count: Nat, +mem: Mem, +offset: Nat, acc: +List<U32>) -> +List<U32>:
  match count:
    case 0n: B.reverse(acc, Nil{})
    case 1n+p:
      read_loop(p, mem, 1n+offset, read_byte(mem, offset) <> acc)

def read(mem: Mem, offset: Nat, len: Nat) -> +List<U32>:
  read_loop(len, mem, offset, Nil{})

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
