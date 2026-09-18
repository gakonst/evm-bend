import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./gas.bend as G
import ./world.bend as World
import ./bytes.bend as B
import ./memory.bend as Mem
import ./call-common.bend as C
import ./create-address.bend as Address

def collision(+a: M.Account) -> Bool:
  Bool.or(Bool.not(W.is_zero(M.Account.nonce(a))),Nat.is_ne(B.len(M.Account.code(a)),0n))

def address(kind: U32, sender: W.Word, nonce: W.Word, salt: W.Word, code: +List<U32>) -> W.Word:
  match kind:
    case 245: Address.create2(sender,salt,code)
    case other: Address.create(sender,nonce)

def collide(collided: Bool, +e: M.Engine, parents: +List<M.Parent>, parent: M.Parent, +child: M.Frame, +target: W.Word) -> M.Machine:
  match collided:
    case True{}:
      M.Machine{M.Engine{M.fault(child,9),M.Engine.world(e),M.Engine.context(e),M.Engine.reservoir(e),W.zero(),0n},parent <> parents}
    case False{}:
      +world = M.Engine.world(e)
      +a = World.account(world,target)
      +new_account = M.Account.set_created(M.Account.set_exists(M.Account.set_nonce(M.Account.set_original(M.Account.set_storage(a,Nil{}),Nil{}),W.from_u32(1)),True{}),True{})
      +world = C.transfer(World.modify(world,new_account),M.Frame.caller(child),target,M.Frame.value(child))
      M.Machine{M.Engine{child,world,M.Engine.context(e),M.Engine.reservoir(e),W.zero(),0n},parent <> parents}

def state_ready(bad: Bool, +e: M.Engine, parents: +List<M.Parent>, kind: U32, value: W.Word, code: +List<U32>, +target: W.Word, charged: Bool) -> M.Machine:
  match bad:
    case True{}: M.Machine{e,parents}
    case False{}:
      +f = M.Engine.frame(e)
      +world = M.Engine.world(e)
      +sender = World.account(world,M.Frame.address(f))
      +world = World.modify(world,M.Account.set_nonce(sender,W.add(M.Account.nonce(sender),W.from_u32(1))))
      +gas = C.cap(M.Frame.gas(f))
      +parent_frame = M.Frame.set_gas(M.Frame.set_action(M.Frame.set_ret(f,Nil{}),M.Running{}),Nat.sub(M.Frame.gas(f),gas))
      +parent = {M.Parent{parent_frame,world,U32.add(kind,U32.from_nat(C.nat(charged,U32.to_nat(256),0n))),0n,0n,target,M.Engine.state_used(e),M.Engine.state_spilled(e)} : M.Parent}
      child = {M.Frame{gas,0n,Nil{},Mem.empty(),code,M.empty_input(),Nil{},target,M.Frame.address(f),value,False{},1n+M.Frame.depth(f),M.Running{},Nil{}} : M.Frame}
      collide(collision(World.account(world,target)),M.Engine.set_world(e,world),parents,parent,child,target)

def destination(+e: M.Engine, parents: +List<M.Parent>, kind: U32, value: W.Word, code: +List<U32>, +target: W.Word) -> M.Machine:
  +charged = C.empty(World.account(M.Engine.world(e),target))
  +warm = M.Engine.set_world(e,World.warm_account(M.Engine.world(e),target))
  +paid = C.state_if(charged,warm)
  state_ready(G.failed(M.Frame.action(M.Engine.frame(paid))),paid,parents,kind,value,code,target,charged)

def precheck(failed: Bool, +e: M.Engine, parents: +List<M.Parent>, +kind: U32, value: W.Word, offset: W.Word, size: W.Word, salt: W.Word) -> M.Machine:
  match failed:
    case True{}:
      M.Machine{M.Engine.set_frame(e,C.push(M.Frame.set_ret(M.Engine.frame(e),Nil{}),W.zero())),parents}
    case False{}:
      +f = M.Engine.frame(e)
      +code = Mem.read(M.Frame.memory(f),O.to_nat(offset),O.to_nat(size))
      +sender = M.Frame.address(f)
      target = address(kind,sender,M.Account.nonce(World.account(M.Engine.world(e),sender)),salt,code)
      destination(e,parents,kind,value,code,target)

def paid(bad: Bool, +e: M.Engine, parents: +List<M.Parent>, kind: U32, +value: W.Word, offset: W.Word, size: W.Word, salt: W.Word) -> M.Machine:
  match bad:
    case True{}: M.Machine{e,parents}
    case False{}:
      +f = M.Engine.frame(e)
      +sender = World.account(M.Engine.world(e),M.Frame.address(f))
      failed = Bool.or(Nat.is_ge(M.Frame.depth(f),U32.to_nat(1024)),Bool.or(O.lt(M.Account.balance(sender),value),Bool.not(O.lt(M.Account.nonce(sender),W.W{4294967295,4294967295,0,0,0,0,0,0}))))
      precheck(failed,e,parents,kind,value,offset,size,salt)

def size_ok(too_large: Bool, +e: M.Engine, parents: +List<M.Parent>, +kind: U32, value: W.Word, +offset: W.Word, +size: W.Word, salt: W.Word) -> M.Machine:
  match too_large:
    case True{}: M.Machine{C.fail(e),parents}
    case False{}:
      +f = G.charge(C.memory(M.Engine.frame(e),offset,size),Nat.add(U32.to_nat(12000),Nat.mul(C.nat(U32.is_eq(kind,245),8n,2n),Mem.words(O.to_nat(size)))))
      paid(G.failed(M.Frame.action(f)),M.Engine.set_frame(e,f),parents,kind,value,offset,size,salt)

def static_check(is_static: Bool, +e: M.Engine, parents: +List<M.Parent>, kind: U32, value: W.Word, offset: W.Word, +size: W.Word, salt: W.Word) -> M.Machine:
  match is_static:
    case True{}: M.Machine{M.Engine.set_frame(e,M.fault(M.Engine.frame(e),6)),parents}
    case False{}: size_ok(O.gt(size,W.from_u32(131072)),e,parents,kind,value,offset,size,salt)

def start(+e: M.Engine, parents: +List<M.Parent>, kind: U32, value: W.Word, offset: W.Word, size: W.Word, salt: W.Word) -> M.Machine:
  static_check(M.Frame.is_static(M.Engine.frame(e)),e,parents,kind,value,offset,size,salt)
