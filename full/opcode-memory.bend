import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./gas.bend as G
import ./memory.bend as Mem
import ./bytes.bend as B
import ./keccak.bend as K
import ./opcode-common.bend as H

def finish(bad: Bool,op: U32,+f: M.Frame,+a: W.Word,+b: W.Word,+n: W.Word) -> M.Frame:
  match bad:
    case True{}: f
    case False{}:
      match op:
        case 32: H.result(f,2n,K.hash(Mem.read(M.Frame.memory(f),O.to_nat(a),O.to_nat(b))))
        case 81: H.result(f,1n,Mem.load_word(M.Frame.memory(f),O.to_nat(a)))
        case 82: M.Frame.set_memory(H.pop(f,2n),Mem.store_word(M.Frame.memory(f),O.to_nat(a),b))
        case 83: M.Frame.set_memory(H.pop(f,2n),Mem.write_byte(M.Frame.memory(f),O.to_nat(a),W.low_u32(b)))
        case 94: M.Frame.set_memory(H.pop(f,3n),Mem.copy(M.Frame.memory(f),O.to_nat(a),O.to_nat(b),O.to_nat(n)))
        case 243: M.Frame.set_action(M.Frame.set_output(H.pop(f,2n),Mem.read(M.Frame.memory(f),O.to_nat(a),O.to_nat(b))),M.Returned{})
        case 253: M.Frame.set_action(M.Frame.set_output(H.pop(f,2n),Mem.read(M.Frame.memory(f),O.to_nat(a),O.to_nat(b))),M.Reverted{})
        case 55: M.Frame.set_memory(H.pop(f,3n),Mem.write(M.Frame.memory(f),O.to_nat(a),H.slice(b,O.to_nat(n),M.Frame.input(f))))
        case 57: M.Frame.set_memory(H.pop(f,3n),Mem.write(M.Frame.memory(f),O.to_nat(a),H.slice(b,O.to_nat(n),M.Frame.code(f))))
        case other: M.Frame.set_memory(H.pop(f,3n),Mem.write(M.Frame.memory(f),O.to_nat(a),H.slice(b,O.to_nat(n),M.Frame.ret(f))))

def dynamic_cost(op: U32,b: W.Word,n: W.Word) -> Nat:
  match op:
    case 32: Nat.mul(6n,Mem.words(O.to_nat(b)))
    case 94: Nat.mul(3n,Mem.words(O.to_nat(n)))
    case 55: Nat.mul(3n,Mem.words(O.to_nat(n)))
    case 57: Nat.mul(3n,Mem.words(O.to_nat(n)))
    case 62: Nat.mul(3n,Mem.words(O.to_nat(n)))
    case other: 0n

def dynamic(bad: Bool,+op: U32,+f: M.Frame,+a: W.Word,+b: W.Word,+n: W.Word) -> M.Frame:
  match bad:
    case True{}: f
    case False{}:
      +cost = dynamic_cost(op,b,n)
      +paid = G.charge(f,cost)
      finish(G.failed(M.Frame.action(paid)),op,paid,a,b,n)

def expanded(+op: U32,+f: M.Frame,+a: W.Word,+b: W.Word,+n: W.Word) -> M.Frame:
  +paid = H.memory(f,a,n)
  dynamic(G.failed(M.Frame.action(paid)),op,paid,a,b,n)

def copysecond(bad: Bool,+f: M.Frame,+a: W.Word,+b: W.Word,+n: W.Word) -> M.Frame:
  match bad:
    case True{}: f
    case False{}: expanded(94,f,a,b,n)

def retbounds(ok: Bool,f: M.Frame,a: W.Word,b: W.Word,n: W.Word) -> M.Frame:
  match ok:
    case False{}: M.fault(f,7)
    case True{}: expanded(62,f,a,b,n)

def run(op: U32,+f: M.Frame) -> M.Frame:
  match op:
    case 32:
      +paid = H.memory(f,H.arg(f,0n),H.arg(f,1n))
      dynamic(G.failed(M.Frame.action(paid)),32,paid,H.arg(f,0n),H.arg(f,1n),H.arg(f,1n))
    case 81: expanded(81,f,H.arg(f,0n),H.arg(f,1n),W.from_u32(32))
    case 82: expanded(82,f,H.arg(f,0n),H.arg(f,1n),W.from_u32(32))
    case 83: expanded(83,f,H.arg(f,0n),H.arg(f,1n),W.from_u32(1))
    case 94:
      +paid = H.memory(f,H.arg(f,1n),H.arg(f,2n))
      copysecond(G.failed(M.Frame.action(paid)),paid,H.arg(f,0n),H.arg(f,1n),H.arg(f,2n))
    case 62:
      +off = H.arg(f,1n)
      +n = H.arg(f,2n)
      +end = W.add(off,n)
      retbounds(Bool.and(Bool.not(O.lt(end,off)),Bool.not(O.gt(end,O.from_nat(B.len(M.Frame.ret(f)))))),f,H.arg(f,0n),off,n)
    case 243: expanded(243,f,H.arg(f,0n),H.arg(f,1n),H.arg(f,1n))
    case 253: expanded(253,f,H.arg(f,0n),H.arg(f,1n),H.arg(f,1n))
    case other: expanded(other,f,H.arg(f,0n),H.arg(f,1n),H.arg(f,2n))
