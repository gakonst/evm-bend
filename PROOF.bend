import ./word-spec.bend as WordSpec
import ./word-proof.bend as WordProof
import ./stack-proof.bend as StackProof
import Base
import ./gas.bend as Gas
import ./LAWS.bend as Laws

def Laws.gas_exact(cost, remaining):
  match cost:
    case 0n:
      {==}
    case 1n+c:
      Laws.gas_exact(c, remaining)

def Laws.gas_short(gas):
  match gas:
    case 0n:
      {==}
    case 1n+g:
      Laws.gas_short(g)

def Laws.stop(gas, pc, stack):
  {==}

def Laws.pop(remaining, pc, top, rest):
  {==}

def Laws.add(remaining, pc, a, b, rest):
  {==}

def Laws.add_underflow(remaining, pc, top):
  {==}

def Laws.invalid_burns_gas(gas, pc, stack):
  {==}
