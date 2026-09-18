import Base
import ../evmword.bend as W
import ./model.bend as M
import ./world.bend as World
import ./bytes.bend as B

def warm_repeat(n: Nat,world: M.World) -> M.World:
  match n:
    case 0n: world
    case 1n+p: warm_repeat(p,World.warm_storage(world,W.from_u32(1),W.zero()))

def check(name: String,ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def main() -> IO(Unit):
  do IO<Unit>:
    check("128KiB code account is nonempty",Bool.not(World.is_empty(M.Account.set_code(M.empty_account(W.zero()),B.take(U32.to_nat(131072),Nil{})))))
    +world : M.World = warm_repeat(U32.to_nat(50000),M.empty_world())
    +keys : +List<W.Word> = M.Account.storage_warm(World.account(world,W.from_u32(1)))
    check("50000 accesses retain one warm key",Nat.is_eq(List.length(&2,W.Word,keys),1n) && World.contains(keys,W.zero()) && Bool.not(World.contains(keys,W.from_u32(1))))
    +second : M.World = World.warm_storage(world,W.from_u32(1),W.from_u32(1))
    +next : +List<W.Word> = M.Account.storage_warm(World.account(second,W.from_u32(1)))
    check("distinct warm keys and immutable snapshot",Nat.is_eq(List.length(&2,W.Word,next),2n) && World.contains(next,W.zero()) && World.contains(next,W.from_u32(1)) && Nat.is_eq(List.length(&2,W.Word,M.Account.storage_warm(World.account(world,W.from_u32(1)))),1n))
