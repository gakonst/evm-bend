import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./world.bend as World
import ./gas.bend as G
import ./bytes.bend as B
import ./call-common.bend as C
import ./call-enter.bend as Call
import ./create-address.bend as Address
import ./precompile.bend as P
import ./transaction-types.bend as T
import ./transaction-intrinsic.bend as I
import ./transaction-validate.bend as V
import ./transaction-auth.bend as Auth
import ./transaction-finish.bend as F
import ./transaction-world.bend as TW

# Rejection never includes a mutated world; preparation faults are accepted
# transactions and return Prepared with an exceptional terminal engine.
type Preparation is Data:
  Rejected{reason: U32}
  Prepared{engine: M.Engine, metadata: F.Metadata}

def is_create(to: +Maybe<W.Word>) -> Bool:
  match to:
    case None{}: True{}
    case Some{address}: False{}

def recipient_address(to: +Maybe<W.Word>, sender: W.Word, nonce: W.Word) -> W.Word:
  match to:
    case None{}: Address.create(sender,nonce)
    case Some{address}: address

def warm_access(entries: +List<T.Access>, world: M.World) -> M.World:
  match entries:
    case Nil{}: world
    case Con{T.Access{+address,keys},rest}:
      warm_access(rest,TW.warm_slots(keys,World.warm_account(world,address),address))

def warm(+tx: T.Transaction, world: M.World, recipient: W.Word, coinbase: W.Word) -> M.World:
  warm_access(T.Transaction.access_list(tx),TW.warm_precompiles(17n,World.warm_account(World.warm_account(World.warm_account(world,T.Transaction.sender(tx)),recipient),coinbase)))

def paid_writes(paid: Bool, +sender: W.Word, recipient: W.Word) -> +List<W.Word>:
  match paid:
    case False{}: [sender]
    case True{}: [sender,recipient]

def make_metadata(+tx: T.Transaction, +context: M.Context, snapshot: M.World, recipient: W.Word, entry: Nat, committed: W.Word, spill: Nat) -> F.Metadata:
  +price = V.effective_price(tx,context)
  F.Metadata{T.Transaction.gas(tx),I.Intrinsic.floor(I.compute(tx)),price,O.sub(price,M.Context.basefee(context)),T.Transaction.sender(tx),M.Context.coinbase(context),snapshot,is_create(T.Transaction.to(tx)),recipient,entry,committed,spill}

def initialize_create(create: Bool, +world: M.World, +recipient: W.Word) -> M.World:
  match create:
    case False{}: world
    case True{}:
      +a = World.account(world,recipient)
      a = M.Account.set_exists(M.Account.set_created(M.Account.set_original(M.Account.set_storage(M.Account.set_nonce(a,W.from_u32(1)),Nil{}),Nil{}),True{}),True{})
      World.modify(world,a)

def dispatch_ready(failed: Bool, +tx: T.Transaction, +e: M.Engine, +context: M.Context, +before: M.World, +recipient: W.Word, +entry: Nat, committed: W.Word, spill: Nat) -> Preparation:
  match failed:
    case True{}:
      +frame = M.Frame.set_output(M.Frame.set_gas(M.Engine.frame(e),0n),Nil{})
      Prepared{M.Engine{frame,before,context,entry,W.zero(),0n},make_metadata(tx,context,before,recipient,entry,W.zero(),0n)}
    case False{}:
      +snapshot = M.Engine.world(e)
      world = initialize_create(is_create(T.Transaction.to(tx)),snapshot,recipient)
      world = C.transfer(world,T.Transaction.sender(tx),recipient,T.Transaction.value(tx))
      Prepared{M.Engine.set_world(e,world),make_metadata(tx,context,snapshot,recipient,entry,committed,spill)}

def resolved_code(precompile: Bool, code: +List<U32>) -> +List<U32>:
  match precompile:
    case True{}: Nil{}
    case False{}: code

