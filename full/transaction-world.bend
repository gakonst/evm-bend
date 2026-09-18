import Base
import ../evmword.bend as W
import ./model.bend as M
import ./world.bend as World

# Transaction-local annotations never leak from an earlier transaction.
def reverse_accounts(accounts: +List<M.Account>, acc: +List<M.Account>) -> +List<M.Account>:
  match accounts:
    case Nil{}: acc
    case Con{a,rest}: reverse_accounts(rest,a <> acc)

def reset_accounts_acc(accounts: +List<M.Account>, acc: +List<M.Account>) -> +List<M.Account>:
  match accounts:
    case Nil{}: reverse_accounts(acc,Nil{})
    case Con{+a,rest}:
      a = M.Account.set_storage_warm(M.Account.set_created(M.Account.set_warm(M.Account.set_transient(M.Account.set_original(a,M.Account.storage(a)),Nil{}),False{}),False{}),Nil{})
      reset_accounts_acc(rest,a <> acc)

def reset_accounts(accounts: +List<M.Account>) -> +List<M.Account>:
  reset_accounts_acc(accounts,Nil{})

def reset(+world: M.World) -> M.World:
  M.World{reset_accounts(M.World.accounts(world)),Nil{},W.zero(),Nil{}}

def warm_precompiles(+n: Nat, world: M.World) -> M.World:
  match n:
    case 0n: World.warm_account(world,W.from_u32(256))
    case 1n+p: warm_precompiles(p,World.warm_account(world,W.from_u32(U32.from_nat(1n+p))))

def warm_slots(keys: +List<W.Word>, world: M.World, +address: W.Word) -> M.World:
  match keys:
    case Nil{}: world
    case Con{key,rest}: warm_slots(rest,World.warm_storage(world,address,key),address)

# Mutating account fields follows pinned immediate empty-account deletion.
def write(world: M.World, a: M.Account) -> M.World:
  World.modify(world,a)
