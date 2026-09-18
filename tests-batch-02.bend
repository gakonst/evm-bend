import Base
import ./vm.bend as VM
import ./render.bend as R

def repeat(n: Nat, +byte: U32) -> +List<U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      byte <> repeat(p, byte)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("push-3-truncated:" ++ R.state(VM.run([98, 254], 3n)))
    IO.print("push-4-endian:" ++ R.state(VM.run([99, 4, 35, 66, 97], 3n)))
    IO.print("push-4-truncated:" ++ R.state(VM.run([99, 254, 254], 3n)))
    IO.print("push-5-endian:" ++ R.state(VM.run([100, 5, 36, 67, 98, 129], 3n)))
    IO.print("push-5-truncated:" ++ R.state(VM.run([100, 254, 254], 3n)))
    IO.print("push-6-endian:" ++ R.state(VM.run([101, 6, 37, 68, 99, 130, 161], 3n)))
    IO.print("push-6-truncated:" ++ R.state(VM.run([101, 254, 254, 254], 3n)))
    IO.print("push-7-endian:" ++ R.state(VM.run([102, 7, 38, 69, 100, 131, 162, 193], 3n)))
    IO.print("push-7-truncated:" ++ R.state(VM.run([102, 254, 254, 254], 3n)))
    IO.print("push-8-endian:" ++ R.state(VM.run([103, 8, 39, 70, 101, 132, 163, 194, 225], 3n)))
    IO.print("push-8-truncated:" ++ R.state(VM.run([103, 254, 254, 254, 254], 3n)))
    IO.print("push-9-endian:" ++ R.state(VM.run([104, 9, 40, 71, 102, 133, 164, 195, 226, 1], 3n)))
    IO.print("push-9-truncated:" ++ R.state(VM.run([104, 254, 254, 254, 254], 3n)))
    IO.print("push-10-endian:" ++ R.state(VM.run([105, 10, 41, 72, 103, 134, 165, 196, 227, 2, 33], 3n)))
    IO.print("push-10-truncated:" ++ R.state(VM.run([105, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-11-endian:" ++ R.state(VM.run([106, 11, 42, 73, 104, 135, 166, 197, 228, 3, 34, 65], 3n)))