def resolve(delegated: Bool, +e: M.Engine, +recipient: W.Word) -> M.Engine:
  match delegated:
    case False{}:
      +frame = M.Frame.set_code(M.Engine.frame(e),M.Account.code(World.account(M.Engine.world(e),recipient)))
      M.Engine.set_frame(e,M.Frame.set_action(frame,Call.child_action(False{},recipient)))
    case True{}:
      +address = Call.delegation_address(M.Account.code(World.account(M.Engine.world(e),recipient)))
      +a = World.account(M.Engine.world(e),address)
      +frame = G.charge(M.Engine.frame(e),C.access(a))
      frame = M.Frame.set_code(frame,resolved_code(P.supported(address),M.Account.code(a)))
      M.Engine.set_world(M.Engine.set_frame(e,frame),World.warm_account(M.Engine.world(e),address))

def dispatch_call_paid(bad: Bool, +e: M.Engine, +recipient: W.Word) -> M.Engine:
  match bad:
    case True{}: e
    case False{}: resolve(Call.delegated(M.Account.code(World.account(M.Engine.world(e),recipient))),e,recipient)

def dispatch_call(+e: M.Engine, +recipient: W.Word, value: W.Word) -> M.Engine:
  +charged = C.state_if(Bool.and(Bool.not(W.is_zero(value)),C.empty(World.account(M.Engine.world(e),recipient))),e)
  dispatch_call_paid(G.failed(M.Frame.action(M.Engine.frame(charged))),charged,recipient)

def dispatch_create(collision: Bool, +e: M.Engine, charge: Bool) -> M.Engine:
  match collision:
    case True{}: M.Engine.set_frame(e,M.fault(M.Engine.frame(e),10))
    case False{}: C.state_if(charge,e)

def dispatch(create: Bool, +tx: T.Transaction, +e: M.Engine, +original: M.World, +recipient: W.Word) -> M.Engine:
  match create:
    case False{}: dispatch_call(e,recipient,T.Transaction.value(tx))
    case True{}:
      +a = World.account(M.Engine.world(e),recipient)
      +f = M.Frame.set_code(M.Frame.set_input(M.Engine.frame(e),Nil{}),T.Transaction.data(tx))
      dispatch_create(Bool.or(Bool.not(W.is_zero(M.Account.nonce(a))),Bool.not(Nat.is_eq(B.len(M.Account.code(a)),0n))),M.Engine.set_frame(e,f),C.empty(World.account(original,recipient)))

def after_auth(bad: Bool, +tx: T.Transaction, +e: M.Engine, +context: M.Context, +original: M.World, +before: M.World, +recipient: W.Word, +entry: Nat) -> Preparation:
  match bad:
    case True{}: dispatch_ready(True{},tx,e,context,before,recipient,entry,W.zero(),0n)
    case False{}:
      +committed = M.Engine.state_used(e)
      +spill = M.Engine.state_spilled(e)
      +ready = M.Engine.set_state_spilled(M.Engine.set_state_used(e,W.zero()),0n)
      ready = M.Engine.set_world(ready,warm(tx,M.Engine.world(ready),recipient,M.Context.coinbase(context)))
      +dispatched = dispatch(is_create(T.Transaction.to(tx)),tx,ready,original,recipient)
      dispatch_ready(G.failed(M.Frame.action(M.Engine.frame(dispatched))),tx,dispatched,context,before,recipient,entry,committed,spill)

def authorized(+tx: T.Transaction, +e: M.Engine, +context: M.Context, +original: M.World, before: M.World, +recipient: W.Word, entry: Nat) -> Preparation:
  +result = Auth.process(e,original,M.Context.chainid(context),T.Transaction.authorizations(tx),paid_writes(Bool.or(is_create(T.Transaction.to(tx)),Bool.not(W.is_zero(T.Transaction.value(tx)))),T.Transaction.sender(tx),recipient))
  after_auth(Auth.AuthResult.preparation_failed(result),tx,Auth.AuthResult.engine(result),context,original,before,recipient,entry)

