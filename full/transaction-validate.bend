import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./world.bend as World
import ./bytes.bend as B
import ./transaction-types.bend as T
import ./transaction-intrinsic.bend as I

# Decoded envelope validation; sender/signature recovery is trusted externally.
# Context has no consumed block execution/state/blob counters: inclusion capacity
# remains a caller obligation. 100 is a host representation limit, not EVM OOG.
# effective_price/upfront require validate == 0; upfront excludes transfer value.
def choose(test: Bool, a: W.Word, b: W.Word) -> W.Word:
  match test:
    case True{}: a
    case False{}: b

def reject(test: Bool, code: U32, next: U32) -> U32:
  match test:
    case True{}: code
    case False{}: next

def mul_overflow_zero(zero: Bool, a: W.Word, b: W.Word) -> Bool:
  match zero:
    case True{}: False{}
    case False{}: O.gt(a, O.div(O.ones(), b))

def mul_overflow(a: W.Word, +b: W.Word) -> Bool:
  mul_overflow_zero(W.is_zero(b), a, b)

def add_overflow(+a: W.Word, b: W.Word) -> Bool:
  O.lt(W.add(a, b), a)

def effective_price(+tx: T.Transaction, +context: M.Context) -> W.Word:
  +base = M.Context.basefee(context)
  +tip = T.Transaction.tip(tx)
  +room = O.sub(T.Transaction.fee_cap(tx), base)
  choose(U32.is_lt(T.Transaction.kind(tx), 2), T.Transaction.fee_cap(tx), W.add(base, choose(O.lt(tip, room), tip, room)))

def blob_count_go(xs: +List<W.Word>, acc: Nat) -> Nat:
  match xs:
    case Nil{}: acc
    case Con{h,t}: blob_count_go(t,Nat.add(acc,1n))

def blob_count(xs: +List<W.Word>) -> Nat:
  blob_count_go(xs,0n)

def blob_gas(+tx: T.Transaction) -> W.Word:
  choose(U32.is_eq(T.Transaction.kind(tx), 3), O.mul(O.from_nat(blob_count(T.Transaction.blobhashes(tx))), W.from_u32(131072)), W.zero())

def upfront(+tx: T.Transaction, +context: M.Context) -> W.Word:
  W.add(O.mul(O.from_nat(T.Transaction.gas(tx)), effective_price(tx, context)), O.mul(blob_gas(tx), M.Context.blobbasefee(context)))

def canonical_address(+w: W.Word) -> Bool:
  W.eq(w, World.normalize_address(w))

def destination(to: +Maybe<W.Word>) -> Bool:
  match to:
    case None{}: True{}
    case Some{x}: canonical_address(x)

def creation(to: +Maybe<W.Word>) -> Bool:
  match to:
    case None{}: True{}
    case Some{x}: False{}

def bytes_valid_go(xs: +List<U32>, valid: Bool) -> Bool:
  match xs:
    case Nil{}: valid
    case Con{h,t}: bytes_valid_go(t,valid && U32.is_le(h,255))

def bytes_valid(xs: +List<U32>) -> Bool:
  bytes_valid_go(xs,True{})

def access_valid_go(xs: +List<T.Access>, valid: Bool) -> Bool:
  match xs:
    case Nil{}: valid
    case Con{h,t}: access_valid_go(t,valid && canonical_address(T.Access.address(h)))

def access_valid(xs: +List<T.Access>) -> Bool:
  access_valid_go(xs,True{})

def access_empty(xs: +List<T.Access>) -> Bool:
  match xs:
    case Nil{}: True{}
    case Con{h,t}: False{}

def auth_empty(xs: +List<T.Authorization>) -> Bool:
  match xs:
    case Nil{}: True{}
    case Con{h,t}: False{}

def chain_valid(id: +Maybe<W.Word>, kind: U32, expected: W.Word) -> Bool:
  match id:
    case None{}: U32.is_eq(kind,0)
    case Some{+id}: W.eq(id,expected) && Bool.not(O.gt(id,W.W{4294967295,4294967295,0,0,0,0,0,0}))

def blobs_valid_go(xs: +List<W.Word>, valid: Bool) -> Bool:
  match xs:
    case Nil{}: valid
    case Con{h,t}: blobs_valid_go(t,valid && W.eq(O.byte(W.zero(),h),W.from_u32(1)))

def blobs_valid(xs: +List<W.Word>) -> Bool:
  blobs_valid_go(xs,True{})

def sender_code(+code: +List<U32>) -> Bool:
  Nat.is_eq(B.len(code),0n) || (Nat.is_eq(B.len(code),23n) && U32.is_eq(B.get(0n,code),239) && U32.is_eq(B.get(1n,code),1) && U32.is_eq(B.get(2n,code),0) && bytes_valid(code))

