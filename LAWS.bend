import Base
import ./gas.bend as Gas
import ./evmword.bend as W
import ./core.bend as E

# Every affordable charge returns exactly the unspent gas.
law gas_exact:
  for cost: Nat
  for remaining: Nat
  {Gas.charge(cost, Nat.add(cost, remaining)) == Some{remaining} : Maybe<&2, Nat>}

# Being one gas short always fails, rather than wrapping/saturating.
law gas_short:
  for gas: Nat
  {Gas.charge(1n+gas, gas) == None{} : Maybe<&2, Nat>}


# STOP preserves every remaining gas unit and the stack.
law stop:
  for gas: Nat
  for pc: Nat
  for stack: +List<W.Word>
  {E.step(E.Stop{}, gas, pc, stack) == E.S{gas, pc, stack, E.Halted{}} : E.State}

# POP consumes exactly two gas and exactly the top element.
law pop:
  for remaining: Nat
  for pc: Nat
  for top: W.Word
  for rest: +List<W.Word>
  {E.step(E.Pop{}, 2n+remaining, pc, top <> rest) == E.S{remaining, 1n+pc, rest, E.Running{}} : E.State}

# ADD consumes three gas, pops two and pushes their modular sum.
# This theorem does not independently prove W.add's arithmetic refinement.
law add:
  for remaining: Nat
  for pc: Nat
  for a: W.Word
  for b: W.Word
  for rest: +List<W.Word>
  {E.step(E.Add{}, 3n+remaining, pc, a <> b <> rest) == E.S{remaining, 1n+pc, W.add(a, b) <> rest, E.Running{}} : E.State}

law add_underflow:
  for remaining: Nat
  for pc: Nat
  for top: W.Word
  {E.step(E.Add{}, 3n+remaining, pc, top <> Nil{}) == E.S{0n, pc, top <> Nil{}, E.Underflow{}} : E.State}

law invalid_burns_gas:
  for gas: Nat
  for pc: Nat
  for stack: +List<W.Word>
  {E.step(E.Invalid{}, gas, pc, stack) == E.S{0n, pc, stack, E.BadOpcode{}} : E.State}
