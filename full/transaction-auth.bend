import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./transaction-types.bend as T
import ./gas.bend as G
import ./world.bend as World
import ./bytes.bend as B
import ./call-enter.bend as Call

# Signature recovery/hash construction are the explicit crypto
# boundary. Parity and scalar ranges are checked in Bend. Some(authority) attests recovery for this exact tuple, not validity
# against the chain or state; those checks remain here.
type AuthResult is Data:
  AuthResult{engine: M.Engine, preparation_failed: Bool, snapshot: M.World, paid_writes: +List<W.Word>, designation_set: +List<W.Word>}

def AuthResult.engine(x: AuthResult) -> M.Engine:
  match x:
    case AuthResult{engine,preparation_failed,snapshot,paid_writes,designation_set}: engine

def AuthResult.preparation_failed(x: AuthResult) -> Bool:
  match x:
    case AuthResult{engine,preparation_failed,snapshot,paid_writes,designation_set}: preparation_failed

def AuthResult.snapshot(x: AuthResult) -> M.World:
  match x:
    case AuthResult{engine,preparation_failed,snapshot,paid_writes,designation_set}: snapshot

def AuthResult.paid_writes(x: AuthResult) -> +List<W.Word>:
  match x:
    case AuthResult{engine,preparation_failed,snapshot,paid_writes,designation_set}: paid_writes

def AuthResult.designation_set(x: AuthResult) -> +List<W.Word>:
  match x:
    case AuthResult{engine,preparation_failed,snapshot,paid_writes,designation_set}: designation_set

def result(+e: M.Engine, paid: +List<W.Word>, designated: +List<W.Word>) -> AuthResult:
  AuthResult{e,G.failed(M.Frame.action(M.Engine.frame(e))),M.Engine.world(e),paid,designated}

def code(clear: Bool, target: W.Word) -> +List<U32>:
  match clear:
    case True{}: Nil{}
    case False{}: B.concat([239,1,0],B.drop(12n,B.from_word(World.normalize_address(target))))

def state_charge(charge: Bool, e: M.Engine, amount: Nat) -> M.Engine:
  match charge:
    case False{}: e
    case True{}: G.spend_state(e,amount)

def write_charge(skip: Bool, +e: M.Engine) -> M.Engine:
  match skip:
    case True{}: e
    case False{}: M.Engine.set_frame(e,G.charge(M.Engine.frame(e),U32.to_nat(9000)))

def mark(set: Bool, address: W.Word, marked: +List<W.Word>) -> +List<W.Word>:
  match set:
    case True{}: address <> marked
    case False{}: marked

def commit(bad: Bool, +e: M.Engine, +auth: T.Authorization, +authority: W.Word, paid: +List<W.Word>, designated: +List<W.Word>) -> AuthResult:
  match bad:
    case True{}: result(e,paid,designated)
    case False{}:
      +a = World.account(M.Engine.world(e),authority)
      +updated = M.Account.set_exists(M.Account.set_nonce(M.Account.set_code(a,code(W.is_zero(T.Authorization.address(auth)),T.Authorization.address(auth))),W.add(M.Account.nonce(a),W.from_u32(1))),True{})
      result(M.Engine.set_world(e,World.modify(M.Engine.world(e),updated)),authority <> paid,mark(Bool.not(W.is_zero(T.Authorization.address(auth))),authority,designated))

def indicator(bad: Bool, +e: M.Engine, original: M.World, +auth: T.Authorization, +authority: W.Word, paid: +List<W.Word>, +designated: +List<W.Word>) -> AuthResult:
  match bad:
    case True{}: result(e,paid,designated)
    case False{}:
      need = Bool.and(Bool.not(W.is_zero(T.Authorization.address(auth))),Bool.and(Bool.not(Call.delegated(M.Account.code(World.account(original,authority)))),Bool.not(World.contains(designated,authority))))
      +charged = state_charge(need,e,U32.to_nat(35190))
      commit(G.failed(M.Frame.action(M.Engine.frame(charged))),charged,auth,authority,paid,designated)

