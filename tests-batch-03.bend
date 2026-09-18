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
    IO.print("push-11-truncated:" ++ R.state(VM.run([106, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-12-endian:" ++ R.state(VM.run([107, 12, 43, 74, 105, 136, 167, 198, 229, 4, 35, 66, 97], 3n)))
    IO.print("push-12-truncated:" ++ R.state(VM.run([107, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-13-endian:" ++ R.state(VM.run([108, 13, 44, 75, 106, 137, 168, 199, 230, 5, 36, 67, 98, 129], 3n)))
    IO.print("push-13-truncated:" ++ R.state(VM.run([108, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-14-endian:" ++ R.state(VM.run([109, 14, 45, 76, 107, 138, 169, 200, 231, 6, 37, 68, 99, 130, 161], 3n)))
    IO.print("push-14-truncated:" ++ R.state(VM.run([109, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-15-endian:" ++ R.state(VM.run([110, 15, 46, 77, 108, 139, 170, 201, 232, 7, 38, 69, 100, 131, 162, 193], 3n)))
    IO.print("push-15-truncated:" ++ R.state(VM.run([110, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-16-endian:" ++ R.state(VM.run([111, 16, 47, 78, 109, 140, 171, 202, 233, 8, 39, 70, 101, 132, 163, 194, 225], 3n)))
    IO.print("push-16-truncated:" ++ R.state(VM.run([111, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-17-endian:" ++ R.state(VM.run([112, 17, 48, 79, 110, 141, 172, 203, 234, 9, 40, 71, 102, 133, 164, 195, 226, 1], 3n)))
    IO.print("push-17-truncated:" ++ R.state(VM.run([112, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-18-endian:" ++ R.state(VM.run([113, 18, 49, 80, 111, 142, 173, 204, 235, 10, 41, 72, 103, 134, 165, 196, 227, 2, 33], 3n)))
    IO.print("push-18-truncated:" ++ R.state(VM.run([113, 254, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-19-endian:" ++ R.state(VM.run([114, 19, 50, 81, 112, 143, 174, 205, 236, 11, 42, 73, 104, 135, 166, 197, 228, 3, 34, 65], 3n)))
