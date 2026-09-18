import Base
import ../evmword.bend as W
import ./transaction-types.bend as T

# State-dependent creation and authorization gas is charged during preparation.
# EELS calculate_intrinsic_cost itself has no state gas component.
type Intrinsic is Data:
  Intrinsic{execution: Nat, floor: Nat, state: Nat}

def Intrinsic.execution(x: Intrinsic) -> Nat:
  match x:
    case Intrinsic{execution, floor, state}:
      execution

def Intrinsic.floor(x: Intrinsic) -> Nat:
  match x:
    case Intrinsic{execution, floor, state}:
      floor

def Intrinsic.state(x: Intrinsic) -> Nat:
  match x:
    case Intrinsic{execution, floor, state}:
      state

def select(test: Bool, yes: Nat, no: Nat) -> Nat:
  match test:
    case True{}:
      yes
    case False{}:
      no

def recipient(to: +Maybe<W.Word>, sender: W.Word, value: W.Word) -> Nat:
  match to:
    case None{}:
      U32.to_nat(12000)
    case Some{address}:
      select(W.eq(address, sender), 0n, select(W.is_zero(value), U32.to_nat(3000), U32.to_nat(9000)))

def initcode(to: +Maybe<W.Word>, size: Nat) -> Nat:
  match to:
    case None{}:
      Nat.mul(2n, Nat.div(Nat.add(size, 31n), 32n))
    case Some{address}:
      0n

# All input traversals are tail recursive: valid large lists must not consume
# one JavaScript call-stack frame per byte, key, entry, or authorization.
def length_acc(-A: Data, entries: +List<A>, count: Nat) -> Nat:
  match entries:
    case Nil{}:
      count
    case Con{entry, rest}:
      length_acc(A, rest, Nat.add(count, 1n))

def length(-A: Data, entries: +List<A>) -> Nat:
  length_acc(A, entries, 0n)

def calldata_acc(data: +List<U32>, cost: Nat) -> Nat:
  match data:
    case Nil{}:
      cost
    case Con{byte, rest}:
      calldata_acc(rest, Nat.add(cost, select(U32.is_eq(byte, 0), 4n, 16n)))

def calldata(data: +List<U32>) -> Nat:
  calldata_acc(data, 0n)

# Count every entry and key, including duplicates. This is distinct from warming.
def access_execution_acc(entries: +List<T.Access>, cost: Nat) -> Nat:
  match entries:
    case Nil{}:
      cost
    case Con{entry, rest}:
      access_execution_acc(rest, Nat.add(cost, Nat.add(U32.to_nat(2900), Nat.mul(U32.to_nat(2000), length(W.Word, T.Access.keys(entry))))))

def access_execution(entries: +List<T.Access>) -> Nat:
  access_execution_acc(entries, 0n)

def access_data_acc(entries: +List<T.Access>, cost: Nat) -> Nat:
  match entries:
    case Nil{}:
      cost
    case Con{entry, rest}:
      access_data_acc(rest, Nat.add(cost, Nat.add(U32.to_nat(1280), Nat.mul(U32.to_nat(2048), length(W.Word, T.Access.keys(entry))))))

def access_data(entries: +List<T.Access>) -> Nat:
  access_data_acc(entries, 0n)

def typed_access(kind: U32, entries: +List<T.Access>) -> +List<T.Access>:
  match kind:
    case 0:
      Nil{}
    case _:
      entries

def authorization_cost(kind: U32, entries: +List<T.Authorization>) -> Nat:
  match kind:
    case 4:
      Nat.mul(U32.to_nat(7816), length(T.Authorization, entries))
    case _:
      0n

# Requires validated kind 0..4 and canonical bytes. Nat arithmetic must stay
# within the declared host bound; resource exhaustion is not EVM out-of-gas.
def compute(+tx: T.Transaction) -> Intrinsic:
  +size = length(U32, T.Transaction.data(tx))
  +base = Nat.add(U32.to_nat(12000), recipient(T.Transaction.to(tx), T.Transaction.sender(tx), T.Transaction.value(tx)))
  +access = typed_access(T.Transaction.kind(tx), T.Transaction.access_list(tx))
  +surcharge = access_data(access)
  execution = Nat.add(base, Nat.add(initcode(T.Transaction.to(tx), size), Nat.add(calldata(T.Transaction.data(tx)), Nat.add(access_execution(access), Nat.add(surcharge, authorization_cost(T.Transaction.kind(tx), T.Transaction.authorizations(tx)))))))
  floor = Nat.add(base, Nat.add(Nat.mul(64n, size), surcharge))
  Intrinsic{execution, floor, 0n}
