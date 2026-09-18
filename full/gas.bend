import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ../gas.bend as Checked
import ./model.bend as M

def failed(action: M.Action) -> Bool:
  match action:
    case M.Fault{reason}:
      True{}
    case M.HostLimit{}:
      True{}
    case other:
      False{}

def charged(left: Maybe<&2, Nat>, frame: M.Frame) -> M.Frame:
  match left:
    case None{}:
      M.fault(frame, 1)
    case Some{n}:
      M.Frame.set_gas(frame, n)

def charge(+frame: M.Frame, cost: Nat) -> M.Frame:
  charged(Checked.charge(cost, M.Frame.gas(frame)), frame)

def minimum_if(smaller: Bool, a: Nat, b: Nat) -> Nat:
  match smaller:
    case True{}:
      a
    case False{}:
      b

def minimum(+a: Nat, +b: Nat) -> Nat:
  minimum_if(Nat.is_lt(a, b), a, b)

def state_paid(bad: Bool, +engine: M.Engine, cost: Nat, spill: Nat, reservoir: Nat) -> M.Engine:
  match bad:
    case True{}:
      engine
    case False{}:
      M.Engine.set_state_used(M.Engine.set_state_spilled(M.Engine.set_reservoir(engine, reservoir), Nat.add(M.Engine.state_spilled(engine), spill)), W.add(M.Engine.state_used(engine), O.from_nat(cost)))

def state_after_charge(+engine: M.Engine, cost: Nat, spill: Nat, reservoir: Nat) -> M.Engine:
  state_paid(failed(M.Frame.action(M.Engine.frame(engine))), engine, cost, spill, reservoir)

def spend_state(+engine: M.Engine, +cost: Nat) -> M.Engine:
  +from_reservoir = minimum(cost, M.Engine.reservoir(engine))
  +spill = Nat.sub(cost, from_reservoir)
  +reservoir = Nat.sub(M.Engine.reservoir(engine), from_reservoir)
  state_after_charge(M.Engine.set_frame(engine, charge(M.Engine.frame(engine), spill)), cost, spill, reservoir)

# Refills the last funding pool first; state_used is signed two's-complement.
def refill(+engine: M.Engine, +amount: Nat) -> M.Engine:
  +to_execution = minimum(amount, M.Engine.state_spilled(engine))
  +frame = M.Engine.frame(engine)
  M.Engine.set_state_used(
    M.Engine.set_state_spilled(
      M.Engine.set_reservoir(
        M.Engine.set_frame(engine, M.Frame.set_gas(frame, Nat.add(M.Frame.gas(frame), to_execution))),
        Nat.add(M.Engine.reservoir(engine), Nat.sub(amount, to_execution))),
      Nat.sub(M.Engine.state_spilled(engine), to_execution)),
    O.sub(M.Engine.state_used(engine), O.from_nat(amount)))

def successful(action: M.Action) -> Bool:
  match action:
    case M.Stopped{}:
      True{}
    case M.Returned{}:
      True{}
    case other:
      False{}

def reverted(action: M.Action) -> Bool:
  match action:
    case M.Reverted{}:
      True{}
    case other:
      False{}

def rollback(+engine: M.Engine) -> M.Engine:
  +frame = M.Engine.frame(engine)
  restored = O.to_nat(O.sub(W.add(O.from_nat(M.Engine.reservoir(engine)), M.Engine.state_used(engine)), O.from_nat(M.Engine.state_spilled(engine))))
  M.Engine.set_state_spilled(M.Engine.set_state_used(M.Engine.set_reservoir(M.Engine.set_frame(engine, M.Frame.set_gas(frame, Nat.add(M.Frame.gas(frame), M.Engine.state_spilled(engine)))), restored), W.zero()), 0n)

def settle_rollback(is_revert: Bool, +engine: M.Engine) -> M.Engine:
  match is_revert:
    case True{}:
      engine
    case False{}:
      M.Engine.set_frame(engine, M.Frame.set_gas(M.Engine.frame(engine), 0n))

def settle_if(success: Bool, +engine: M.Engine) -> M.Engine:
  match success:
    case True{}:
      engine
    case False{}:
      settle_rollback(reverted(M.Frame.action(M.Engine.frame(engine))), rollback(engine))

def settle(+engine: M.Engine) -> M.Engine:
  settle_if(successful(M.Frame.action(M.Engine.frame(engine))), engine)

# Adopt a child's shared reservoir, repairing the parent's execution spill.
def absorb(+engine: M.Engine, +returned: Nat) -> M.Engine:
  +restore = minimum(returned, M.Engine.state_spilled(engine))
  +frame = M.Engine.frame(engine)
  M.Engine.set_reservoir(M.Engine.set_state_spilled(M.Engine.set_frame(engine, M.Frame.set_gas(frame, Nat.add(M.Frame.gas(frame), restore))), Nat.sub(M.Engine.state_spilled(engine), restore)), Nat.sub(returned, restore))
