import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M

def normalize_address(w: W.Word) -> W.Word:
  match w:
    case W.W{a,b,c,d,e,f,g,h}:
      W.W{a,b,c,d,e,0,0,0}

def choose_account(same: Bool, a: M.Account, b: M.Account) -> M.Account:
  match same:
    case True{}: a
    case False{}: b

def find(accounts: +List<M.Account>, +address: W.Word) -> M.Account:
  match accounts:
    case Nil{}: M.empty_account(address)
    case Con{+a,rest}: choose_account(W.eq(M.Account.address(a),address),a,find(rest,address))

def account(world: M.World,address: W.Word) -> M.Account:
  find(M.World.accounts(world),normalize_address(address))

def keep(same: Bool,a: M.Account,rest: +List<M.Account>) -> +List<M.Account>:
  match same:
    case True{}: rest
    case False{}: a <> rest

def erase(accounts: +List<M.Account>,+address: W.Word) -> +List<M.Account>:
  match accounts:
    case Nil{}: Nil{}
    case Con{+a,rest}: keep(W.eq(M.Account.address(a),address),a,erase(rest,address))

def put(+world: M.World,+a: M.Account) -> M.World:
  +addr = normalize_address(M.Account.address(a))
  M.World.set_accounts(world,M.Account.set_address(a,addr) <> erase(M.World.accounts(world),addr))

# Emptiness needs only the first constructor, not a recursive code length.
def code_empty(code: +List<U32>) -> Bool:
  match code:
    case Nil{}: True{}
    case Con{byte,rest}: False{}

def is_empty(+a: M.Account) -> Bool:
  Bool.and(W.is_zero(M.Account.balance(a)),Bool.and(W.is_zero(M.Account.nonce(a)),code_empty(M.Account.code(a))))

# EELS modify_state deletes an empty modified leaf immediately. Keep transaction
# metadata in an absent-account tombstone: reads/warmth are not account existence.
def modified_account(empty: Bool, +a: M.Account) -> M.Account:
  match empty:
    case True{}:
      M.Account.set_exists(M.Account.set_storage(M.Account.set_code(M.Account.set_nonce(M.Account.set_balance(a,W.zero()),W.zero()),Nil{}),Nil{}),False{})
    case False{}: M.Account.set_exists(a,True{})

def modify(world: M.World, +a: M.Account) -> M.World:
  put(world,modified_account(is_empty(a),a))

# SELFDESTRUCT calls move_ether even for zero, unlike ordinary message entry.
def move_ether(+world: M.World, +source: W.Word, +target: W.Word, +value: W.Word) -> M.World:
  +sender = account(world,source)
  +debited = modify(world,M.Account.set_balance(sender,O.sub(M.Account.balance(sender),value)))
  +recipient = account(debited,target)
  modify(debited,M.Account.set_balance(recipient,W.add(M.Account.balance(recipient),value)))

def transfer_nonzero(zero: Bool,+world: M.World,+source: W.Word,+target: W.Word,+value: W.Word) -> M.World:
  match zero:
    case True{}: world
    case False{}:
      +sender = account(world,source)
      +debited = modify(world,M.Account.set_balance(sender,O.sub(M.Account.balance(sender),value)))
      +recipient = account(debited,target)
      modify(debited,M.Account.set_balance(recipient,W.add(M.Account.balance(recipient),value)))

# Caller checks sufficient balance. Zero transfers do not create accounts.
def transfer(world: M.World,source: W.Word,target: W.Word,+value: W.Word) -> M.World:
  transfer_nonzero(W.is_zero(value),world,source,target,value)

def warm_account(+world: M.World,address: W.Word) -> M.World:
  put(world,M.Account.set_warm(account(world,address),True{}))

def word_choice(same: Bool,a: W.Word,b: W.Word) -> W.Word:
  match same:
    case True{}: a
    case False{}: b

def lookup(slots: +List<M.Slot>,+key: W.Word) -> W.Word:
  match slots:
    case Nil{}: W.zero()
    case Con{M.Slot{at,value},rest}: word_choice(W.eq(at,key),value,lookup(rest,key))

def keep_slot(same: Bool,slot: M.Slot,rest: +List<M.Slot>) -> +List<M.Slot>:
  match same:
    case True{}: rest
    case False{}: slot <> rest

def erase_slot(slots: +List<M.Slot>,+key: W.Word) -> +List<M.Slot>:
  match slots:
    case Nil{}: Nil{}
    case Con{M.Slot{+at,value},rest}: keep_slot(W.eq(at,key),M.Slot{at,value},erase_slot(rest,key))

def set(slots: +List<M.Slot>,+key: W.Word,value: W.Word) -> +List<M.Slot>:
  M.Slot{key,value} <> erase_slot(slots,key)

# Warm keys are a set. Repeated accesses must not grow a duplicate list;
# otherwise a loop touching one slot makes membership checks quadratic.
def contains_go(keys: +List<W.Word>,+key: W.Word,found: Bool) -> Bool:
  match keys found:
    case Nil{} seen: seen
    case Con{at,rest} True{}: True{}
    case Con{at,rest} False{}: contains_go(rest,key,W.eq(at,key))

def contains(keys: +List<W.Word>,key: W.Word) -> Bool:
  contains_go(keys,key,False{})

def warm_storage_if(warm: Bool,world: M.World,+a: M.Account,key: W.Word) -> M.World:
  match warm:
    case True{}: world
    case False{}: put(world,M.Account.set_storage_warm(a,key <> M.Account.storage_warm(a)))

def warm_storage(+world: M.World,address: W.Word,+key: W.Word) -> M.World:
  +a = account(world,address)
  warm_storage_if(contains(M.Account.storage_warm(a),key),world,a,key)

# original is the transaction-start snapshot; this operation never changes it.
def set_storage(+world: M.World,address: W.Word,key: W.Word,value: W.Word) -> M.World:
  +a = account(world,address)
  put(world,M.Account.set_storage(a,set(M.Account.storage(a),key,value)))

def set_transient(+world: M.World,address: W.Word,key: W.Word,value: W.Word) -> M.World:
  +a = account(world,address)
  put(world,M.Account.set_transient(a,set(M.Account.transient(a),key,value)))

def add_refund(+world: M.World,delta: W.Word) -> M.World:
  M.World.set_refund(world,W.add(M.World.refund(world),delta))

def append_log(logs: +List<M.Log>,log: M.Log) -> +List<M.Log>:
  match logs:
    case Nil{}: log <> Nil{}
    case Con{h,t}: h <> append_log(t,log)

def log(+world: M.World,event: M.Log) -> M.World:
  M.World.set_logs(world,append_log(M.World.logs(world),event))

