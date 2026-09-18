import Base
import ./bytes.bend as B
import ./codec.bend as C
import ./memory.bend as Mem
import ./render.bend as R
import ./input.bend as I

def pattern(n: Nat, +i: Nat, acc: +List<U32>) -> +List<U32>:
  match n:
    case 0n: B.reverse(acc, Nil{})
    case 1n+p: pattern(p, 1n+i, U32.from_nat(Nat.mod(i,256n)) <> acc)

def check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def main() -> IO(Unit):
  do IO<Unit>:
    +original : Mem.Mem = Mem.write(Mem.empty(),0n,[1,2,3,4])
    +view : I.View = I.Slice{original,1n,2n}
    +part : +List<U32> = I.read(view,1n,3n)
    check("calldata view length and bounded padding",Nat.is_eq(I.len(view),2n) && U32.is_eq(B.get(0n,part),3) && U32.is_eq(B.get(1n,part),0) && Nat.is_eq(B.len(part),3n))
    +changed : Mem.Mem = Mem.write_byte(original,1n,0)
    check("persistent snapshot",U32.is_eq(Mem.read_byte(original,1n),2) && U32.is_eq(Mem.read_byte(changed,1n),0))
    check("calldata snapshot survives parent write",U32.is_eq(B.get(0n,I.read(view,0n,1n)),2) && U32.is_eq(Mem.read_byte(changed,1n),0))
    +high : Mem.Mem = Mem.write_byte(changed,Nat.add(Nat.mul(U32.to_nat(2147483648),U32.to_nat(65536)),7n),511)
    check("48-bit sparse index",U32.is_eq(Mem.read_byte(high,Nat.add(Nat.mul(U32.to_nat(2147483648),U32.to_nat(65536)),7n)),255) && U32.is_eq(Mem.read_byte(high,7n),0) && U32.is_eq(Mem.read_byte(high,2n),3))
    +cleared : Mem.Mem = Mem.write_byte(high,Nat.add(Nat.mul(U32.to_nat(2147483648),U32.to_nat(65536)),7n),0)
    check("high sparse clear preserves other branch",U32.is_eq(Mem.read_byte(cleared,Nat.add(Nat.mul(U32.to_nat(2147483648),U32.to_nat(65536)),7n)),0) && U32.is_eq(Mem.read_byte(cleared,2n),3))
    check("overflow-safe ceil",Nat.is_eq(Mem.words(Nat.add(Nat.mul(U32.to_nat(4294967295),U32.to_nat(65536)),U32.to_nat(65535))),Nat.mul(U32.to_nat(2147483648),U32.to_nat(4096))))
    +data : +List<U32> = pattern(U32.to_nat(131072),0n,Nil{})
    +decoded : C.BytesRead = C.read_bytes(U32.to_nat(131072),C.R{data,True{}})
    check("128KiB codec length and trailing reader",Nat.is_eq(B.len(C.BytesRead.value(decoded)),U32.to_nat(131072)) && C.valid(C.BytesRead.reader(decoded)))
    IO.print(R.bytes(B.take(U32.to_nat(131073),C.BytesRead.value(decoded))))
    +mem : Mem.Mem = Mem.write(Mem.empty(),0n,B.take(U32.to_nat(65536),data))
    IO.print(R.bytes(Mem.read(Mem.copy(mem,1n,0n,U32.to_nat(65535)),0n,U32.to_nat(65536))))
