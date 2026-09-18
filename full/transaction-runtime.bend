import Base
import ./model.bend as M
import ./runtime.bend as Runtime
import ./gas.bend as G
import ../word-ops.bend as O
import ./transaction.bend as Tx
import ./transaction-types.bend as T

# Prepared frames already select dispatch, including delegated precompile
# suppression and top CREATE. Runtime.run's address-only initial dispatch must
# not be applied a second time.
def execute(+engine: M.Engine) -> IO(M.Engine):
  +maxnat = Nat.add(Nat.mul(U32.to_nat(65535),O.radix32()),U32.to_nat(4294967295))
  +limit = Nat.div(Nat.sub(maxnat,U32.to_nat(4096)),4n)
  +pool = Nat.add(M.Frame.gas(M.Engine.frame(engine)),M.Engine.reservoir(engine))
  fuel = Nat.add(Nat.mul(4n,G.minimum(pool,limit)),U32.to_nat(4096))
  Runtime.loop(fuel,Runtime.decide(M.Machine{engine,Nil{}}))

def prepared(result: Tx.Preparation) -> IO(Tx.Completion):
  match result:
    case Tx.Rejected{reason}: IO.pure(Tx.Completion,Tx.Incomplete{})
    case Tx.Prepared{engine,metadata}:
      do IO<Tx.Completion>:
        terminal : M.Engine <- execute(engine)
        return Tx.finish(metadata,terminal)

# Call prepare separately when rejection reason must be preserved.
def run(tx: T.Transaction, world: M.World, context: M.Context) -> IO(Tx.Completion):
  prepared(Tx.prepare(tx,world,context))
