import Base
import ./evmword.bend as W
import ./core.bend as E

def status(s: E.Status) -> String:
  match s:
    case E.Running{}:
      "running"
    case E.Halted{}:
      "halted"
    case E.OutOfGas{}:
      "out_of_gas"
    case E.Underflow{}:
      "underflow"
    case E.Overflow{}:
      "overflow"
    case E.BadOpcode{}:
      "invalid"
    case E.NotImplemented{b}:
      "unsupported"
    case E.FuelExhausted{}:
      "fuel_exhausted"

def stack(xs: +List<W.Word>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      W.show(x) ++ ";" ++ stack(rest)

def state(s: E.State) -> String:
  match s:
    case E.S{gas, pc, xs, st}:
      status(st) ++ "|" ++ Nat.show(gas) ++ "|" ++ Nat.show(pc) ++ "|" ++ stack(xs)
