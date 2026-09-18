import Base
import ../evmword.bend as W
import ./model.bend as M
import ./memory.bend as Mem
import ./opcode-common.bend as H
import ./gas.bend as G
import ./render.bend as R

def check(name: String,ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(R.word(H.memory_cost(0n)))
    IO.print(R.word(H.memory_cost(1n)))
    IO.print(R.word(H.memory_cost(31n)))
    IO.print(R.word(H.memory_cost(32n)))
    IO.print(R.word(H.memory_cost(33n)))
    IO.print(R.word(H.memory_cost(U32.to_nat(134217727))))
    IO.print(R.word(H.memory_cost(U32.to_nat(134217728))))
    IO.print(R.word(H.memory_cost(U32.to_nat(134217729))))
    IO.print(R.word(H.memory_cost(Nat.sub(Nat.mul(U32.to_nat(16777216),U32.to_nat(65536)),1n))))
    +f : M.Frame = M.initial_frame(Nil{},3n,Nil{},W.zero(),W.zero(),W.zero())
    +grown : M.Frame = H.memory(f,W.zero(),W.from_u32(1))
    +same : M.Frame = H.memory(grown,W.zero(),W.from_u32(32))
    check("non-growing access preserves zero gas",Nat.is_eq(M.Frame.gas(same),0n) && Nat.is_eq(Mem.size(M.Frame.memory(same)),32n) && Bool.not(G.failed(M.Frame.action(same))))
    +bad : M.Frame = H.memory(f,W.zero(),W.from_u32(134217728))
    check("failed expansion faults before memory growth",G.failed(M.Frame.action(bad)) && Nat.is_eq(Mem.size(M.Frame.memory(bad)),0n))
