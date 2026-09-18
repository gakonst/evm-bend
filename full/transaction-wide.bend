import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./world.bend as World
import ./gas.bend as G
import ./transaction-types.bend as T
import ./transaction-intrinsic.bend as I
import ./transaction-validate.bend as V
import ./transaction.bend as Tx
import ./transaction-finish.bend as F
import ./runtime.bend as Runtime
import ./vm.bend as VM
import ./precompile.bend as P
import ./transaction-world.bend as TW
import ./bytes.bend as B

# Exact total gas. Nested v1 gas is ignored. See transaction-wide-api.md.
type Transaction is Data:
  WideTx{transaction: T.Transaction, gas: W.Word}
type Preparation is Data:
  Rejected{reason: U32}
  Prepared{engine: M.Engine, metadata: F.Metadata, gas: W.Word, escrow: W.Word}
type Settlement is Data:
  Gas{used: W.Word, left: W.Word, execution: W.Word, state: W.Word}
type Completion is Data:
  Incomplete{}
  Completed{engine: M.Engine, gas: Settlement, reservoir: W.Word}

# 2^44: enough for all state charges admitted by the 2^24 execution budget.
def window() -> Nat:
  Nat.mul(U32.to_nat(4096),O.radix32())

def proxy(tx: T.Transaction, gas: Nat) -> T.Transaction:
  match tx:
    case T.Tx{kind,sender,nonce,old,to,value,data,chainid,fee_cap,tip,blob_fee_cap,blobhashes,access_list,authorizations}:
      T.Tx{kind,sender,nonce,gas,to,value,data,chainid,fee_cap,tip,blob_fee_cap,blobhashes,access_list,authorizations}

def bounded(+gas: W.Word) -> Nat:
  O.to_nat(V.choose(O.gt(gas,O.from_nat(window())),O.from_nat(window()),gas))

def validate(+tx: T.Transaction, +gasword: W.Word, world: M.World, +context: M.Context) -> U32:
  +kind = T.Transaction.kind(tx)
  +account = World.account(world,T.Transaction.sender(tx))
  +cap = T.Transaction.fee_cap(tx)
  +blobcap = T.Transaction.blob_fee_cap(tx)
  +bg = V.blob_gas(tx)
  +fee = O.mul(gasword,cap)
  +blobfee = O.mul(bg,blobcap)
  +fees = W.add(fee,blobfee)
  +value = T.Transaction.value(tx)
  +nblobs = V.blob_count(T.Transaction.blobhashes(tx))
  +create = V.creation(T.Transaction.to(tx))
  +plain = U32.is_lt(kind,2)
  +blob = U32.is_eq(kind,3)
  +auth = U32.is_eq(kind,4)
  V.reject(U32.is_gt(kind,4) || Bool.not(V.canonical_address(T.Transaction.sender(tx)) && V.destination(T.Transaction.to(tx)) && V.bytes_valid(T.Transaction.data(tx)) && V.access_valid(T.Transaction.access_list(tx))) || (U32.is_eq(kind,0) && Bool.not(V.access_empty(T.Transaction.access_list(tx)))) || (plain && Bool.not(W.eq(cap,T.Transaction.tip(tx)))) || (Bool.not(blob) && (Nat.is_ne(nblobs,0n) || Bool.not(W.is_zero(blobcap)))) || (Bool.not(auth) && Bool.not(V.auth_empty(T.Transaction.authorizations(tx)))),1,
    V.reject(Bool.not(V.chain_valid(T.Transaction.chainid(tx),kind,M.Context.chainid(context))),2,
    V.reject(O.gt(T.Transaction.nonce(tx),W.W{4294967295,4294967295,0,0,0,0,0,0}),22,
    V.reject(W.eq(T.Transaction.nonce(tx),W.W{4294967295,4294967295,0,0,0,0,0,0}),3,
    V.reject(create && Nat.is_gt(B.len(T.Transaction.data(tx)),U32.to_nat(131072)),4,
    V.reject(O.gt(T.Transaction.tip(tx),cap),5,
    V.reject(blob && create,6,
    V.reject(blob && Nat.is_eq(nblobs,0n),16,
    V.reject(blob && Nat.is_gt(nblobs,6n),17,
    V.reject(blob && Bool.not(V.blobs_valid(T.Transaction.blobhashes(tx))),18,
    V.reject(auth && create,7,
    V.reject(auth && V.auth_empty(T.Transaction.authorizations(tx)),19,
    V.reject(U32.is_ne(V.intrinsic_reason(tx),0),V.intrinsic_reason(tx),
    V.reject(O.gt(gasword,M.Context.gaslimit(context)),9,
    V.reject(O.lt(cap,M.Context.basefee(context)),10,
    V.reject(blob && O.lt(blobcap,M.Context.blobbasefee(context)),11,
    V.reject(O.lt(T.Transaction.nonce(tx),M.Account.nonce(account)),12,
    V.reject(O.gt(T.Transaction.nonce(tx),M.Account.nonce(account)),21,
    V.reject(V.mul_overflow(gasword,cap),13,
    V.reject(V.mul_overflow(bg,blobcap) || V.add_overflow(fee,blobfee) || V.add_overflow(fees,value),24,
    V.reject(O.gt(W.add(fees,value),M.Account.balance(account)),14,
    V.reject(Bool.not(V.sender_code(M.Account.code(account))),15,0))))))))))))))))))))))

