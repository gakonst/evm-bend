import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./world.bend as World
import ./gas.bend as G
import ./call-common.bend as C
import ./create-finish.bend as Create

# snapshot is AFTER nonce/upfront payment and committed authorizations, BEFORE
# dispatched value transfer/creation. Engine state counters exclude auth commit.
type Metadata is Data:
  Metadata{txgas: Nat, floor: Nat, gasprice: W.Word, priority: W.Word, sender: W.Word, coinbase: W.Word, snapshot: M.World, create: Bool, target: W.Word, entry_reservoir: Nat, committed_used: W.Word, committed_spilled: Nat}

type GasSettlement is Data:
  GasSettlement{used: Nat, left: Nat, execution: Nat, state: W.Word}

def positive(+w: W.Word) -> W.Word:
  C.word(O.negative(w),W.zero(),w)

def cap_execution_refund(+used: Nat, +refund: W.Word) -> Nat:
  +cap = Nat.div(used,5n)
  O.to_nat(C.word(O.lt(positive(refund),O.from_nat(cap)),positive(refund),O.from_nat(cap)))

def gas(+txgas: Nat, +floor: Nat, execution_left: Nat, reservoir: Nat, +refund: W.Word, +state_used: W.Word) -> GasSettlement:
  +used = Nat.sub(Nat.sub(txgas,execution_left),reservoir)
  +after_refund = Nat.sub(used,cap_execution_refund(used,refund))
  +charged = C.nat(Nat.is_gt(floor,after_refund),floor,after_refund)
  +state = positive(state_used)
  +exec = O.sub(O.from_nat(used),state)
  GasSettlement{charged,Nat.sub(txgas,charged),C.nat(Bool.or(O.negative(exec),O.lt(exec,O.from_nat(floor))),floor,O.to_nat(exec)),state}

# Only explicit touched addresses may be pruned; warmth is not evidence of touch.
def prune_if(empty: Bool, +world: M.World, address: W.Word) -> M.World:
  match empty:
    case True{}: World.modify(world,World.account(world,address))
    case False{}: world

def finalize_touched(addresses: +List<W.Word>, +world: M.World) -> M.World:
  match addresses:
    case Nil{}: world
    case Con{+address,rest}: finalize_touched(rest,prune_if(World.is_empty(World.account(world,address)),world,address))

def credit(+world: M.World, +address: W.Word, value: W.Word) -> M.World:
  +a = World.account(world,address)
  +a = M.Account.set_exists(M.Account.set_balance(a,W.add(M.Account.balance(a),value)),True{})
  World.modify(world,a)

# Pinned state_tracker.clear_account_preserving_balance: even a scheduled
# destruction may have received more ETH after SELFDESTRUCT or from gas fees.
def destroy(addresses: +List<W.Word>, +world: M.World) -> M.World:
  match addresses:
    case Nil{}: world
    case Con{+address,rest}:
      +old = World.account(world,address)
      +a = M.Account.set_storage(M.Account.set_code(M.Account.set_nonce(old,W.zero()),Nil{}),Nil{})
      destroy(rest,World.modify(world,a))

def deposit(create: Bool, e: M.Engine, target: W.Word) -> M.Engine:
  match create:
    case True{}: Create.finish(e,target)
    case False{}: e

def rollback(success: Bool, +e: M.Engine, snapshot: M.World) -> M.Engine:
  match success:
    case True{}: e
    case False{}:
      +settled = G.settle(e)
      M.Engine.set_world(settled,M.World.set_refund(snapshot,W.zero()))

def pay(settlement: GasSettlement, +e: M.Engine, gasprice: W.Word, priority: W.Word, sender: W.Word, coinbase: W.Word) -> M.Engine:
  match settlement:
    case GasSettlement{used,left,execution,state}:
      +world = credit(credit(M.Engine.world(e),sender,O.mul(O.from_nat(left),gasprice)),coinbase,O.mul(O.from_nat(used),priority))
      M.Engine.set_world(e,destroy(M.World.selfdestructs(world),world))

