import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./world.bend as World
import ./gas.bend as G
import ./bytes.bend as B
import ./memory.bend as Mem
import ./keccak.bend as K
import ./opcode-common.bend as H

def choose(b: Bool,a: Nat,c: Nat) -> Nat:
  match b:
    case True{}: a
    case False{}: c

def fault(+e: M.Engine,n: U32) -> M.Engine:
  M.Engine.set_frame(e,M.fault(M.Engine.frame(e),n))

def charge(+e: M.Engine,c: Nat) -> M.Engine:
  M.Engine.set_frame(e,G.charge(M.Engine.frame(e),c))

def finish(+e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  +f = M.Engine.frame(e)
  M.Engine.set_frame(e,M.Frame.set_pc(M.Frame.set_stack(f,stack),1n+M.Frame.pc(f)))

def commit_if(bad: Bool,old: M.Engine,new: M.Engine) -> M.Engine:
  match bad:
    case True{}: old
    case False{}: new

def extent(offset: Nat,size: Nat) -> Nat:
  match size:
    case 0n: 0n
    case 1n+p: Nat.add(offset,1n+p)

def commit(+old: M.Engine,new: M.Engine) -> M.Engine:
  commit_if(G.failed(M.Frame.action(M.Engine.frame(old))),old,new)

# Charge ranges using Word arithmetic before converting to bounded Nat. The
# shared checker rejects wrapped/oversized endpoints before any memory access.
def memory(+e: M.Engine,offset: Nat,size: Nat,cost: Maybe<&2,Nat>) -> M.Engine:
  match cost:
    case None{}: fault(e,1)
    case Some{cost}:
      charge(M.Engine.set_frame(e,H.memory(M.Engine.frame(e),O.from_nat(offset),O.from_nat(size))),cost)

def access(a: M.Account) -> Nat:
  choose(M.Account.warm(a),U32.to_nat(100),U32.to_nat(3000))

def codehash_if(empty: Bool,a: M.Account) -> W.Word:
  match empty:
    case True{}: W.zero()
    case False{}: K.hash(M.Account.code(a))

def codehash(+a: M.Account) -> W.Word:
  codehash_if(World.is_empty(a),a)

def external_value(op: U32,+a: M.Account) -> W.Word:
  match op:
    case 49: M.Account.balance(a)
    case 59: O.from_nat(B.len(M.Account.code(a)))
    case other: codehash(a)

def external(+op: U32,+e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  match stack:
    case Con{+addr,rest}:
      +a = World.account(M.Engine.world(e),addr)
      +paid = charge(e,Nat.add(access(a),choose(U32.is_eq(op,59),U32.to_nat(100),0n)))
      commit(paid,finish(M.Engine.set_world(paid,World.warm_account(M.Engine.world(paid),addr)),external_value(op,a) <> rest))
    case other: fault(e,2)

def ext_source(fits: Bool,src: W.Word,n: Nat,code: +List<U32>) -> +List<U32>:
  match fits:
    case True{}: B.slice(O.to_nat(src),n,code)
    case False{}: B.take(n,Nil{})

def extcopy_finish(bad: Bool,+paid: M.Engine,+a: M.Account,offset: Nat,+src: W.Word,n: Nat,rest: +List<W.Word>) -> M.Engine:
  match bad:
    case True{}: paid
    case False{}:
      +f = M.Engine.frame(paid)
      finish(M.Engine.set_world(M.Engine.set_frame(paid,M.Frame.set_memory(f,Mem.write(M.Frame.memory(f),offset,ext_source(O.fits_nat(src),src,n,M.Account.code(a))))),World.warm_account(M.Engine.world(paid),M.Account.address(a))),rest)

def extcopy_raw(+e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  match stack:
    case Con{+addr,Con{off,Con{+src,Con{size,rest}}}}:
      +a = World.account(M.Engine.world(e),addr)
      +n = O.to_nat(size)
      +offset = O.to_nat(off)
      +paid = memory(e,offset,n,Some{Nat.add(Nat.add(access(a),U32.to_nat(100)),Nat.mul(3n,Mem.words(n)))})
      extcopy_finish(G.failed(M.Frame.action(M.Engine.frame(paid))),paid,a,offset,src,n,rest)
    case other: fault(e,2)

def load_slot(transient: Bool,+e: M.Engine,+addr: W.Word,+a: M.Account,+key: W.Word,rest: +List<W.Word>) -> M.Engine:
  match transient:
    case True{}:
      +paid = charge(e,U32.to_nat(100))
      commit(paid,finish(paid,World.lookup(M.Account.transient(a),key) <> rest))
    case False{}:
      +paid = charge(e,choose(World.contains(M.Account.storage_warm(a),key),U32.to_nat(100),U32.to_nat(2100)))
      commit(paid,finish(M.Engine.set_world(paid,World.warm_storage(M.Engine.world(paid),addr,key)),World.lookup(M.Account.storage(a),key) <> rest))

def sload(stack: +List<W.Word>,transient: Bool,+e: M.Engine) -> M.Engine:
  match stack:
    case Con{+key,rest}:
      +addr = M.Frame.address(M.Engine.frame(e))
      +a = World.account(M.Engine.world(e),addr)
      load_slot(transient,e,addr,a,key,rest)
    case other: fault(e,2)

# Signed refund deltas are encoded as two's-complement words.
def clear_refund(original_zero: Bool,current_zero: Bool,value_zero: Bool) -> W.Word:
  match original_zero current_zero value_zero:
    case False{} True{} v: O.sub(W.zero(),W.from_u32(11616))
    case False{} False{} True{}: W.from_u32(11616)
    case o c v: W.zero()

def refund_if(same: Bool,reset: Bool,oz: Bool,cz: Bool,vz: Bool) -> W.Word:
  match same:
    case True{}: W.zero()
    case False{}: W.add(clear_refund(oz,cz,vz),O.from_nat(choose(reset,U32.to_nat(10000),0n)))

def refund(+original: W.Word,+current: W.Word,+value: W.Word) -> W.Word:
  refund_if(W.eq(current,value),W.eq(original,value),W.is_zero(original),W.is_zero(current),W.is_zero(value))

def state_if(same: Bool,oz: Bool,cz: Bool,vz: Bool,e: M.Engine) -> M.Engine:
  match same oz cz vz:
    case False{} True{} True{} False{}: G.spend_state(e,U32.to_nat(97920))
    case False{} True{} False{} True{}: G.refill(e,U32.to_nat(97920))
    case s o c v: e

def state_change(e: M.Engine,+original: W.Word,+current: W.Word,+value: W.Word) -> M.Engine:
  state_if(W.eq(current,value),W.is_zero(original),W.is_zero(current),W.is_zero(value),e)

def store_paid(+e: M.Engine,+key: W.Word,+value: W.Word,rest: +List<W.Word>) -> M.Engine:
  +addr = M.Frame.address(M.Engine.frame(e))
  +a = World.account(M.Engine.world(e),addr)
  +original = World.lookup(M.Account.original(a),key)
  +current = World.lookup(M.Account.storage(a),key)
  cost = Nat.add(choose(World.contains(M.Account.storage_warm(a),key),U32.to_nat(100),U32.to_nat(2100)),choose(Bool.and(W.eq(original,current),Bool.not(W.eq(current,value))),U32.to_nat(10000),0n))
  +paid = charge(e,cost)
  +funded = commit(paid,state_change(paid,original,current,value))
  +world = World.add_refund(World.set_storage(World.warm_storage(M.Engine.world(funded),addr,key),addr,key,value),refund(original,current,value))
  commit(funded,finish(M.Engine.set_world(funded,world),rest))

def sentry(low: Bool,e: M.Engine,key: W.Word,value: W.Word,rest: +List<W.Word>) -> M.Engine:
  match low:
    case True{}: fault(e,1)
    case False{}: store_paid(e,key,value,rest)

def store_slot(transient: Bool,+e: M.Engine,key: W.Word,value: W.Word,rest: +List<W.Word>) -> M.Engine:
  match transient:
    case True{}:
      +paid = charge(e,U32.to_nat(100))
      commit(paid,finish(M.Engine.set_world(paid,World.set_transient(M.Engine.world(paid),M.Frame.address(M.Engine.frame(paid)),key,value)),rest))
    case False{}:
      sentry(Nat.is_le(M.Frame.gas(M.Engine.frame(e)),U32.to_nat(2300)),e,key,value,rest)

def store_if(static: Bool,stack: +List<W.Word>,transient: Bool,+e: M.Engine) -> M.Engine:
  match static:
    case True{}: fault(e,6)
    case False{}:
      match stack:
        case Con{key,Con{value,rest}}:
          store_slot(transient,e,key,value,rest)
        case other: fault(e,2)

def topics(n: Nat,stack: +List<W.Word>) -> +List<W.Word>:
  match n:
    case 0n: Nil{}
    case 1n+p:
      match stack:
        case Nil{}: Nil{}
        case Con{h,t}: h <> topics(p,t)

def drop(n: Nat,stack: +List<W.Word>) -> +List<W.Word>:
  match n:
    case 0n: stack
    case 1n+p:
      match stack:
        case Nil{}: Nil{}
        case Con{h,t}: drop(p,t)

def emit_finish(bad: Bool,+n: Nat,+paid: M.Engine,offset: Nat,len: Nat,+rest: +List<W.Word>) -> M.Engine:
  match bad:
    case True{}: paid
    case False{}:
      +f = M.Engine.frame(paid)
      event = {M.Log{M.Frame.address(f),topics(n,rest),Mem.read(M.Frame.memory(f),offset,len)} : M.Log}
      finish(M.Engine.set_world(paid,World.log(M.Engine.world(paid),event)),drop(n,rest))

def emit_paid_raw(short: Bool,+n: Nat,+e: M.Engine,off: W.Word,size: W.Word,+rest: +List<W.Word>) -> M.Engine:
  match short:
    case True{}: fault(e,2)
    case False{}:
      +offset = O.to_nat(off)
      +len = O.to_nat(size)
      cost = O.checked_to_nat(W.add(O.from_nat(Nat.mul(U32.to_nat(375),1n+n)),O.mul(W.from_u32(8),O.from_nat(len))))
      +paid = memory(e,offset,len,cost)
      emit_finish(G.failed(M.Frame.action(M.Engine.frame(paid))),n,paid,offset,len,rest)

def emit_valid(valid: Bool,short: Bool,n: Nat,e: M.Engine,off: W.Word,size: W.Word,rest: +List<W.Word>) -> M.Engine:
  match valid:
    case True{}: emit_paid_raw(short,n,e,off,size,rest)
    case False{}: fault(e,1)

def valid_range(+offset: W.Word,+size: W.Word) -> Bool:
  Bool.or(W.is_zero(size),Bool.and(O.fits_nat(offset),O.fits_nat(size)))

def emit_paid(short: Bool,n: Nat,e: M.Engine,+off: W.Word,+size: W.Word,rest: +List<W.Word>) -> M.Engine:
  emit_valid(valid_range(off,size),short,n,e,off,size,rest)
def emit_if(static: Bool,+n: Nat,+e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  match static:
    case True{}: fault(e,6)
    case False{}:
      match stack:
        case Con{off,Con{size,+rest}}:
          emit_paid(Nat.is_lt(List.length(&2,W.Word,rest),n),n,e,off,size,rest)
        case other: fault(e,2)

def self_balance(full: Bool,+e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  match full:
    case True{}: fault(e,3)
    case False{}:
      +paid = charge(e,5n)
      commit(paid,finish(paid,M.Account.balance(World.account(M.Engine.world(e),M.Frame.address(M.Engine.frame(e)))) <> stack))

def store(transient: Bool,+e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  store_if(M.Frame.is_static(M.Engine.frame(e)),stack,transient,e)

def emit(n: Nat,+e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  emit_if(M.Frame.is_static(M.Engine.frame(e)),n,e,stack)

def extcopy_valid(valid: Bool,e: M.Engine,stack: +List<W.Word>) -> M.Engine:
  match valid:
    case True{}: extcopy_raw(e,stack)
    case False{}: fault(e,1)

def extcopy(e: M.Engine,+stack: +List<W.Word>) -> M.Engine:
  match stack:
    case Con{addr,Con{+off,Con{src,Con{+size,rest}}}}:
      extcopy_valid(valid_range(off,size),e,addr <> off <> src <> size <> rest)
    case other: fault(e,2)

def dispatch_stack(op: U32,+e: M.Engine,+stack: +List<W.Word>) -> M.Engine:
  match op:
    case 49: external(49,e,stack)
    case 59: external(59,e,stack)
    case 60: extcopy(e,stack)
    case 63: external(63,e,stack)
    case 71:
      self_balance(Nat.is_ge(List.length(&2,W.Word,stack),U32.to_nat(1024)),e,stack)
    case 84: sload(stack,False{},e)
    case 85: store(False{},e,stack)
    case 92: sload(stack,True{},e)
    case 93: store(True{},e,stack)
    case 160: emit(0n,e,stack)
    case 161: emit(1n,e,stack)
    case 162: emit(2n,e,stack)
    case 163: emit(3n,e,stack)
    case 164: emit(4n,e,stack)
    case other: fault(e,4)

def dispatch(op: U32,+e: M.Engine) -> M.Engine:
  dispatch_stack(op,e,M.Frame.stack(M.Engine.frame(e)))
def step(+e: M.Engine) -> M.Engine:
  +f = M.Engine.frame(e)
  dispatch(B.get(M.Frame.pc(f),M.Frame.code(f)),e)


