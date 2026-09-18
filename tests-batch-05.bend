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
    IO.print("push-27-truncated:" ++ R.state(VM.run([122, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-28-endian:" ++ R.state(VM.run([123, 28, 59, 90, 121, 152, 183, 214, 245, 20, 51, 82, 113, 144, 175, 206, 237, 12, 43, 74, 105, 136, 167, 198, 229, 4, 35, 66, 97], 3n)))
    IO.print("push-28-truncated:" ++ R.state(VM.run([123, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-29-endian:" ++ R.state(VM.run([124, 29, 60, 91, 122, 153, 184, 215, 246, 21, 52, 83, 114, 145, 176, 207, 238, 13, 44, 75, 106, 137, 168, 199, 230, 5, 36, 67, 98, 129], 3n)))
    IO.print("push-29-truncated:" ++ R.state(VM.run([124, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-30-endian:" ++ R.state(VM.run([125, 30, 61, 92, 123, 154, 185, 216, 247, 22, 53, 84, 115, 146, 177, 208, 239, 14, 45, 76, 107, 138, 169, 200, 231, 6, 37, 68, 99, 130, 161], 3n)))
    IO.print("push-30-truncated:" ++ R.state(VM.run([125, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-31-endian:" ++ R.state(VM.run([126, 31, 62, 93, 124, 155, 186, 217, 248, 23, 54, 85, 116, 147, 178, 209, 240, 15, 46, 77, 108, 139, 170, 201, 232, 7, 38, 69, 100, 131, 162, 193], 3n)))
    IO.print("push-31-truncated:" ++ R.state(VM.run([126, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("push-32-endian:" ++ R.state(VM.run([127, 32, 63, 94, 125, 156, 187, 218, 249, 24, 55, 86, 117, 148, 179, 210, 241, 16, 47, 78, 109, 140, 171, 202, 233, 8, 39, 70, 101, 132, 163, 194, 225], 3n)))
    IO.print("push-32-truncated:" ++ R.state(VM.run([127, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254], 3n)))
    IO.print("unsupported-2:" ++ R.state(VM.run([2], 13n)))
    IO.print("unsupported-32:" ++ R.state(VM.run([32], 13n)))
    IO.print("unsupported-81:" ++ R.state(VM.run([81], 13n)))
    IO.print("unsupported-94:" ++ R.state(VM.run([94], 13n)))
    IO.print("unsupported-128:" ++ R.state(VM.run([128], 13n)))