def debit(+world: M.World, +sender: W.Word, amount: W.Word) -> M.World:
  +a = World.account(world,sender)
  TW.write(world,M.Account.set_balance(a,O.sub(M.Account.balance(a),amount)))

def adjusted(result: Tx.Preparation, +gas: W.Word, +escrow: W.Word) -> Preparation:
  match result:
    case Tx.Rejected{reason}: Rejected{reason}
    case Tx.Prepared{+engine,metadata}:
      match metadata:
        case F.Metadata{txgas,floor,+gasprice,priority,+sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}:
          +extra = O.mul(escrow,gasprice)
          Prepared{M.Engine.set_world(engine,debit(M.Engine.world(engine),sender,extra)),F.Metadata{txgas,floor,gasprice,priority,sender,coinbase,debit(snapshot,sender,extra),create,target,entry_reservoir,committed_used,committed_spilled},gas,escrow}

def validated(reason: U32, +tx: T.Transaction, gas: W.Word, escrow: W.Word, world: M.World, context: M.Context) -> Preparation:
  match reason:
    case 0: adjusted(Tx.prepare(tx,world,context),gas,escrow)
    case other: Rejected{other}

def prepare(tx: Transaction, +world: M.World, +context: M.Context) -> Preparation:
  match tx:
    case WideTx{transaction,+gas}:
      +tx = proxy(transaction,bounded(gas))
      validated(validate(tx,gas,world,context),tx,gas,O.sub(gas,O.from_nat(T.Transaction.gas(tx))),world,context)

def settlement(+gas: W.Word, escrow: W.Word, +floor: Nat, +e: M.Engine) -> Settlement:
  +before = O.sub(O.sub(O.sub(gas,O.from_nat(M.Frame.gas(M.Engine.frame(e)))),O.from_nat(M.Engine.reservoir(e))),escrow)
  +cap = O.div(before,W.from_u32(5))
  +refund = F.positive(M.World.refund(M.Engine.world(e)))
  +after = O.sub(before,V.choose(O.lt(refund,cap),refund,cap))
  +charged = V.choose(O.lt(after,O.from_nat(floor)),O.from_nat(floor),after)
  +state = F.positive(M.Engine.state_used(e))
  +execution = O.sub(before,state)
  Gas{charged,O.sub(gas,charged),V.choose(O.negative(execution) || O.lt(execution,O.from_nat(floor)),O.from_nat(floor),execution),state}

