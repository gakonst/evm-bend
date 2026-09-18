import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./gas.bend as G
import ./memory.bend as Mem
import ./bytes.bend as B
import ./opcode-common.bend as H
import ./opcode-memory.bend as MM
import ./opcode-stack.bend as S

def block_choose(ok: Bool,a: W.Word,b: W.Word) -> W.Word:
  match ok:
    case True{}: a
    case False{}: b


def block_find(xs: +List<M.BlockHash>,+n: W.Word) -> W.Word:
  match xs:
    case Nil{}: W.zero()
    case Con{M.BH{number,hash},rest}: block_choose(W.eq(number,n),hash,block_find(rest,n))


def block(+n: W.Word,+c: M.Context) -> W.Word:
  block_choose(Bool.and(O.lt(n,M.Context.number(c)),Bool.not(O.gt(O.sub(M.Context.number(c),n),W.from_u32(256)))),block_find(M.Context.blockhashes(c),n),W.zero())

def exp_paid(bad: Bool,+f: M.Frame) -> M.Frame:
  match bad:
    case True{}: f
    case False{}: H.result(f,2n,O.exp(H.arg(f,0n),H.arg(f,1n)))

def exponent(+f: M.Frame) -> M.Frame:
  +paid = G.charge(f,Nat.mul(50n,Nat.div(Nat.add(Nat.sub(256n,O.to_nat(O.clz(H.arg(f,1n)))),7n),8n)))
  exp_paid(G.failed(M.Frame.action(paid)),paid)

def action_static(bad: Bool,f: M.Frame,a: M.Action) -> M.Frame:
  match bad:
    case True{}: M.fault(f,6)
    case False{}: M.Frame.set_action(f,a)

def blob(ok: Bool,n: W.Word,xs: +List<W.Word>) -> W.Word:
  match ok:
    case False{}: W.zero()
    case True{}: H.at(O.to_nat(n),xs)


