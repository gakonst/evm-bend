import Base
import ./model.bend as M
import ./codec.bend as C
import ./render.bend as R
import ./runtime.bend as Run
import ./gas.bend as G

def finish_ok(success: Bool, engine: M.Engine, initial: M.World) -> IO(Unit):
  match success:
    case True{}:
      IO.print(R.engine(engine))
    case False{}:
      IO.print(R.engine(M.Engine.set_world(engine, initial)))

def finish(action: M.Action, engine: M.Engine, initial: M.World) -> IO(Unit):
  match action:
    case M.HostLimit{}:
      IO.print("{\"error\":\"host_resource_or_precompile_failure\"}")
    case other:
      finish_ok(G.successful(other), G.settle(engine), initial)

def finish_result(+result: M.Engine, initial: M.World) -> IO(Unit):
  finish(M.Frame.action(M.Engine.frame(result)), result, initial)

def launch_valid(valid: Bool, +engine: M.Engine) -> IO(Unit):
  match valid:
    case False{}:
      IO.print("{\"error\":\"invalid_binary_input\"}")
    case True{}:
      do IO<Unit>:
        result : M.Engine <- Run.run(engine)
        finish_result(result, M.Engine.world(engine))

def launch(+decoded: C.EngineRead) -> IO(Unit):
  launch_valid(C.valid(C.EngineRead.reader(decoded)), C.EngineRead.value(decoded))

def consume(pair: File & Result<&1, &1, U32 & String, +List<U32>>) -> IO(Unit):
  match pair:
    case (file, result):
      do IO<Unit>:
        File.close(file)
        data : +List<U32> <- IO.pass(+List<U32>, result)
        launch(C.decode(data))

def main() -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String, IO.get_env("BEND_EVM_INPUT"))
    file : File <- IO.try(File, File.open(path, "r"))
    result : File & Result<&1, &1, U32 & String, +List<U32>> <- File.read_bytes(file, 16777216)
    consume(result)