def accepted(+tx: T.Transaction, +world: M.World, +context: M.Context) -> Preparation:
  +original = TW.reset(world)
  +sender = T.Transaction.sender(tx)
  +recipient = recipient_address(T.Transaction.to(tx),sender,T.Transaction.nonce(tx))
  +a = World.account(original,sender)
  a = M.Account.set_balance(M.Account.set_nonce(a,W.add(M.Account.nonce(a),W.from_u32(1))),O.sub(M.Account.balance(a),V.upfront(tx,context)))
  +before = TW.write(original,a)
  +intrinsic = I.Intrinsic.execution(I.compute(tx))
  +grant = G.minimum(Nat.sub(U32.to_nat(16777216),intrinsic),Nat.sub(T.Transaction.gas(tx),intrinsic))
  +entry = Nat.sub(Nat.sub(T.Transaction.gas(tx),intrinsic),grant)
  +context = M.Context.set_blobhashes(M.Context.set_gasprice(M.Context.set_origin(context,sender),V.effective_price(tx,context)),T.Transaction.blobhashes(tx))
  frame = M.initial_frame(Nil{},grant,T.Transaction.data(tx),recipient,sender,T.Transaction.value(tx))
  authorized(tx,M.Engine{frame,before,context,entry,W.zero(),0n},context,original,before,recipient,entry)

def validated(reason: U32, tx: T.Transaction, world: M.World, context: M.Context) -> Preparation:
  match reason:
    case 0: accepted(tx,world,context)
    case other: Rejected{other}

def prepare(+tx: T.Transaction, +world: M.World, +context: M.Context) -> Preparation:
  validated(V.validate(tx,world,context),tx,world,context)

type Completion is Data:
  Completed{engine: M.Engine, gas: F.GasSettlement}
  Incomplete{}

def completed(metadata: F.Metadata, +settled: M.Engine) -> Completion:
  match metadata:
    case F.Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}:
      Completed{settled,F.gas(txgas,floor,M.Frame.gas(M.Engine.frame(settled)),M.Engine.reservoir(settled),M.World.refund(M.Engine.world(settled)),M.Engine.state_used(settled))}

def finish_terminal(action: M.Action, +metadata: F.Metadata, +engine: M.Engine) -> Completion:
  match action:
    case M.HostLimit{}: Incomplete{}
    case M.Running{}: Incomplete{}
    case M.Call{kind,gas,target,value,in_offset,in_size,out_offset,out_size}: Incomplete{}
    case M.Create{kind,value,offset,size,salt}: Incomplete{}
    case M.SelfDestruct{target}: Incomplete{}
    case M.Precompile{address}: Incomplete{}
    case terminal:
      completed(metadata,F.settlement(metadata,engine))

def finish(metadata: F.Metadata, +engine: M.Engine) -> Completion:
  finish_terminal(M.Frame.action(M.Engine.frame(engine)),metadata,engine)

def Preparation.engine(p: Preparation) -> +Maybe<M.Engine>:
  match p:
    case Rejected{reason}: None{}
    case Prepared{engine,metadata}: Some{engine}

def Preparation.metadata(p: Preparation) -> +Maybe<F.Metadata>:
  match p:
    case Rejected{reason}: None{}
    case Prepared{engine,metadata}: Some{metadata}

def Preparation.reason(p: Preparation) -> +Maybe<U32>:
  match p:
    case Rejected{reason}: Some{reason}
    case Prepared{engine,metadata}: None{}

def Completion.engine(c: Completion) -> +Maybe<M.Engine>:
  match c:
    case Incomplete{}: None{}
    case Completed{engine,gas}: Some{engine}

def Completion.world(c: Completion) -> +Maybe<M.World>:
  match c:
    case Incomplete{}: None{}
    case Completed{engine,gas}: Some{M.Engine.world(engine)}

def Completion.gas(c: Completion) -> +Maybe<F.GasSettlement>:
  match c:
    case Incomplete{}: None{}
    case Completed{engine,gas}: Some{gas}

# Call with the terminal engine returned by Completed; does not settle twice.
def refunds(+metadata: F.Metadata, +settled: M.Engine) -> F.RefundSettlement:
  F.refunds(F.Metadata.txgas(metadata),F.Metadata.floor(metadata),M.Frame.gas(M.Engine.frame(settled)),M.Engine.reservoir(settled),M.World.refund(M.Engine.world(settled)))
