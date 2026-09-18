import Base
import ./vm.bend as VM
import ./render.bend as R

def main() -> IO(Unit):
  IO.print(R.state(VM.run([96, 2, 96, 3, 1, 0], 100n)))