def write(bad: Bool, +e: M.Engine, original: M.World, auth: T.Authorization, +authority: W.Word, +paid: +List<W.Word>, designated: +List<W.Word>) -> AuthResult:
  match bad:
    case True{}: result(e,paid,designated)
    case False{}:
      +charged = write_charge(World.contains(paid,authority),e)
      indicator(G.failed(M.Frame.action(M.Engine.frame(charged))),charged,original,auth,authority,paid,designated)

def valid(ok: Bool, +e: M.Engine, original: M.World, auth: T.Authorization, +authority: W.Word, paid: +List<W.Word>, designated: +List<W.Word>) -> AuthResult:
  match ok:
    case False{}: result(e,paid,designated)
    case True{}:
      +charged = state_charge(Bool.not(M.Account.exists(World.account(M.Engine.world(e),authority))),e,U32.to_nat(183600))
      write(G.failed(M.Frame.action(M.Engine.frame(charged))),charged,original,auth,authority,paid,designated)

def recovered(authority: Maybe<&2,W.Word>, +e: M.Engine, original: M.World, +auth: T.Authorization, paid: +List<W.Word>, designated: +List<W.Word>) -> AuthResult:
  match authority:
    case None{}: result(e,paid,designated)
    case Some{address}:
      +at = World.normalize_address(address)
      +warm = M.Engine.set_world(e,World.warm_account(M.Engine.world(e),at))
      +a = World.account(M.Engine.world(warm),at)
      ok = Bool.and(Bool.or(Nat.is_eq(B.len(M.Account.code(a)),0n),Call.delegated(M.Account.code(a))),W.eq(M.Account.nonce(a),T.Authorization.nonce(auth)))
      valid(ok,warm,original,auth,at,paid,designated)

def signature_shape(+auth: T.Authorization) -> Bool:
  Bool.and(U32.is_le(T.Authorization.parity(auth),1),Bool.and(Bool.and(Bool.not(W.is_zero(T.Authorization.r(auth))),O.lt(T.Authorization.r(auth),W.W{3493216577,3218235020,2940772411,3132021990,4294967294,4294967295,4294967295,4294967295})),Bool.and(Bool.not(W.is_zero(T.Authorization.s(auth))),Bool.not(O.gt(T.Authorization.s(auth),W.W{1746608288,3756601158,1470386205,1566010995,4294967295,4294967295,4294967295,2147483647})))))

def eligible(ok: Bool, e: M.Engine, original: M.World, +auth: T.Authorization, paid: +List<W.Word>, designated: +List<W.Word>) -> AuthResult:
  match ok:
    case False{}: result(e,paid,designated)
    case True{}: recovered(T.Authorization.authority(auth),e,original,auth,paid,designated)

def one(bad: Bool, e: M.Engine, original: M.World, +chain: W.Word, +auth: T.Authorization, paid: +List<W.Word>, designated: +List<W.Word>) -> AuthResult:
  match bad:
    case True{}: result(e,paid,designated)
    case False{}:
      ok = Bool.and(Bool.or(W.is_zero(T.Authorization.chainid(auth)),W.eq(T.Authorization.chainid(auth),chain)),O.lt(T.Authorization.nonce(auth),W.W{4294967295,4294967295,0,0,0,0,0,0}))
      eligible(Bool.and(ok,signature_shape(auth)),e,original,auth,paid,designated)

def sequence(auths: +List<T.Authorization>, +original: M.World, +chain: W.Word, +state: AuthResult) -> AuthResult:
  match auths:
    case Nil{}: state
    case Con{auth,rest}:
      sequence(rest,original,chain,one(AuthResult.preparation_failed(state),AuthResult.engine(state),original,chain,auth,AuthResult.paid_writes(state),AuthResult.designation_set(state)))

# original is before transaction mutation. paid starts with sender plus the
# value-bearing recipient. snapshot is the post-auth dispatch rollback world.
# Failure leaves partial preparation visible for diagnosis: caller must restore
# its pre-preparation world and settle the failed meter before returning.
def process(e: M.Engine, original: M.World, chain: W.Word, auths: +List<T.Authorization>, paid: +List<W.Word>) -> AuthResult:
  sequence(auths,original,chain,result(e,paid,Nil{}))
