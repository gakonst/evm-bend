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
    IO.print("empty:" ++ R.state(VM.run([], 0n)))
    IO.print("stop-retains-pc:" ++ R.state(VM.run([0, 254], 9n)))
    IO.print("add-oog-before-underflow:" ++ R.state(VM.run([1], 2n)))
    IO.print("add-underflow:" ++ R.state(VM.run([1], 3n)))
    IO.print("pop-oog-before-underflow:" ++ R.state(VM.run([80], 1n)))
    IO.print("pop-underflow:" ++ R.state(VM.run([80], 2n)))
    IO.print("one-add-underflow-retains-stack:" ++ R.state(VM.run([96, 23, 1], 6n)))
    IO.print("one-add-oog-retains-stack:" ++ R.state(VM.run([96, 23, 1], 5n)))
    IO.print("invalid-retains-stack:" ++ R.state(VM.run([96, 23, 254], 20n)))
    IO.print("invalid-zero-gas:" ++ R.state(VM.run([254], 0n)))
    IO.print("unsupported-retains-gas-stack:" ++ R.state(VM.run([96, 23, 2], 20n)))
    IO.print("push0-exact:" ++ R.state(VM.run([95], 2n)))
    IO.print("push0-oog:" ++ R.state(VM.run([95], 1n)))
    IO.print("push1-exact:" ++ R.state(VM.run([96, 7], 3n)))
    IO.print("push1-oog:" ++ R.state(VM.run([96, 7], 2n)))
    IO.print("pop-exact:" ++ R.state(VM.run([95, 80], 4n)))
