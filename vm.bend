import Base
import ./evmword.bend as W
import ./core.bend as E
import ./decode.bend as D

type Frame is Type:
  F{state: E.State, code: +List<U32>}

def advance(decoded: E.Op & +List<U32>, gas: Nat, pc: Nat, stack: +List<W.Word>) -> Frame:
  match decoded:
    case (op, rest):
      F{E.step(op, gas, pc, stack), rest}

# Fuel exhaustion is a host condition, not EVM out-of-gas.
def exhausted(state: E.State) -> E.State:
  match state:
    case E.S{gas, pc, stack, E.Running{}}:
      E.S{gas, pc, stack, E.FuelExhausted{}}
    case E.S{gas, pc, stack, status}:
      E.S{gas, pc, stack, status}

def loop(fuel: Nat, frame: Frame) -> E.State:
  match fuel:
    case 0n:
      match frame:
        case F{state, code}:
          exhausted(state)
    case 1n+f:
      match frame:
        case F{E.S{gas, pc, stack, E.Running{}}, code}:
          loop(f, advance(D.next(code), gas, pc, stack))
        case F{E.S{gas, pc, stack, status}, code}:
          E.S{gas, pc, stack, status}

def run(+code: +List<U32>, gas: Nat) -> E.State:
  loop(2n+List.length(&2, U32, code), F{E.S{gas, 0n, Nil{}, E.Running{}}, code})
