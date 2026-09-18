import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./gas.bend as G
import ./memory.bend as Mem
import ./bytes.bend as B

def choose(b: Bool, a: Nat, c: Nat) -> Nat:
  match b:
    case True{}: a
    case False{}: c

def at(n: Nat, xs: +List<W.Word>) -> W.Word:
  match n:
    case 0n:
      match xs:
        case Nil{}: W.zero()
        case Con{x, rest}: x
    case 1n+p:
      match xs:
        case Nil{}: W.zero()
        case Con{x, rest}: at(p, rest)

def drop(n: Nat, xs: +List<W.Word>) -> +List<W.Word>:
  match n:
    case 0n: xs
    case 1n+p:
      match xs:
        case Nil{}: Nil{}
        case Con{x, rest}: drop(p, rest)

def set(n: Nat, xs: +List<W.Word>, x: W.Word) -> +List<W.Word>:
  match n:
    case 0n:
      match xs:
        case Nil{}: Nil{}
        case Con{h, rest}: x <> rest
    case 1n+p:
      match xs:
        case Nil{}: Nil{}
        case Con{h, rest}: h <> set(p, rest, x)

def exchange(+xs: +List<W.Word>, +a: Nat, +b: Nat) -> +List<W.Word>:
  set(a, set(b, xs, at(a,xs)), at(b,xs))

def arg(+f: M.Frame,n: Nat) -> W.Word:
  at(n,M.Frame.stack(f))

def pop(+f: M.Frame,n: Nat) -> M.Frame:
  M.Frame.set_stack(f,drop(n,M.Frame.stack(f)))

def push(+f: M.Frame,x: W.Word) -> M.Frame:
  M.Frame.set_stack(f,x <> M.Frame.stack(f))

def next(+f: M.Frame,n: Nat) -> M.Frame:
  M.Frame.set_pc(f,Nat.add(M.Frame.pc(f),n))

def result(f: M.Frame,n: Nat,x: W.Word) -> M.Frame:
  push(pop(f,n),x)

def memory_cost(+bytes: Nat) -> W.Word:
  +words = O.from_nat(Mem.words(bytes))
  W.add(O.mul(W.from_u32(3),words),O.div(O.mul(words,words),W.from_u32(512)))

def expanded(bad: Bool,+f: M.Frame,size: Nat) -> M.Frame:
  match bad:
    case True{}: f
    case False{}: M.Frame.set_memory(f,Mem.expand(M.Frame.memory(f),size))

def paymem(cost: Maybe<&2,Nat>,f: M.Frame,+size: Nat) -> M.Frame:
  match cost:
    case None{}: M.fault(f,1)
    case Some{cost}:
      +paid = G.charge(f,cost)
      expanded(G.failed(M.Frame.action(paid)),paid,size)

def rangefit(ok: Bool,+f: M.Frame,end: W.Word) -> M.Frame:
  match ok:
    case False{}: M.fault(f,1)
    case True{}:
      +size = Mem.maximum(Mem.size(M.Frame.memory(f)),O.to_nat(end))
      paymem(O.checked_to_nat(O.sub(memory_cost(size),memory_cost(Mem.size(M.Frame.memory(f))))),f,size)

def rangezero(z: Bool,f: M.Frame,+offset: W.Word,+size: W.Word) -> M.Frame:
  match z:
    case True{}: f
    case False{}:
      +end = W.add(offset,size)
      rangefit(Bool.and(Bool.not(O.lt(end,offset)),O.lt(end,W.W{0,256,0,0,0,0,0,0})),f,end)

def memory(f: M.Frame,offset: W.Word,+size: W.Word) -> M.Frame:
  rangezero(W.is_zero(size),f,offset,size)

def sliceok(ok: Bool,offset: W.Word,count: Nat,bytes: +List<U32>) -> +List<U32>:
  match ok:
    case False{}: B.take(count,Nil{})
    case True{}: B.slice(O.to_nat(offset),count,bytes)

def slice(+offset: W.Word,count: Nat,+bytes: +List<U32>) -> +List<U32>:
  sliceok(O.lt(offset,O.from_nat(B.len(bytes))),offset,count,bytes)

# Legacy jump-destination analysis skips PUSH data only. EIP-8024
# immediate bytes are still scanned as opcodes when building destinations.
def width(+op: U32) -> Nat:
  choose(Bool.and(U32.is_ge(op,96),U32.is_le(op,127)),U32.to_nat(U32.sub(op,94)),1n)

def jump_scan(code: +List<U32>,+target: Nat,+pc: Nat,skip: Nat) -> Bool:
  match code:
    case Nil{}: False{}
    case Con{+op,rest}:
      match skip:
        case 0n:
          Bool.or(Bool.and(Nat.is_eq(pc,target),U32.is_eq(op,91)),jump_scan(rest,target,1n+pc,Nat.sub(width(op),1n)))
        case 1n+p: jump_scan(rest,target,1n+pc,p)

def jumpok(ok: Bool,f: M.Frame,target: W.Word) -> M.Frame:
  match ok:
    case False{}: M.fault(f,5)
    case True{}: M.Frame.set_pc(f,O.to_nat(target))

def jump(take: Bool,+f: M.Frame,+target: W.Word) -> M.Frame:
  match take:
    case False{}: f
    case True{}: jumpok(Bool.and(O.lt(target,O.from_nat(B.len(M.Frame.code(f)))),jump_scan(M.Frame.code(f),O.to_nat(target),0n,0n)),f,target)
