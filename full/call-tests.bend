import Base
import ../evmword.bend as W
import ../word-ops.bend as O
import ./model.bend as M
import ./world.bend as World
import ./bytes.bend as B
import ./memory.bend as Mem
import ./gas.bend as G
import ./vm.bend as VM
import ./call-enter.bend as Call
import ./create-enter.bend as Create
import ./call-finish.bend as Finish
import ./call-selfdestruct.bend as Destroy
import ./create-address.bend as Address

def check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def base() -> M.Engine:
  +a = M.Account.set_exists(M.Account.set_balance(M.empty_account(W.from_u32(100)),W.from_u32(10)),True{})
  M.Engine{M.initial_frame(Nil{},U32.to_nat(100000),Nil{},W.from_u32(100),W.from_u32(50),W.from_u32(7)),World.put(M.empty_world(),a),M.default_context(),U32.to_nat(200000),W.zero(),0n}

def call(+e: M.Engine, kind: U32, value: U32, target: U32) -> M.Machine:
  # Call.start receives the frame after the dispatcher pays static CALL gas.
  Call.start(M.Engine.set_frame(e,G.charge(M.Engine.frame(e),U32.to_nat(100))),Nil{},kind,W.from_u32(10000),W.from_u32(target),W.from_u32(value),W.zero(),W.zero(),W.zero(),W.zero())

def complete(+m: M.Machine, action: M.Action, output: +List<U32>) -> M.Engine:
  +e = M.Machine.engine(m)
  +f = M.Frame.set_output(M.Frame.set_action(M.Engine.frame(e),action),output)
  M.Machine.engine(Finish.unwind(M.Engine.set_frame(e,f),M.Machine.parents(m)))

def top(stack: +List<W.Word>) -> W.Word:
  match stack:
    case Nil{}: W.zero()
    case Con{head,tail}: head

def success(+e: M.Engine) -> Bool:
  W.eq(top(M.Frame.stack(M.Engine.frame(e))),W.from_u32(1))

def empty_call() -> Bool:
  +e = complete(call(base(),241,0,200),M.Stopped{},Nil{})
  success(e) && Nat.is_eq(M.Frame.gas(M.Engine.frame(e)),U32.to_nat(97000)) && Nat.is_eq(M.Engine.reservoir(e),U32.to_nat(200000))

def value_call() -> Bool:
  +e = complete(call(base(),241,1,200),M.Stopped{},Nil{})
  success(e) && Nat.is_eq(M.Frame.gas(M.Engine.frame(e)),U32.to_nat(88000)) && Nat.is_eq(M.Engine.reservoir(e),U32.to_nat(16400)) && W.eq(M.Engine.state_used(e),W.from_u32(183600)) && W.eq(M.Account.balance(World.account(M.Engine.world(e),W.from_u32(200))),W.from_u32(1)) && Nat.is_eq(List.length(&2,M.Log,M.World.logs(M.Engine.world(e))),1n)

def revert_call() -> Bool:
  +e = complete(call(base(),241,1,200),M.Reverted{},[170])
  Bool.not(success(e)) && Nat.is_eq(M.Frame.gas(M.Engine.frame(e)),U32.to_nat(88000)) && Nat.is_eq(M.Engine.reservoir(e),U32.to_nat(200000)) && W.is_zero(M.Engine.state_used(e)) && W.eq(M.Account.balance(World.account(M.Engine.world(e),W.from_u32(100))),W.from_u32(10)) && Nat.is_eq(B.len(M.Frame.ret(M.Engine.frame(e))),1n) && Nat.is_eq(List.length(&2,M.Log,M.World.logs(M.Engine.world(e))),0n)

def depth_call() -> Bool:
  +e = base()
  +deep = M.Engine.set_frame(e,M.Frame.set_depth(M.Engine.frame(e),U32.to_nat(1024)))
  +r = M.Machine.engine(call(deep,241,1,200))
  Bool.not(success(r)) && Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),U32.to_nat(88000)) && Nat.is_eq(M.Engine.reservoir(r),U32.to_nat(200000)) && M.Account.warm(World.account(M.Engine.world(r),W.from_u32(200)))

def callcode() -> Bool:
  +m = call(base(),242,1,200)
  +f = M.Engine.frame(M.Machine.engine(m))
  +e = complete(m,M.Stopped{},Nil{})
  W.eq(M.Frame.address(f),W.from_u32(100)) && W.eq(M.Frame.caller(f),W.from_u32(100)) && W.eq(M.Frame.value(f),W.from_u32(1)) && Nat.is_eq(M.Engine.reservoir(e),U32.to_nat(200000)) && Nat.is_eq(List.length(&2,M.Log,M.World.logs(M.Engine.world(e))),0n)

def delegate() -> Bool:
  +f = M.Engine.frame(M.Machine.engine(call(base(),244,0,200)))
  W.eq(M.Frame.address(f),W.from_u32(100)) && W.eq(M.Frame.caller(f),W.from_u32(50)) && W.eq(M.Frame.value(f),W.from_u32(7)) && Nat.is_eq(M.Frame.gas(f),U32.to_nat(10000))

