import Base
import ./evmword.bend as W
import ./gas.bend as Gas

type Op is Data:
  Stop{}
  Push{width: Nat, value: W.Word}
  Add{}
  Pop{}
  Invalid{}
  Unsupported{byte: U32}

type Status is Data:
  Running{}
  Halted{}
  OutOfGas{}
  Underflow{}
  Overflow{}
  BadOpcode{}
  NotImplemented{byte: U32}
  FuelExhausted{}

type State is Data:
  S{gas: Nat, pc: Nat, stack: +List<W.Word>, status: Status}

def cost(op: Op) -> Nat:
  match op:
    case Stop{}:
      0n
    case Push{0n, v}:
      2n
    case Push{1n+p, v}:
      3n
    case Add{}:
      3n
    case Pop{}:
      2n
    case Invalid{}:
      0n
    case Unsupported{b}:
      0n

# Faults consume frame gas. Retained stack/pc are diagnostic, not committed state.
def fault(pc: Nat, stack: +List<W.Word>, status: Status) -> State:
  S{0n, pc, stack, status}

def push_checked(ok: Bool, gas: Nat, +pc: Nat, +width: Nat, value: W.Word, stack: +List<W.Word>) -> State:
  match ok:
    case False{}:
      fault(pc, stack, Overflow{})
    case True{}:
      S{gas, Nat.add(pc, 1n+width), value <> stack, Running{}}

def add_stack(stack: +List<W.Word>, gas: Nat, pc: Nat) -> State:
  match stack:
    case Nil{}:
      fault(pc, Nil{}, Underflow{})
    case Con{a, Nil{}}:
      fault(pc, a <> Nil{}, Underflow{})
    case Con{a, Con{b, rest}}:
      S{gas, 1n+pc, W.add(a, b) <> rest, Running{}}

def pop_stack(stack: +List<W.Word>, gas: Nat, pc: Nat) -> State:
  match stack:
    case Nil{}:
      fault(pc, Nil{}, Underflow{})
    case Con{a, rest}:
      S{gas, 1n+pc, rest, Running{}}

def execute(op: Op, gas: Nat, pc: Nat, +stack: +List<W.Word>) -> State:
  match op:
    case Stop{}:
      S{gas, pc, stack, Halted{}}
    case Push{width, value}:
      push_checked(Nat.is_lt(List.length(&2, W.Word, stack), 1024n), gas, pc, width, value, stack)
    case Add{}:
      add_stack(stack, gas, pc)
    case Pop{}:
      pop_stack(stack, gas, pc)
    case Invalid{}:
      fault(pc, stack, BadOpcode{})
    case Unsupported{b}:
      S{gas, pc, stack, NotImplemented{b}}

def charged(remaining: Maybe<&2, Nat>, op: Op, pc: Nat, stack: +List<W.Word>) -> State:
  match remaining:
    case None{}:
      fault(pc, stack, OutOfGas{})
    case Some{g}:
      execute(op, g, pc, stack)

def step(+op: Op, gas: Nat, pc: Nat, stack: +List<W.Word>) -> State:
  charged(Gas.charge(cost(op), gas), op, pc, stack)