def execute(op: U32,+f: M.Frame,+c: M.Context) -> M.Frame:
  match op:
    case 0: M.Frame.set_action(M.Frame.set_output(f,Nil{}),M.Stopped{})
    case 1: H.result(f,2n,W.add(H.arg(f,0n),H.arg(f,1n)))
    case 2: H.result(f,2n,O.mul(H.arg(f,0n),H.arg(f,1n)))
    case 3: H.result(f,2n,O.sub(H.arg(f,0n),H.arg(f,1n)))
    case 4: H.result(f,2n,O.div(H.arg(f,0n),H.arg(f,1n)))
    case 5: H.result(f,2n,O.sdiv(H.arg(f,0n),H.arg(f,1n)))
    case 6: H.result(f,2n,O.mod(H.arg(f,0n),H.arg(f,1n)))
    case 7: H.result(f,2n,O.smod(H.arg(f,0n),H.arg(f,1n)))
    case 8: H.result(f,3n,O.addmod(H.arg(f,0n),H.arg(f,1n),H.arg(f,2n)))
    case 9: H.result(f,3n,O.mulmod(H.arg(f,0n),H.arg(f,1n),H.arg(f,2n)))
    case 10: exponent(f)
    case 11: H.result(f,2n,O.signextend(H.arg(f,0n),H.arg(f,1n)))
    case 16: H.result(f,2n,O.bool_word(O.lt(H.arg(f,0n),H.arg(f,1n))))
    case 17: H.result(f,2n,O.bool_word(O.gt(H.arg(f,0n),H.arg(f,1n))))
    case 18: H.result(f,2n,O.bool_word(O.slt(H.arg(f,0n),H.arg(f,1n))))
    case 19: H.result(f,2n,O.bool_word(O.sgt(H.arg(f,0n),H.arg(f,1n))))
    case 20: H.result(f,2n,O.bool_word(W.eq(H.arg(f,0n),H.arg(f,1n))))
    case 21: H.result(f,1n,O.bool_word(W.is_zero(H.arg(f,0n))))
    case 22: H.result(f,2n,O.and(H.arg(f,0n),H.arg(f,1n)))
    case 23: H.result(f,2n,O.or(H.arg(f,0n),H.arg(f,1n)))
    case 24: H.result(f,2n,O.xor(H.arg(f,0n),H.arg(f,1n)))
    case 25: H.result(f,1n,O.not(H.arg(f,0n)))
    case 26: H.result(f,2n,O.byte(H.arg(f,0n),H.arg(f,1n)))
    case 27: H.result(f,2n,O.shl(H.arg(f,0n),H.arg(f,1n)))
    case 28: H.result(f,2n,O.shr(H.arg(f,0n),H.arg(f,1n)))
    case 29: H.result(f,2n,O.sar(H.arg(f,0n),H.arg(f,1n)))
    case 30: H.result(f,1n,O.clz(H.arg(f,0n)))
    case 32: MM.run(32,f)
    case 48: H.push(f,M.Frame.address(f))
    case 50: H.push(f,M.Context.origin(c))
    case 51: H.push(f,M.Frame.caller(f))
    case 52: H.push(f,M.Frame.value(f))
    case 53: H.result(f,1n,B.to_word(H.slice(H.arg(f,0n),32n,M.Frame.input(f))))
    case 54: H.push(f,O.from_nat(B.len(M.Frame.input(f))))
    case 55: MM.run(55,f)
    case 56: H.push(f,O.from_nat(B.len(M.Frame.code(f))))
    case 57: MM.run(57,f)
    case 58: H.push(f,M.Context.gasprice(c))
    case 61: H.push(f,O.from_nat(B.len(M.Frame.ret(f))))
    case 62: MM.run(62,f)
    case 64: H.result(f,1n,block(H.arg(f,0n),c))
    case 65: H.push(f,M.Context.coinbase(c))
    case 66: H.push(f,M.Context.timestamp(c))
    case 67: H.push(f,M.Context.number(c))
    case 68: H.push(f,M.Context.prevrandao(c))
    case 69: H.push(f,M.Context.gaslimit(c))
    case 70: H.push(f,M.Context.chainid(c))
    case 72: H.push(f,M.Context.basefee(c))
    case 73: H.result(f,1n,blob(O.lt(H.arg(f,0n),O.from_nat(List.length(&2,W.Word,M.Context.blobhashes(c)))),H.arg(f,0n),M.Context.blobhashes(c)))
    case 74: H.push(f,M.Context.blobbasefee(c))
    case 75: H.push(f,M.Context.slotnum(c))
    case 80: H.pop(f,1n)
    case 81: MM.run(81,f)
    case 82: MM.run(82,f)
    case 83: MM.run(83,f)
    case 86: H.jump(True{},H.pop(f,1n),H.arg(f,0n))
    case 87: H.jump(Bool.not(W.is_zero(H.arg(f,1n))),H.pop(f,2n),H.arg(f,0n))
    case 88: H.push(f,O.from_nat(Nat.sub(M.Frame.pc(f),1n)))
    case 89: H.push(f,O.from_nat(Mem.size(M.Frame.memory(f))))
    case 90: H.push(f,O.from_nat(M.Frame.gas(f)))
    case 91: f
    case 94: MM.run(94,f)
    case 95: H.push(f,W.zero())
    case 96: H.push(H.next(f,1n),B.fold_word(1n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 97: H.push(H.next(f,2n),B.fold_word(2n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 98: H.push(H.next(f,3n),B.fold_word(3n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 99: H.push(H.next(f,4n),B.fold_word(4n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 100: H.push(H.next(f,5n),B.fold_word(5n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 101: H.push(H.next(f,6n),B.fold_word(6n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 102: H.push(H.next(f,7n),B.fold_word(7n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 103: H.push(H.next(f,8n),B.fold_word(8n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 104: H.push(H.next(f,9n),B.fold_word(9n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 105: H.push(H.next(f,10n),B.fold_word(10n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 106: H.push(H.next(f,11n),B.fold_word(11n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 107: H.push(H.next(f,12n),B.fold_word(12n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 108: H.push(H.next(f,13n),B.fold_word(13n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 109: H.push(H.next(f,14n),B.fold_word(14n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 110: H.push(H.next(f,15n),B.fold_word(15n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 111: H.push(H.next(f,16n),B.fold_word(16n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 112: H.push(H.next(f,17n),B.fold_word(17n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 113: H.push(H.next(f,18n),B.fold_word(18n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 114: H.push(H.next(f,19n),B.fold_word(19n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 115: H.push(H.next(f,20n),B.fold_word(20n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 116: H.push(H.next(f,21n),B.fold_word(21n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 117: H.push(H.next(f,22n),B.fold_word(22n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 118: H.push(H.next(f,23n),B.fold_word(23n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 119: H.push(H.next(f,24n),B.fold_word(24n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 120: H.push(H.next(f,25n),B.fold_word(25n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 121: H.push(H.next(f,26n),B.fold_word(26n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 122: H.push(H.next(f,27n),B.fold_word(27n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 123: H.push(H.next(f,28n),B.fold_word(28n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 124: H.push(H.next(f,29n),B.fold_word(29n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 125: H.push(H.next(f,30n),B.fold_word(30n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 126: H.push(H.next(f,31n),B.fold_word(31n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 127: H.push(H.next(f,32n),B.fold_word(32n,B.drop(M.Frame.pc(f),M.Frame.code(f)),W.zero()))
    case 128: S.dup(f,1n)
    case 129: S.dup(f,2n)
    case 130: S.dup(f,3n)
    case 131: S.dup(f,4n)
    case 132: S.dup(f,5n)
    case 133: S.dup(f,6n)
    case 134: S.dup(f,7n)
    case 135: S.dup(f,8n)
    case 136: S.dup(f,9n)
    case 137: S.dup(f,10n)
    case 138: S.dup(f,11n)
    case 139: S.dup(f,12n)
    case 140: S.dup(f,13n)
    case 141: S.dup(f,14n)
    case 142: S.dup(f,15n)
    case 143: S.dup(f,16n)
    case 144: S.swap(f,0n,1n)
    case 145: S.swap(f,0n,2n)
    case 146: S.swap(f,0n,3n)
    case 147: S.swap(f,0n,4n)
    case 148: S.swap(f,0n,5n)
    case 149: S.swap(f,0n,6n)
    case 150: S.swap(f,0n,7n)
    case 151: S.swap(f,0n,8n)
    case 152: S.swap(f,0n,9n)
    case 153: S.swap(f,0n,10n)
    case 154: S.swap(f,0n,11n)
    case 155: S.swap(f,0n,12n)
    case 156: S.swap(f,0n,13n)
    case 157: S.swap(f,0n,14n)
    case 158: S.swap(f,0n,15n)
    case 159: S.swap(f,0n,16n)
    case 230: S.immediate(230,f)
    case 231: S.immediate(231,f)
    case 232: S.immediate(232,f)
    case 240: action_static(M.Frame.is_static(f),H.pop(f,3n),M.Create{240,H.arg(f,0n),H.arg(f,1n),H.arg(f,2n),W.zero()})
    case 241: action_static(Bool.and(M.Frame.is_static(f),Bool.not(W.is_zero(H.arg(f,2n)))),H.pop(f,7n),M.Call{241,H.arg(f,0n),H.arg(f,1n),H.arg(f,2n),H.arg(f,3n),H.arg(f,4n),H.arg(f,5n),H.arg(f,6n)})
    case 242: action_static(False{},H.pop(f,7n),M.Call{242,H.arg(f,0n),H.arg(f,1n),H.arg(f,2n),H.arg(f,3n),H.arg(f,4n),H.arg(f,5n),H.arg(f,6n)})
    case 243: MM.run(243,f)
    case 244: action_static(False{},H.pop(f,6n),M.Call{244,H.arg(f,0n),H.arg(f,1n),W.zero(),H.arg(f,2n),H.arg(f,3n),H.arg(f,4n),H.arg(f,5n)})
    case 245: action_static(M.Frame.is_static(f),H.pop(f,4n),M.Create{245,H.arg(f,0n),H.arg(f,1n),H.arg(f,2n),H.arg(f,3n)})
    case 250: action_static(False{},H.pop(f,6n),M.Call{250,H.arg(f,0n),H.arg(f,1n),W.zero(),H.arg(f,2n),H.arg(f,3n),H.arg(f,4n),H.arg(f,5n)})
    case 253: MM.run(253,f)
    case 255: action_static(M.Frame.is_static(f),H.pop(f,1n),M.SelfDestruct{H.arg(f,0n)})
    case other: M.fault(f,4)


def required(op: U32) -> Nat:
  match op:
    case 1: 2n
    case 2: 2n
    case 3: 2n
    case 4: 2n
    case 5: 2n
    case 6: 2n
    case 7: 2n
    case 8: 3n
    case 9: 3n
    case 10: 2n
    case 11: 2n
    case 16: 2n
    case 17: 2n
    case 18: 2n
    case 19: 2n
    case 20: 2n
    case 21: 1n
    case 22: 2n
    case 23: 2n
    case 24: 2n
    case 25: 1n
    case 26: 2n
    case 27: 2n
    case 28: 2n
    case 29: 2n
    case 30: 1n
    case 32: 2n
    case 53: 1n
    case 55: 3n
    case 57: 3n
    case 62: 3n
    case 64: 1n
    case 73: 1n
    case 80: 1n
    case 81: 1n
    case 82: 2n
    case 83: 2n
    case 86: 1n
    case 87: 2n
    case 94: 3n
    case 240: 3n
    case 241: 7n
    case 242: 7n
    case 243: 2n
    case 244: 6n
    case 245: 4n
    case 250: 6n
    case 253: 2n
    case 255: 1n
    case other: 0n

def cost(op: U32) -> Nat:
  match op:
    case 1: 3n
    case 2: 5n
    case 3: 3n
    case 4: 5n
    case 5: 5n
    case 6: 5n
    case 7: 5n
    case 8: 8n
    case 9: 8n
    case 10: 10n
    case 11: 5n
    case 16: 3n
    case 17: 3n
    case 18: 3n
    case 19: 3n
    case 20: 3n
    case 21: 3n
    case 22: 3n
    case 23: 3n
    case 24: 3n
    case 25: 3n
    case 26: 3n
    case 27: 3n
    case 28: 3n
    case 29: 3n
    case 30: 5n
    case 32: 30n
    case 48: 2n
    case 50: 2n
    case 51: 2n
    case 52: 2n
    case 53: 3n
    case 54: 2n
    case 55: 3n
    case 56: 2n
    case 57: 3n
    case 58: 2n
    case 61: 2n
    case 62: 3n
    case 64: 20n
    case 65: 2n
    case 66: 2n
    case 67: 2n
    case 68: 2n
    case 69: 2n
    case 70: 2n
    case 72: 2n
    case 73: 3n
    case 74: 2n
    case 75: 2n
    case 80: 2n
    case 81: 3n
    case 82: 3n
    case 83: 3n
    case 86: 8n
    case 87: 10n
    case 88: 2n
    case 89: 2n
    case 90: 2n
    case 91: 1n
    case 94: 3n
    case 95: 2n
    case 96: 3n
    case 97: 3n
    case 98: 3n
    case 99: 3n
    case 100: 3n
    case 101: 3n
    case 102: 3n
    case 103: 3n
    case 104: 3n
    case 105: 3n
    case 106: 3n
    case 107: 3n
    case 108: 3n
    case 109: 3n
    case 110: 3n
    case 111: 3n
    case 112: 3n
    case 113: 3n
    case 114: 3n
    case 115: 3n
    case 116: 3n
    case 117: 3n
    case 118: 3n
    case 119: 3n
    case 120: 3n
    case 121: 3n
    case 122: 3n
    case 123: 3n
    case 124: 3n
    case 125: 3n
    case 126: 3n
    case 127: 3n
    case 128: 3n
    case 129: 3n
    case 130: 3n
    case 131: 3n
    case 132: 3n
    case 133: 3n
    case 134: 3n
    case 135: 3n
    case 136: 3n
    case 137: 3n
    case 138: 3n
    case 139: 3n
    case 140: 3n
    case 141: 3n
    case 142: 3n
    case 143: 3n
    case 144: 3n
    case 145: 3n
    case 146: 3n
    case 147: 3n
    case 148: 3n
    case 149: 3n
    case 150: 3n
    case 151: 3n
    case 152: 3n
    case 153: 3n
    case 154: 3n
    case 155: 3n
    case 156: 3n
    case 157: 3n
    case 158: 3n
    case 159: 3n
    case 230: 3n
    case 231: 3n
    case 232: 3n
    case 241: 100n
    case 242: 100n
    case 244: 100n
    case 250: 100n
    case other: 0n

def growth(op: U32) -> Nat:
  match op:
    case 48: 1n
    case 50: 1n
    case 51: 1n
    case 52: 1n
    case 54: 1n
    case 56: 1n
    case 58: 1n
    case 61: 1n
    case 65: 1n
    case 66: 1n
    case 67: 1n
    case 68: 1n
    case 69: 1n
    case 70: 1n
    case 72: 1n
    case 74: 1n
    case 75: 1n
    case 88: 1n
    case 89: 1n
    case 90: 1n
    case 95: 1n
    case 96: 1n
    case 97: 1n
    case 98: 1n
    case 99: 1n
    case 100: 1n
    case 101: 1n
    case 102: 1n
    case 103: 1n
    case 104: 1n
    case 105: 1n
    case 106: 1n
    case 107: 1n
    case 108: 1n
    case 109: 1n
    case 110: 1n
    case 111: 1n
    case 112: 1n
    case 113: 1n
    case 114: 1n
    case 115: 1n
    case 116: 1n
    case 117: 1n
    case 118: 1n
    case 119: 1n
    case 120: 1n
    case 121: 1n
    case 122: 1n
    case 123: 1n
    case 124: 1n
    case 125: 1n
    case 126: 1n
    case 127: 1n
    case other: 0n

def paid(bad: Bool,op: U32,f: M.Frame,c: M.Context) -> M.Frame:
  match bad:
    case True{}: f
    case False{}: execute(op,H.next(f,1n),c)

def room(ok: Bool,+op: U32,f: M.Frame,c: M.Context) -> M.Frame:
  match ok:
    case False{}: M.fault(f,3)
    case True{}:
      +p = G.charge(f,cost(op))
      paid(G.failed(M.Frame.action(p)),op,p,c)

def enough(ok: Bool,+op: U32,+f: M.Frame,c: M.Context) -> M.Frame:
  match ok:
    case False{}: M.fault(f,2)
    case True{}: room(Nat.is_le(Nat.add(List.length(&2,W.Word,M.Frame.stack(f)),growth(op)),1024n),op,f,c)

def dispatch(+op: U32,+f: M.Frame,c: M.Context) -> M.Frame:
  enough(Nat.is_ge(List.length(&2,W.Word,M.Frame.stack(f)),required(op)),op,f,c)

def active(a: M.Action,+f: M.Frame,c: M.Context) -> M.Frame:
  match a:
    case M.Running{}: dispatch(B.get(M.Frame.pc(f),M.Frame.code(f)),f,c)
    case other: f

def step(+f: M.Frame,c: M.Context) -> M.Frame:
  active(M.Frame.action(f),f,c)
