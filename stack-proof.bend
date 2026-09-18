import Base
import ./evmword.bend as W
import ./core.bend as E
import ./capacity.bend as C

# Terminal faults do not continue execution with an invalid stack.
def running_bounded(s: E.State) -> Bool:
  match s:
    case E.S{g, pc, xs, E.Running{}}:
      Nat.is_le(List.length(&2, W.Word, xs), 1024n)
    case E.S{g, pc, xs, st}:
      True{}

law push_branch:
  for ok: Bool
  for gas: Nat
  for pc: Nat
  for width: Nat
  for value: W.Word
  for +stack: +List<W.Word>
  for evidence: {Nat.is_lt(List.length(&2, W.Word, stack), 1024n) == ok : Bool}
  {running_bounded(E.push_checked(ok, gas, pc, width, value, stack)) == True{} : Bool}

def push_branch(ok, gas, pc, width, value, stack, evidence):
  match ok:
    case False{}:
      {==}
    case True{}:
      Equal.trans(Bool,
        Nat.is_le(1n+List.length(&2, W.Word, stack), 1024n),
        Nat.is_lt(List.length(&2, W.Word, stack), 1024n), True{},
        C.successor_bound(List.length(&2, W.Word, stack), 1024n), evidence)

# This quantifies over every stack and every word, including oversized inputs.
# Successful execution of PUSH cannot produce an oversized running stack.
law push_bounded:
  for gas: Nat
  for pc: Nat
  for width: Nat
  for value: W.Word
  for +stack: +List<W.Word>
  {running_bounded(E.execute(E.Push{width, value}, gas, pc, stack)) == True{} : Bool}

def push_bounded(gas, pc, width, value, stack):
  push_branch(Nat.is_lt(List.length(&2, W.Word, stack), 1024n), gas, pc, width, value, stack, {==})
