import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./gas.bend as G
import ./memory.bend as Mem
import ./opcode-common.bend as H
import ./bytes.bend as B
import ./world.bend as World

def nat(test: Bool, a: Nat, b: Nat) -> Nat:
  match test:
    case True{}: a
    case False{}: b

def word(test: Bool, a: W.Word, b: W.Word) -> W.Word:
  match test:
    case True{}: a
    case False{}: b

def empty(+a: M.Account) -> Bool:
  Bool.and(W.is_zero(M.Account.nonce(a)), Bool.and(W.is_zero(M.Account.balance(a)), Nat.is_eq(B.len(M.Account.code(a)), 0n)))

def access(a: M.Account) -> Nat:
  nat(M.Account.warm(a), U32.to_nat(100), U32.to_nat(3000))

def push(+f: M.Frame, value: W.Word) -> M.Frame:
  M.Frame.set_action(M.Frame.set_stack(f, value <> M.Frame.stack(f)), M.Running{})

def fail(+e: M.Engine) -> M.Engine:
  M.Engine.set_frame(e, M.fault(M.Engine.frame(e), 1))

def memory_paid(bad: Bool, +f: M.Frame, size: Nat) -> M.Frame:
  match bad:
    case True{}: f
    case False{}: M.Frame.set_memory(f, Mem.expand(M.Frame.memory(f), size))

def memory_cost(bytes: Nat) -> W.Word:
  H.memory_cost(bytes)

def memory_charge(cost: Maybe<&2,Nat>, +f: M.Frame, size: Nat) -> M.Frame:
  match cost:
    case None{}: M.fault(f, 1)
    case Some{cost}:
      +paid = G.charge(f, cost)
      memory_paid(G.failed(M.Frame.action(paid)), paid, size)

def memory_range_fit(fits: Bool,f: M.Frame,end: W.Word) -> M.Frame:
  H.rangefit(fits,f,end)

def memory_nonzero(zero: Bool, +f: M.Frame, +offset: W.Word, +size: W.Word) -> M.Frame:
  match zero:
    case True{}: f
    case False{}:
      +end = W.add(offset, size)
      memory_range_fit(Bool.and(Bool.not(O.lt(end, offset)), O.lt(end, W.W{0,256,0,0,0,0,0,0})), f, end)

def memory(f: M.Frame, offset: W.Word, +size: W.Word) -> M.Frame:
  memory_nonzero(W.is_zero(size), f, offset, size)

def transfer_log(skip: Bool, world: M.World, source: W.Word, target: W.Word, value: W.Word) -> M.World:
  match skip:
    case True{}: world
    case False{}:
      World.log(world, M.Log{W.W{4294967294,4294967295,4294967295,4294967295,4294967295,0,0,0}, [W.W{4112757743,687168077,1673830678,2502666225,4231499178,1774366824,467847323,3723645613},source,target], B.from_word(value)})

def transfer(world: M.World, +source: W.Word, +target: W.Word, +value: W.Word) -> M.World:
  transfer_log(Bool.or(W.is_zero(value), W.eq(source,target)), World.transfer(world,source,target,value),source,target,value)

def state_if(charge: Bool, e: M.Engine) -> M.Engine:
  match charge:
    case True{}: G.spend_state(e, U32.to_nat(183600))
    case False{}: e

def refund_if(refund: Bool, e: M.Engine) -> M.Engine:
  match refund:
    case True{}: G.refill(e, U32.to_nat(183600))
    case False{}: e

def cap(+gas: Nat) -> Nat:
  Nat.sub(gas, Nat.div(gas,U32.to_nat(64)))