def intrinsic_bad(+tx: T.Transaction) -> Bool:
  +cost = I.compute(tx)
  +execution = I.Intrinsic.execution(cost)
  +floor = I.Intrinsic.floor(cost)
  Nat.is_gt(execution,T.Transaction.gas(tx)) || Nat.is_gt(floor,T.Transaction.gas(tx)) || Nat.is_gt(execution,U32.to_nat(16777216)) || Nat.is_gt(floor,U32.to_nat(16777216))

# Exact rejection facets are serialized by conformance/rejection_mapping.py.
# 1 malformed decoded envelope and 100 host bound have no EEST translation.
# Original codes retain their first facet; 16..24 distinguish grouped failures.
def intrinsic_reason(+tx: T.Transaction) -> U32:
  +cost = I.compute(tx)
  +execution = I.Intrinsic.execution(cost)
  +floor = I.Intrinsic.floor(cost)
  reject(Nat.is_gt(execution,T.Transaction.gas(tx)),8,
    reject(Nat.is_gt(floor,T.Transaction.gas(tx)),20,
    reject(Nat.is_gt(execution,U32.to_nat(16777216)) || Nat.is_gt(floor,U32.to_nat(16777216)),8,0)))
def validate(+tx: T.Transaction, world: M.World, +context: M.Context) -> U32:
  +kind = T.Transaction.kind(tx)
  +gas = T.Transaction.gas(tx)
  +account = World.account(world,T.Transaction.sender(tx))
  +cap = T.Transaction.fee_cap(tx)
  +blobcap = T.Transaction.blob_fee_cap(tx)
  +bg = blob_gas(tx)
  +gasword = O.from_nat(gas)
  +fee = O.mul(gasword,cap)
  +blobfee = O.mul(bg,blobcap)
  +fees = W.add(fee,blobfee)
  +value = T.Transaction.value(tx)
  +nblobs = blob_count(T.Transaction.blobhashes(tx))
  +create = creation(T.Transaction.to(tx))
  +plain = U32.is_lt(kind,2)
  +blob = U32.is_eq(kind,3)
  +auth = U32.is_eq(kind,4)
  reject(Nat.is_gt(gas,Nat.add(Nat.mul(U32.to_nat(65535),O.radix32()),U32.to_nat(4294967295))),100,
    reject(U32.is_gt(kind,4) || Bool.not(canonical_address(T.Transaction.sender(tx)) && destination(T.Transaction.to(tx)) && bytes_valid(T.Transaction.data(tx)) && access_valid(T.Transaction.access_list(tx))) || (U32.is_eq(kind,0) && Bool.not(access_empty(T.Transaction.access_list(tx)))) || (plain && Bool.not(W.eq(cap,T.Transaction.tip(tx)))) || (Bool.not(blob) && (Nat.is_ne(nblobs,0n) || Bool.not(W.is_zero(blobcap)))) || (Bool.not(auth) && Bool.not(auth_empty(T.Transaction.authorizations(tx)))),1,
    reject(Bool.not(chain_valid(T.Transaction.chainid(tx),kind,M.Context.chainid(context))),2,
    reject(O.gt(T.Transaction.nonce(tx),W.W{4294967295,4294967295,0,0,0,0,0,0}),22,
    reject(W.eq(T.Transaction.nonce(tx),W.W{4294967295,4294967295,0,0,0,0,0,0}),3,
    reject(create && Nat.is_gt(B.len(T.Transaction.data(tx)),U32.to_nat(131072)),4,
    reject(O.gt(T.Transaction.tip(tx),cap),5,
    reject(blob && create,6,
    reject(blob && Nat.is_eq(nblobs,0n),16,
    reject(blob && Nat.is_gt(nblobs,6n),17,
    reject(blob && Bool.not(blobs_valid(T.Transaction.blobhashes(tx))),18,
    reject(auth && create,7,
    reject(auth && auth_empty(T.Transaction.authorizations(tx)),19,
    reject(U32.is_ne(intrinsic_reason(tx),0),intrinsic_reason(tx),
    reject(O.gt(gasword,M.Context.gaslimit(context)),9,
    reject(O.lt(cap,M.Context.basefee(context)),10,
    reject(blob && O.lt(blobcap,M.Context.blobbasefee(context)),11,
    reject(O.lt(T.Transaction.nonce(tx),M.Account.nonce(account)),12,
    reject(O.gt(T.Transaction.nonce(tx),M.Account.nonce(account)),21,
    reject(mul_overflow(gasword,cap),13,
    reject(mul_overflow(bg,blobcap) || add_overflow(fee,blobfee) || add_overflow(fees,value),24,
    reject(O.gt(W.add(fees,value),M.Account.balance(account)),14,
    reject(Bool.not(sender_code(M.Account.code(account))),15,0)))))))))))))))))))))))
