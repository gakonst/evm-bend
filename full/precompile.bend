import Base
import ../evmword.bend as W

# Trusted crypto adapter only. EVM control flow stays in Bend.
def supported(+address: W.Word) -> Bool:
  +n = W.low_u32(address)
  Bool.and(W.eq(address, W.from_u32(n)), Bool.or(Bool.and(U32.is_ge(n, 1), U32.is_le(n, 17)), U32.is_eq(n, 256)))

def be(count: Nat, +value: Nat, tail: +List<U32>) -> +List<U32>:
  match count:
    case 0n:
      tail
    case 1n+p:
      be(p, Nat.div(value, 256n), U32.from_nat(Nat.mod(value, 256n)) <> tail)

def precompile_host(input: +List<U32>) -> IO(+List<U32>):
  import "./precompile.c"
  import "./precompile.js"

# Wire result: status byte, eight gas-remaining bytes, then output bytes.
# Status 0 succeeds, 1 is an exceptional precompile failure, 2 is a host error.
def run(address: U32, +gas: Nat, input: +List<U32>) -> IO(+List<U32>):
  precompile_host(be(4n, U32.to_nat(address), be(8n, gas, input)))

