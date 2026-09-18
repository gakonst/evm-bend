import Base
import ../evmword.bend as W
import ./model.bend as M
import ./gas.bend as G
import ./world.bend as World
import ./call-common.bend as C

# Deletion is deferred until successful transaction finalization (EIP-6780).
def mark(created: Bool, +world: M.World, address: W.Word) -> M.World:
  match created:
    case False{}: world
    case True{}: M.World.set_selfdestructs(world,address <> M.World.selfdestructs(world))

def apply(bad: Bool, +e: M.Engine, +target: W.Word) -> M.Engine:
  match bad:
    case True{}: e
    case False{}:
      +f = M.Engine.frame(e)
      +source = M.Frame.address(f)
      +a = World.account(M.Engine.world(e),source)
      +value = M.Account.balance(a)
      +world = C.transfer_log(Bool.or(W.is_zero(value),W.eq(source,target)),World.move_ether(M.Engine.world(e),source,target,value),source,target,value)
      M.Engine.set_frame(M.Engine.set_world(e,mark(M.Account.created(a),world,source)),M.Frame.set_action(M.Frame.set_output(f,Nil{}),M.Stopped{}))

def state(bad: Bool, +e: M.Engine, target: W.Word, charge: Bool) -> M.Engine:
  match bad:
    case True{}: e
    case False{}:
      +paid = C.state_if(charge,e)
      apply(G.failed(M.Frame.action(M.Engine.frame(paid))),paid,target)

def allowed(is_static: Bool, +e: M.Engine, +target: W.Word) -> M.Engine:
  match is_static:
    case True{}: M.Engine.set_frame(e,M.fault(M.Engine.frame(e),6))
    case False{}:
      +world = M.Engine.world(e)
      +recipient = World.account(world,target)
      +source = World.account(world,M.Frame.address(M.Engine.frame(e)))
      +topup = Bool.and(Bool.not(W.is_zero(M.Account.balance(source))),C.empty(recipient))
      +paid = M.Engine.set_frame(e,G.charge(M.Engine.frame(e),Nat.add(U32.to_nat(5000),Nat.add(C.nat(M.Account.warm(recipient),0n,U32.to_nat(3000)),C.nat(topup,U32.to_nat(9000),0n)))))
      +warm = M.Engine.set_world(paid,World.warm_account(M.Engine.world(paid),target))
      state(G.failed(M.Frame.action(M.Engine.frame(warm))),warm,target,topup)

def start(+e: M.Engine, target: W.Word) -> M.Engine:
  allowed(M.Frame.is_static(M.Engine.frame(e)),e,World.normalize_address(target))

# EIP-8246 preserves funds received after SELFDESTRUCT and self-target balance.
def erase_one(+world: M.World, +address: W.Word) -> M.World:
  +old = World.account(world,address)
  +balance = M.Account.balance(old)
  +fresh = M.Account.set_storage(M.Account.set_code(M.Account.set_nonce(old,W.zero()),Nil{}),Nil{})
  World.modify(world,fresh)

def finalize_list(addresses: +List<W.Word>, world: M.World) -> M.World:
  match addresses:
    case Nil{}: world
    case Con{address,rest}: finalize_list(rest,erase_one(world,address))

def finalize(+world: M.World) -> M.World:
  M.World.set_selfdestructs(finalize_list(M.World.selfdestructs(world),world),Nil{})