def precompile(action: M.Action) -> Bool:
  match action:
    case M.Precompile{address}: U32.is_eq(address,256)
    case other: False{}

def p256() -> Bool:
  precompile(M.Frame.action(M.Engine.frame(M.Machine.engine(call(base(),250,0,256)))))

def delegated_code() -> Bool:
  +e = base()
  +a = M.Account.set_code(M.empty_account(W.from_u32(200)),B.concat([239,1,0],B.drop(12n,B.from_word(W.from_u32(256)))))
  +m = call(M.Engine.set_world(e,World.put(M.Engine.world(e),a)),241,0,200)
  +child = M.Engine.frame(M.Machine.engine(m))
  +r = complete(m,M.Stopped{},Nil{})
  Bool.not(precompile(M.Frame.action(child))) && Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),U32.to_nat(94000))

def create(e: M.Engine) -> M.Machine:
  Create.start(e,Nil{},240,W.zero(),W.zero(),W.zero(),W.zero())

def create_stop() -> Bool:
  +m = create(base())
  +address = M.Frame.address(M.Engine.frame(M.Machine.engine(m)))
  +r = complete(m,M.Stopped{},Nil{})
  W.eq(top(M.Frame.stack(M.Engine.frame(r))),address) && W.eq(M.Account.nonce(World.account(M.Engine.world(r),W.from_u32(100))),W.from_u32(1)) && M.Account.created(World.account(M.Engine.world(r),address)) && Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),U32.to_nat(88000))

def create_deposit() -> Bool:
  +m = create(base())
  +address = M.Frame.address(M.Engine.frame(M.Machine.engine(m)))
  +r = complete(m,M.Returned{},[0])
  Nat.is_eq(B.len(M.Account.code(World.account(M.Engine.world(r),address))),1n) && Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),U32.to_nat(87994)) && W.eq(M.Engine.state_used(r),W.from_u32(185130))

def create_invalid() -> Bool:
  +r = complete(create(base()),M.Returned{},[239])
  W.is_zero(top(M.Frame.stack(M.Engine.frame(r)))) && Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),U32.to_nat(1375)) && Nat.is_eq(M.Engine.reservoir(r),U32.to_nat(200000)) && W.eq(M.Account.nonce(World.account(M.Engine.world(r),W.from_u32(100))),W.from_u32(1))

def create_collision() -> Bool:
  +e = base()
  +address = Address.create(W.from_u32(100),W.zero())
  +a = M.Account.set_nonce(M.empty_account(address),W.from_u32(1))
  +m = create(M.Engine.set_world(e,World.put(M.Engine.world(e),a)))
  +r = M.Machine.engine(VM.step(m))
  W.is_zero(top(M.Frame.stack(M.Engine.frame(r)))) && Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),U32.to_nat(1375)) && Nat.is_eq(M.Engine.reservoir(r),U32.to_nat(200000))

def destruct_self() -> Bool:
  +e = base()
  +world = M.Engine.world(e)
  +a = M.Account.set_created(M.Account.set_nonce(World.account(world,W.from_u32(100)),W.from_u32(1)),True{})
  +r = Destroy.start(M.Engine.set_world(e,World.put(world,a)),W.from_u32(100))
  +before = World.account(M.Engine.world(r),W.from_u32(100))
  +after = World.account(Destroy.finalize(M.Engine.world(r)),W.from_u32(100))
  W.eq(M.Account.balance(before),W.from_u32(10)) && W.eq(M.Account.nonce(before),W.from_u32(1)) && W.eq(M.Account.balance(after),W.from_u32(10)) && W.is_zero(M.Account.nonce(after))

def iterate(n: Nat, machine: M.Machine) -> M.Machine:
  match n:
    case 0n: machine
    case 1n+p: iterate(p,VM.step(machine))

def nested_bytecode() -> Bool:
  +e = base()
  +f = M.Frame.set_code(M.Engine.frame(e),[95,95,95,95,95,96,200,97,39,16,241,0])
  +m = iterate(14n,M.Machine{M.Engine.set_frame(e,f),Nil{}})
  VM.finished(m) && success(M.Machine.engine(m)) && Nat.is_eq(M.Frame.gas(M.Engine.frame(M.Machine.engine(m))),U32.to_nat(96984))

def main() -> IO(Unit):
  do IO<Unit>:
    check("empty CALL gas",empty_call())
    check("value CALL gas reservoir log",value_call())
    check("REVERT world gas state refund",revert_call())
    check("depth failure stipend and warm target",depth_call())
    check("CALLCODE context no transfer",callcode())
    check("DELEGATECALL caller value",delegate())
    check("P256 precompile handoff",p256())
    check("7702 delegation access and precompile disabled",delegated_code())
    check("CREATE empty deployment nonce",create_stop())
    check("CREATE code deposit state",create_deposit())
    check("CREATE invalid EF rollback",create_invalid())
    check("CREATE collision gas",create_collision())
    check("SELFDESTRUCT self balance deferred reset",destruct_self())
    check("nested bytecode CALL STOP",nested_bytecode())
