import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./gas.bend as G
import ./world.bend as World
import ./bytes.bend as B
import ./memory.bend as Mem
import ./call-common.bend as C

# kind is the opcode byte. Bit 8 in Parent.kind records refundable leaf gas.
type Request is Data:
  Request{kind: U32, gas: W.Word, target: W.Word, value: W.Word, in_offset: W.Word, in_size: W.Word, out_offset: W.Word, out_size: W.Word}

def delegated(+code: +List<U32>) -> Bool:
  Bool.and(Nat.is_eq(B.len(code),23n), Bool.and(U32.is_eq(B.get(0n,code),239), Bool.and(U32.is_eq(B.get(1n,code),1), U32.is_eq(B.get(2n,code),0))))

def delegation_address(code: +List<U32>) -> W.Word:
  B.to_word(B.concat([0,0,0,0,0,0,0,0,0,0,0,0],B.drop(3n,code)))

def precompile(eligible: Bool, target: W.Word) -> M.Action:
  match eligible:
    case True{}: M.Precompile{W.low_u32(target)}
    case False{}: M.Running{}

def child_action(disabled: Bool, +target: W.Word) -> M.Action:
  precompile(Bool.and(Bool.not(disabled),Bool.or(Bool.and(O.gt(target,W.zero()),O.lt(target,W.from_u32(18))),W.eq(target,W.from_u32(256)))),target)

def enter_transfer(do_transfer: Bool, +e: M.Engine, parents: +List<M.Parent>, parent: M.Parent, +child: M.Frame, world: M.World) -> M.Machine:
  match do_transfer:
    case True{}:
      M.Machine{M.Engine{child,C.transfer(world,M.Frame.caller(child),M.Frame.address(child),M.Frame.value(child)),M.Engine.context(e),M.Engine.reservoir(e),W.zero(),0n},parent <> parents}
    case False{}:
      M.Machine{M.Engine{child,world,M.Engine.context(e),M.Engine.reservoir(e),W.zero(),0n},parent <> parents}

def enter_balance(fail: Bool, +e: M.Engine, parents: +List<M.Parent>, +parent: M.Parent, +child: M.Frame, +kind: U32, charged: Bool) -> M.Machine:
  match fail:
    case True{}:
      +pf = M.Parent.frame(parent)
      +restored = M.Frame.set_gas(C.push(pf,W.zero()),Nat.add(M.Frame.gas(pf),M.Frame.gas(child)))
      M.Machine{C.refund_if(charged,M.Engine.set_frame(e,restored)),parents}
    case False{}:
      +world = M.Engine.world(e)
      enter_transfer(U32.is_eq(kind,241),e,parents,parent,child,world)

def enter_ready(bad: Bool, +e: M.Engine, parents: +List<M.Parent>, r: Request, +code: +List<U32>, disabled: Bool, +charged: Bool) -> M.Machine:
  match bad:
    case True{}: M.Machine{e,parents}
    case False{}:
      match r:
        case Request{+kind,+gas,+target,+value,in_offset,in_size,out_offset,out_size}:
          +f = M.Engine.frame(e)
          +with_value = Bool.and(Bool.or(U32.is_eq(kind,241),U32.is_eq(kind,242)),Bool.not(W.is_zero(value)))
          +limit = O.to_nat(C.word(O.lt(gas,O.from_nat(C.cap(M.Frame.gas(f)))),gas,O.from_nat(C.cap(M.Frame.gas(f)))))
          +child_gas = Nat.add(limit,C.nat(with_value,U32.to_nat(2300),0n))
          +parent_frame = M.Frame.set_gas(M.Frame.set_ret(M.Frame.set_action(f,M.Running{}),Nil{}),Nat.sub(M.Frame.gas(f),limit))
          +address = C.word(Bool.or(U32.is_eq(kind,242),U32.is_eq(kind,244)),M.Frame.address(f),target)
          +caller = C.word(U32.is_eq(kind,244),M.Frame.caller(f),M.Frame.address(f))
          +callvalue = C.word(U32.is_eq(kind,244),M.Frame.value(f),value)
          +child = {M.Frame{child_gas,0n,Nil{},Mem.empty(),code,M.memory_input(M.Frame.memory(f),O.to_nat(in_offset),O.to_nat(in_size)),Nil{},address,caller,callvalue,Bool.or(M.Frame.is_static(f),U32.is_eq(kind,250)),1n+M.Frame.depth(f),child_action(disabled,target),Nil{}} : M.Frame}
          +checkpoint = M.Engine.world(e)
          +parent = {M.Parent{parent_frame,checkpoint,U32.add(kind,U32.from_nat(C.nat(charged,U32.to_nat(256),0n))),O.to_nat(out_offset),O.to_nat(out_size),W.zero(),M.Engine.state_used(e),M.Engine.state_spilled(e)} : M.Parent}
          enter_balance(Bool.or(Nat.is_ge(M.Frame.depth(f),U32.to_nat(1024)),Bool.and(Bool.or(U32.is_eq(kind,241),U32.is_eq(kind,242)),O.lt(M.Account.balance(World.account(checkpoint,M.Frame.address(f))),value))),e,parents,parent,child,kind,charged)