def pay(+e: M.Engine, escrow: W.Word, +result: Settlement, price: W.Word, tip: W.Word, sender: W.Word, coinbase: W.Word) -> Completion:
  match result:
    case Gas{+used,+left,+execution,+state}:
      +world = F.credit(F.credit(M.Engine.world(e),sender,O.mul(left,price)),coinbase,O.mul(used,tip))
      Completed{M.Engine.set_world(e,F.destroy(M.World.selfdestructs(world),world)),Gas{used,left,execution,state},W.add(O.from_nat(M.Engine.reservoir(e)),escrow)}

def finish_ready(metadata: F.Metadata, gas: W.Word, +escrow: W.Word, +e: M.Engine) -> Completion:
  match metadata:
    case F.Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,+committed_used,committed_spilled}:
      +deposited = F.deposit(create,e,target)
      +rolled = F.rollback(G.successful(M.Frame.action(M.Engine.frame(deposited))),deposited,snapshot)
      +total = M.Engine.set_state_used(M.Engine.set_state_spilled(rolled,Nat.add(M.Engine.state_spilled(rolled),committed_spilled)),W.add(M.Engine.state_used(rolled),committed_used))
      pay(total,escrow,settlement(gas,escrow,floor,total),gasprice,priority,sender,coinbase)

def finish_action(action: M.Action, metadata: F.Metadata, gas: W.Word, escrow: W.Word, e: M.Engine) -> Completion:
  match action:
    case M.Stopped{}: finish_ready(metadata,gas,escrow,e)
    case M.Returned{}: finish_ready(metadata,gas,escrow,e)
    case M.Reverted{}: finish_ready(metadata,gas,escrow,e)
    case M.Fault{reason}: finish_ready(metadata,gas,escrow,e)
    case other: Incomplete{}

def finish(metadata: F.Metadata, gas: W.Word, escrow: W.Word, +e: M.Engine) -> Completion:
  finish_action(M.Frame.action(M.Engine.frame(e)),metadata,gas,escrow,e)

# A violated reservoir-window bound is a host failure, never a consensus fault.
def margin() -> Nat:
  Nat.mul(U32.to_nat(256),O.radix32())

def invariant(+e: M.Engine, escrow: W.Word) -> Bool:
  W.is_zero(escrow) || (Nat.is_ge(M.Engine.reservoir(e),Nat.sub(window(),margin())) && Nat.is_le(M.Engine.reservoir(e),Nat.add(window(),margin())))

def checked_machine(ok: Bool, +machine: M.Machine) -> M.Machine:
  match ok:
    case True{}: machine
    case False{}:
      +e = M.Machine.engine(machine)
      M.Machine.set_engine(machine,M.Engine.set_frame(e,M.Frame.set_action(M.Engine.frame(e),M.HostLimit{})))

def decision(+machine: M.Machine, escrow: W.Word) -> Runtime.Decision:
  Runtime.decide(checked_machine(invariant(M.Machine.engine(machine),escrow),machine))

def loop(fuel: Nat, current: Runtime.Decision, +escrow: W.Word) -> IO(M.Engine):
  match fuel:
    case 0n: IO.pure(M.Engine,Runtime.exhausted(current))
    case 1n+f:
      match current:
        case Runtime.Done{engine}: IO.pure(M.Engine,engine)
        case Runtime.Tick{machine}: loop(f,decision(VM.step(machine),escrow),escrow)
        case Runtime.Pre{address,+machine}:
          do IO<M.Engine>:
            response : +List<U32> <- P.run(address,M.Frame.gas(M.Engine.frame(M.Machine.engine(machine))),M.Frame.input(M.Engine.frame(M.Machine.engine(machine))))
            loop(f,decision(Runtime.resume(response,machine),escrow),escrow)

def execute(+engine: M.Engine, +escrow: W.Word) -> IO(M.Engine):
  loop(Nat.add(Nat.mul(4n,Nat.add(M.Frame.gas(M.Engine.frame(engine)),M.Engine.reservoir(engine))),U32.to_nat(4096)),decision(M.Machine{engine,Nil{}},escrow),escrow)

