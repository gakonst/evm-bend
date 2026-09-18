import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./gas.bend as G
import ./bytes.bend as B
import ./vm.bend as VM
import ./precompile.bend as P

type Decision is Data:
  Done{engine: M.Engine}
  Tick{machine: M.Machine}
  Pre{address: U32, machine: M.Machine}

def finished(done: Bool, +machine: M.Machine) -> Decision:
  match done:
    case True{}:
      Done{M.Machine.engine(machine)}
    case False{}:
      Tick{machine}

def action(a: M.Action, +machine: M.Machine) -> Decision:
  match a:
    case M.Precompile{address}:
      Pre{address, machine}
    case M.HostLimit{}:
      Done{M.Machine.engine(machine)}
    case other:
      finished(VM.finished(machine), machine)

def decide(+machine: M.Machine) -> Decision:
  action(M.Frame.action(M.Engine.frame(M.Machine.engine(machine))), machine)

def bytes_nat(n: Nat, data: +List<U32>, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      match data:
        case Nil{}:
          0n
        case Con{x, rest}:
          bytes_nat(p, rest, Nat.add(Nat.mul(acc, 256n), U32.to_nat(x)))

def precompile_status(status: U32, +machine: M.Machine, output: +List<U32>, gas: Nat) -> M.Machine:
  match status:
    case 0:
      +engine = M.Machine.engine(machine)
      frame = M.Frame.set_action(M.Frame.set_gas(M.Frame.set_output(M.Engine.frame(engine), output), gas), M.Returned{})
      M.Machine.set_engine(machine, M.Engine.set_frame(engine, frame))
    case 1:
      +engine = M.Machine.engine(machine)
      M.Machine.set_engine(machine, M.Engine.set_frame(engine, M.fault(M.Engine.frame(engine), 9)))
    case other:
      +engine = M.Machine.engine(machine)
      M.Machine.set_engine(machine, M.Engine.set_frame(engine, M.Frame.set_action(M.Engine.frame(engine), M.HostLimit{})))

def precompile_resume(valid: Bool, machine: M.Machine, +data: +List<U32>) -> M.Machine:
  match valid:
    case False{}:
      precompile_status(2, machine, Nil{}, 0n)
    case True{}:
      precompile_status(B.get(0n, data), machine, B.drop(9n, data), bytes_nat(8n, B.drop(1n, data), 0n))

def resume(+data: +List<U32>, machine: M.Machine) -> M.Machine:
  precompile_resume(Nat.is_ge(B.len(data), 9n), machine, data)

def exhausted(decision: Decision) -> M.Engine:
  match decision:
    case Done{engine}:
      engine
    case Tick{machine}:
      +engine = M.Machine.engine(machine)
      M.Engine.set_frame(engine, M.Frame.set_action(M.Engine.frame(engine), M.HostLimit{}))
    case Pre{address, machine}:
      +engine = M.Machine.engine(machine)
      M.Engine.set_frame(engine, M.Frame.set_action(M.Engine.frame(engine), M.HostLimit{}))

def loop(fuel: Nat, decision: Decision) -> IO(M.Engine):
  match fuel:
    case 0n:
      IO.pure(M.Engine, exhausted(decision))
    case 1n+f:
      match decision:
        case Done{engine}:
          IO.pure(M.Engine, engine)
        case Tick{machine}:
          loop(f, decide(VM.step(machine)))
        case Pre{address, +machine}:
          do IO<M.Engine>:
            response : +List<U32> <- P.run(address, M.Frame.gas(M.Engine.frame(M.Machine.engine(machine))), M.Frame.input(M.Engine.frame(M.Machine.engine(machine))))
            loop(f, decide(resume(response, machine)))

def initial_precompile(is_precompile: Bool, +engine: M.Engine) -> M.Engine:
  match is_precompile:
    case False{}:
      engine
    case True{}:
      +frame = M.Engine.frame(engine)
      M.Engine.set_frame(engine, M.Frame.set_action(frame, M.Precompile{W.low_u32(M.Frame.address(frame))}))

def run(+engine: M.Engine) -> IO(M.Engine):
  # Every looping opcode spends execution gas; extra fuel covers frame unwinding.
  # This is a host guard, not a substitute for the protocol gas accounting.
  fuel = Nat.add(Nat.mul(4n, Nat.add(M.Frame.gas(M.Engine.frame(engine)), M.Engine.reservoir(engine))), U32.to_nat(4096))
  loop(fuel, decide(M.Machine{initial_precompile(P.supported(M.Frame.address(M.Engine.frame(engine))), engine), Nil{}}))
