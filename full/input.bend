import Base
import ./bytes.bend as B
import ./memory.bend as Mem

# Call data holds an immutable snapshot of parent memory. Only bytes actually
# requested by an opcode are materialized. This avoids copying a large argument
# region on every call when the child inspects only a small part of it.
type View is Data:
  Bytes{length: Nat, data: +List<U32>}
  Slice{memory: Mem.Mem, offset: Nat, length: Nat}

def bytes(+data: +List<U32>) -> View:
  Bytes{B.len(data),data}

def len(view: View) -> Nat:
  match view:
    case Bytes{length,data}: length
    case Slice{memory,offset,length}: length

def smaller(less: Bool,a: Nat,b: Nat) -> Nat:
  match less:
    case True{}: a
    case False{}: b

def available(inside: Bool,memory: Mem.Mem,base: Nat,+offset: Nat,+count: Nat,length: Nat) -> +List<U32>:
  match inside:
    case False{}: B.take(count,Nil{})
    case True{}:
      +remaining = Nat.sub(length,offset)
      +n = smaller(Nat.is_lt(count,remaining),count,remaining)
      B.concat(Mem.read(memory,Nat.add(base,offset),n),B.take(Nat.sub(count,n),Nil{}))

def read(view: View,+offset: Nat,count: Nat) -> +List<U32>:
  match view:
    case Bytes{length,data}: B.slice(offset,count,data)
    case Slice{memory,base,+length}: available(Nat.is_lt(offset,length),memory,base,offset,count,length)

def all(+view: View) -> +List<U32>:
  read(view,0n,len(view))
