import Base

law zero_le:
  for n: Nat
  {Nat.is_le(0n, n) == True{} : Bool}

def zero_le(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

# The strict pre-push check is exactly the post-push inclusive bound.
law successor_bound:
  for n: Nat
  for limit: Nat
  {Nat.is_le(1n+n, limit) == Nat.is_lt(n, limit) : Bool}

def successor_bound(n, limit):
  match n limit:
    case 0n 0n:
      {==}
    case 0n 1n+p:
      zero_le(p)
    case 1n+p 0n:
      {==}
    case 1n+p 1n+q:
      successor_bound(p, q)
