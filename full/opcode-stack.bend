import Base
import ../evmword.bend as W
import ./model.bend as M
import ./bytes.bend as B
import ./opcode-common.bend as H

def swapok(ok: Bool,+f: M.Frame,+a: Nat,+b: Nat) -> M.Frame:
  match ok:
    case False{}: M.fault(f,2)
    case True{}: M.Frame.set_stack(f,H.exchange(M.Frame.stack(f),a,b))

def swap(+f: M.Frame,+a: Nat,+b: Nat) -> M.Frame:
  swapok(Nat.is_gt(List.length(&2,W.Word,M.Frame.stack(f)),H.choose(Nat.is_gt(a,b),a,b)),f,a,b)

def dupok(ok: Bool,+f: M.Frame,n: Nat) -> M.Frame:
  match ok:
    case False{}: M.fault(f,2)
    case True{}: H.push(f,H.arg(f,Nat.sub(n,1n)))

def duproom(room: Bool,+f: M.Frame,+n: Nat) -> M.Frame:
  match room:
    case False{}: M.fault(f,3)
    case True{}: dupok(Nat.is_ge(List.length(&2,W.Word,M.Frame.stack(f)),n),f,n)

def dup(+f: M.Frame,n: Nat) -> M.Frame:
  duproom(Nat.is_lt(List.length(&2,W.Word,M.Frame.stack(f)),1024n),f,n)

def pair(less: Bool,f: M.Frame,q: Nat,r: Nat) -> M.Frame:
  match less:
    case True{}: swap(f,1n+q,1n+r)
    case False{}: swap(f,1n+r,Nat.sub(29n,q))

def decoded(ok: Bool,op: U32,f: M.Frame,+imm: U32) -> M.Frame:
  match ok:
    case False{}: M.fault(f,8)
    case True{}:
      match op:
        case 230: dup(f,U32.to_nat(U32.and(U32.add(imm,145),255)))
        case 231: swap(f,0n,U32.to_nat(U32.and(U32.add(imm,145),255)))
        case other:
          +k = U32.to_nat(U32.xor(imm,143))
          +q = Nat.div(k,16n)
          +r = Nat.mod(k,16n)
          pair(Nat.is_lt(q,r),f,q,r)

def immediate(+op: U32,+f: M.Frame) -> M.Frame:
  +imm = B.get(M.Frame.pc(f),M.Frame.code(f))
  # Code reads are zero-padded, including a missing trailing immediate.
  decoded(Bool.or(U32.is_ge(imm,128),U32.is_le(imm,U32.from_nat(H.choose(U32.is_eq(op,232),81n,90n)))),op,H.next(f,1n),imm)