def enter_state(+e: M.Engine, parents: +List<M.Parent>, +r: Request, code: +List<U32>, disabled: Bool, +charged: Bool) -> M.Machine:
  +paid = C.state_if(charged,e)
  enter_ready(G.failed(M.Frame.action(M.Engine.frame(paid))),paid,parents,r,code,disabled,charged)

def resolve(is_delegated: Bool, +e: M.Engine, parents: +List<M.Parent>, +r: Request, +a: M.Account, charged: Bool) -> M.Machine:
  match is_delegated:
    case False{}: enter_state(e,parents,r,M.Account.code(a),False{},charged)
    case True{}:
      +target = delegation_address(M.Account.code(a))
      +delegate = World.account(M.Engine.world(e),target)
      +paid = M.Engine.set_frame(e,G.charge(M.Engine.frame(e),C.access(delegate)))
      +warm = M.Engine.set_world(paid,World.warm_account(M.Engine.world(paid),target))
      enter_state(warm,parents,r,M.Account.code(delegate),True{},charged)

def access_ready(bad: Bool, +e: M.Engine, parents: +List<M.Parent>, +r: Request) -> M.Machine:
  match bad:
    case True{}: M.Machine{e,parents}
    case False{}:
      match r:
        case Request{+kind,gas,+target,+value,in_offset,in_size,out_offset,out_size}:
          +a = World.account(M.Engine.world(e),target)
          +with_value = Bool.and(Bool.or(U32.is_eq(kind,241),U32.is_eq(kind,242)),Bool.not(W.is_zero(value)))
          +paid = M.Engine.set_frame(e,G.charge(M.Engine.frame(e),Nat.add(Nat.sub(C.access(a),U32.to_nat(100)),C.nat(with_value,U32.to_nat(11300),0n))))
          +warm = M.Engine.set_world(paid,World.warm_account(M.Engine.world(paid),target))
          resolve(delegated(M.Account.code(a)),warm,parents,Request{kind,gas,target,value,in_offset,in_size,out_offset,out_size},a,Bool.and(U32.is_eq(kind,241),Bool.and(with_value,C.empty(a))))

def start_static(forbidden: Bool, +e: M.Engine, parents: +List<M.Parent>, r: Request) -> M.Machine:
  match forbidden:
    case True{}: M.Machine{M.Engine.set_frame(e,M.fault(M.Engine.frame(e),6)),parents}
    case False{}:
      match r:
        case Request{kind,gas,target,value,+in_offset,+in_size,+out_offset,+out_size}:
          +f = C.memory(C.memory(M.Engine.frame(e),in_offset,in_size),out_offset,out_size)
          access_ready(G.failed(M.Frame.action(f)),M.Engine.set_frame(e,f),parents,Request{kind,gas,target,value,in_offset,in_size,out_offset,out_size})

def start(+e: M.Engine, parents: +List<M.Parent>, +kind: U32, gas: W.Word, target: W.Word, +value: W.Word, in_offset: W.Word, in_size: W.Word, out_offset: W.Word, out_size: W.Word) -> M.Machine:
  start_static(Bool.and(M.Frame.is_static(M.Engine.frame(e)),Bool.and(U32.is_eq(kind,241),Bool.not(W.is_zero(value)))),e,parents,Request{kind,gas,World.normalize_address(target),value,in_offset,in_size,out_offset,out_size})
