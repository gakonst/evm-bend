import Base
import ../evmword.bend as W
import ./model.bend as M
import ./gas.bend as G
import ./world.bend as World
import ./call-common.bend as C

# Deletion is deferred until successful transaction finalization (EIP-6780).
def erase_one(+world: M.World, +address: W.Word) -> M.World:
  +old = World.account(world,address)
  +balance = M.Account.balance(old)
  +fresh = M.Account.set_balance(M.empty_account(address),balance)
  World.put(world,M.Account.set_exists(fresh,Bool.not(W.is_zero(balance))))

def finalize_list(addresses: +List<W.Word>, world: M.World) -> M.World:
  match addresses:
    case Nil{}: world
    case Con{address,rest}: finalize_list(rest,erase_one(world,address))

def finalize(+world: M.World) -> M.World:
  M.World.set_selfdestructs(finalize_list(M.World.selfdestructs(world),world),Nil{})