# HostLimit is not an EVM failure and must not finalize fees or mutate state.
def settle_action(action: M.Action, +metadata: Metadata, +e: M.Engine) -> M.Engine:
  match action:
    case M.HostLimit{}: e
    case other:
      match metadata:
        case Metadata{+txgas,+floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,+committed_used,committed_spilled}:
          +deposited = deposit(create,e,target)
          +rolled = rollback(G.successful(M.Frame.action(M.Engine.frame(deposited))),deposited,snapshot)
          +total = M.Engine.set_state_used(M.Engine.set_state_spilled(rolled,Nat.add(M.Engine.state_spilled(rolled),committed_spilled)),W.add(M.Engine.state_used(rolled),committed_used))
          pay(gas(txgas,floor,M.Frame.gas(M.Engine.frame(total)),M.Engine.reservoir(total),M.World.refund(M.Engine.world(total)),M.Engine.state_used(total)),total,gasprice,priority,sender,coinbase)

def settlement(metadata: Metadata, +engine: M.Engine) -> M.Engine:
  settle_action(M.Frame.action(M.Engine.frame(engine)),metadata,engine)

# Explicit reporting API; preserve the four-field settlement constructor.
def GasSettlement.used(s: GasSettlement) -> Nat:
  match s:
    case GasSettlement{used,left,execution,state}: used

def GasSettlement.left(s: GasSettlement) -> Nat:
  match s:
    case GasSettlement{used,left,execution,state}: left

def GasSettlement.execution(s: GasSettlement) -> Nat:
  match s:
    case GasSettlement{used,left,execution,state}: execution

def GasSettlement.state(s: GasSettlement) -> W.Word:
  match s:
    case GasSettlement{used,left,execution,state}: state

type RefundSettlement is Data:
  RefundSettlement{txgas: Nat, before_refund: Nat, capped_refund: Nat, effective_refund: Nat, floor_charge: Nat}

def refunds(+txgas: Nat, +floor: Nat, execution_left: Nat, reservoir: Nat, refund: W.Word) -> RefundSettlement:
  +before = Nat.sub(Nat.sub(txgas,execution_left),reservoir)
  +cap = cap_execution_refund(before,refund)
  +after = Nat.sub(before,cap)
  +charged = C.nat(Nat.is_gt(floor,after),floor,after)
  RefundSettlement{txgas,before,cap,Nat.sub(before,charged),Nat.sub(charged,after)}

def RefundSettlement.txgas(r: RefundSettlement) -> Nat:
  match r:
    case RefundSettlement{txgas,before_refund,capped_refund,effective_refund,floor_charge}: txgas

def RefundSettlement.before_refund(r: RefundSettlement) -> Nat:
  match r:
    case RefundSettlement{txgas,before_refund,capped_refund,effective_refund,floor_charge}: before_refund

def RefundSettlement.capped_refund(r: RefundSettlement) -> Nat:
  match r:
    case RefundSettlement{txgas,before_refund,capped_refund,effective_refund,floor_charge}: capped_refund

def RefundSettlement.effective_refund(r: RefundSettlement) -> Nat:
  match r:
    case RefundSettlement{txgas,before_refund,capped_refund,effective_refund,floor_charge}: effective_refund

def RefundSettlement.floor_charge(r: RefundSettlement) -> Nat:
  match r:
    case RefundSettlement{txgas,before_refund,capped_refund,effective_refund,floor_charge}: floor_charge

def Metadata.txgas(m: Metadata) -> Nat:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: txgas

def Metadata.floor(m: Metadata) -> Nat:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: floor

def Metadata.gasprice(m: Metadata) -> W.Word:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: gasprice

def Metadata.priority(m: Metadata) -> W.Word:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: priority

def Metadata.sender(m: Metadata) -> W.Word:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: sender

def Metadata.coinbase(m: Metadata) -> W.Word:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: coinbase

def Metadata.snapshot(m: Metadata) -> M.World:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: snapshot

def Metadata.create(m: Metadata) -> Bool:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: create

def Metadata.target(m: Metadata) -> W.Word:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: target

def Metadata.entry_reservoir(m: Metadata) -> Nat:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: entry_reservoir

def Metadata.committed_used(m: Metadata) -> W.Word:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: committed_used

def Metadata.committed_spilled(m: Metadata) -> Nat:
  match m:
    case Metadata{txgas,floor,gasprice,priority,sender,coinbase,snapshot,create,target,entry_reservoir,committed_used,committed_spilled}: committed_spilled
