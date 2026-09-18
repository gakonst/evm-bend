import Base

# Exact checked subtraction. None means insufficient gas.
def charge(cost: Nat, gas: Nat) -> Maybe<&2, Nat>:
  match cost:
    case 0n:
      Some{gas}
    case 1n+c:
      match gas:
        case 0n:
          None{}
        case 1n+g:
          charge(c, g)
