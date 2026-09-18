import Base
import ../evmword.bend as W
import ./model.bend as M
import ./gas.bend as G
import ./world.bend as World
import ./bytes.bend as B
import ./memory.bend as Mem
import ./call-common.bend as C

def store(bad: Bool, +e: M.Engine, address: W.Word) -> M.Engine:
  match bad:
    case True{}: e
    case False{}:
      +world = M.Engine.world(e)
      a = M.Account.set_code(World.account(world,address),M.Frame.output(M.Engine.frame(e)))
      M.Engine.set_world(e,World.modify(world,a))

def deposit(bad: Bool, +e: M.Engine, address: W.Word, len: Nat) -> M.Engine:
  match bad:
    case True{}: e
    case False{}:
      +paid = G.spend_state(e,Nat.mul(U32.to_nat(1530),len))
      store(G.failed(M.Frame.action(M.Engine.frame(paid))),paid,address)

def valid(invalid: Bool, +e: M.Engine, address: W.Word) -> M.Engine:
  match invalid:
    case True{}: M.Engine.set_frame(e,M.fault(M.Engine.frame(e),9))
    case False{}:
      +len = B.len(M.Frame.output(M.Engine.frame(e)))
      +paid = M.Engine.set_frame(e,G.charge(M.Engine.frame(e),Nat.mul(6n,Mem.words(len))))
      deposit(G.failed(M.Frame.action(M.Engine.frame(paid))),paid,address,len)

def finish_if(success: Bool, +e: M.Engine, address: W.Word) -> M.Engine:
  match success:
    case False{}: e
    case True{}:
      +output = M.Frame.output(M.Engine.frame(e))
      valid(Bool.or(Nat.is_gt(B.len(output),U32.to_nat(65536)),U32.is_eq(B.head(output),239)),e,address)

def finish(+e: M.Engine, address: W.Word) -> M.Engine:
  finish_if(G.successful(M.Frame.action(M.Engine.frame(e))),e,address)