def prepared(p: Preparation) -> IO(Completion):
  match p:
    case Rejected{reason}: IO.pure(Completion,Incomplete{})
    case Prepared{engine,metadata,gas,+escrow}:
      do IO<Completion>:
        terminal : M.Engine <- execute(engine,escrow)
        return finish(metadata,gas,escrow,terminal)

def run(tx: Transaction, world: M.World, context: M.Context) -> IO(Completion):
  prepared(prepare(tx,world,context))

def Completion.reservoir(c: Completion) -> +Maybe<W.Word>:
  match c:
    case Incomplete{}: None{}
    case Completed{engine,gas,reservoir}: Some{reservoir}

def Transaction.transaction(x: Transaction) -> T.Transaction:
  match x:
    case WideTx{transaction,gas}: transaction

def Transaction.gas(x: Transaction) -> W.Word:
  match x:
    case WideTx{transaction,gas}: gas

def Settlement.used(x: Settlement) -> W.Word:
  match x:
    case Gas{used,left,execution,state}: used

def Settlement.left(x: Settlement) -> W.Word:
  match x:
    case Gas{used,left,execution,state}: left

def Settlement.execution(x: Settlement) -> W.Word:
  match x:
    case Gas{used,left,execution,state}: execution

def Settlement.state(x: Settlement) -> W.Word:
  match x:
    case Gas{used,left,execution,state}: state

def Completion.engine(x: Completion) -> +Maybe<M.Engine>:
  match x:
    case Incomplete{}: None{}
    case Completed{engine,gas,reservoir}: Some{engine}

def Completion.gas(x: Completion) -> +Maybe<Settlement>:
  match x:
    case Incomplete{}: None{}
    case Completed{engine,gas,reservoir}: Some{gas}

type RefundSettlement is Data:
  Refund{txgas: W.Word, before_refund: W.Word, capped_refund: W.Word, effective_refund: W.Word, floor_charge: W.Word}

# Supply the completed engine (after deployment/rollback), not the raw terminal frame.
def refunds(+gas: W.Word, escrow: W.Word, +floor: Nat, +completed: M.Engine) -> RefundSettlement:
  +before = O.sub(O.sub(O.sub(gas,O.from_nat(M.Frame.gas(M.Engine.frame(completed)))),O.from_nat(M.Engine.reservoir(completed))),escrow)
  +cap = O.div(before,W.from_u32(5))
  +raw = F.positive(M.World.refund(M.Engine.world(completed)))
  +capped = V.choose(O.lt(raw,cap),raw,cap)
  +after = O.sub(before,capped)
  +charged = V.choose(O.lt(after,O.from_nat(floor)),O.from_nat(floor),after)
  Refund{gas,before,capped,V.choose(O.lt(charged,before),O.sub(before,charged),W.zero()),V.choose(O.gt(charged,after),O.sub(charged,after),W.zero())}

def RefundSettlement.txgas(x: RefundSettlement) -> W.Word:
  match x:
    case Refund{txgas,before_refund,capped_refund,effective_refund,floor_charge}: txgas

def RefundSettlement.before_refund(x: RefundSettlement) -> W.Word:
  match x:
    case Refund{txgas,before_refund,capped_refund,effective_refund,floor_charge}: before_refund

def RefundSettlement.capped_refund(x: RefundSettlement) -> W.Word:
  match x:
    case Refund{txgas,before_refund,capped_refund,effective_refund,floor_charge}: capped_refund

def RefundSettlement.effective_refund(x: RefundSettlement) -> W.Word:
  match x:
    case Refund{txgas,before_refund,capped_refund,effective_refund,floor_charge}: effective_refund

def RefundSettlement.floor_charge(x: RefundSettlement) -> W.Word:
  match x:
    case Refund{txgas,before_refund,capped_refund,effective_refund,floor_charge}: floor_charge
