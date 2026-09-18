import Base
import ../evmword.bend as W
import ./transaction-types.bend as T
import ./transaction-environment.bend as Env
import ./codec.bend as C
import ./model.bend as M
import ./render.bend as R
import ./transaction-wide.bend as Tx
import ./transaction-runtime.bend as Run
import ./transaction-finish.bend as F
import ./transaction-codec.bend as Codec

def render_gas(gas: Tx.Settlement) -> String:
  match gas:
    case Tx.Gas{used,left,execution,state}:
      R.append("{\"used\":", R.append(R.word(used), R.append(",\"left\":", R.append(R.word(left), R.append(",\"execution\":", R.append(R.word(execution), R.append(",\"state\":", R.append(R.word(state), "}"))))))))

def completed(result: Tx.Completion) -> IO(Unit):
  match result:
    case Tx.Incomplete{}: IO.print("{\"status\":\"host_error\",\"reason\":\"incomplete_execution\"}")
    case Tx.Completed{engine,gas,reservoir}:
      IO.print(R.append("{\"status\":\"executed\",\"frame\":", R.append(R.engine(engine), R.append(",\"transaction_gas\":", R.append(render_gas(gas), "}")))))

def prepared(result: Tx.Preparation) -> IO(Unit):
  match result:
    case Tx.Rejected{reason}: IO.print(R.append("{\"status\":\"rejected\",\"reason\":", R.append(U32.show(reason), "}")))
    case Tx.Prepared{engine,metadata,gas,+escrow}:
      do IO<Unit>:
        terminal : M.Engine <- Tx.execute(engine,escrow)
        completed(Tx.finish(metadata,gas,escrow,terminal))

def priced(price: +Maybe<W.Word>,tx: Tx.Transaction,world: M.World,context: M.Context) -> IO(Unit):
  match price:
    case None{}: IO.print("{\"status\":\"host_error\",\"reason\":\"blob_price_representation_limit\"}")
    case Some{price}: prepared(Tx.prepare(tx,world,M.Context.set_blobbasefee(context,price)))

def launch(input: Codec.Input) -> IO(Unit):
  match input:
    case Codec.Input{tx,world,context,excess,False{}}: IO.print("{\"status\":\"host_error\",\"reason\":\"invalid_binary_input\"}")
    case Codec.Input{tx,world,context,excess,True{}}: priced(Env.blobbasefee(excess),tx,world,context)

def consume(pair: File & Result<&1,&1,U32 & String,+List<U32>>) -> IO(Unit):
  match pair:
    case (file,result):
      do IO<Unit>:
        File.close(file)
        data : +List<U32> <- IO.pass(+List<U32>,result)
        launch(Codec.decode(data))

def main() -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String,IO.get_env("BEND_EVM_INPUT"))
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,+List<U32>> <- File.read_bytes(file,16777216)
    consume(result)
