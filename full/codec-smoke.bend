import Base
import ./codec.bend as C
import ./render.bend as R

def consume(pair: File & Result<&1, &1, U32 & String, +List<U32>>) -> IO(Unit):
  match pair:
    case (file, result):
      do IO<Unit>:
        File.close(file)
        data : +List<U32> <- IO.pass(+List<U32>, result)
        IO.print(R.engine(C.EngineRead.value(C.decode(data))))

def main() -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String, IO.get_env("BEND_EVM_INPUT"))
    file : File <- IO.try(File, File.open(path, "r"))
    result : File & Result<&1, &1, U32 & String, +List<U32>> <- File.read_bytes(file, 16777216)
    consume(result)
