import Base
import ./model.bend as M
import ./world.bend as World
import ./state-ops.bend as S
import ./memory.bend as Mem
import ../evmword.bend as W
import ../word-ops.bend as O

def check(name: String,ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def engine(op: U32,stack: +List<W.Word>,world: M.World,reservoir: Nat) -> M.Engine:
  M.Engine{M.Frame.set_stack(M.initial_frame(op <> Nil{},U32.to_nat(200000),Nil{},W.zero(),W.zero(),W.zero()),stack),world,M.default_context(),reservoir,W.zero(),0n}

def run(op: U32,stack: +List<W.Word>,+e: M.Engine) -> M.Engine:
  S.step(M.Engine.set_frame(e,M.Frame.set_pc(M.Frame.set_code(M.Frame.set_stack(M.Engine.frame(e),stack),op <> Nil{}),0n)))

def top(stack: +List<W.Word>) -> W.Word:
  match stack:
    case Con{h,t}: h
    case Nil{}: W.from_u32(1)

def log_ok(logs: +List<M.Log>) -> Bool:
  match logs:
    case Con{M.Log{addr,topics,Con{a,Con{b,Nil{}}}},Nil{}}: U32.is_eq(a,170) && U32.is_eq(b,187) && W.eq(top(topics),W.from_u32(42))
    case other: False{}

def static_test(op: U32) -> Bool:
  +e = engine(op,[W.zero(),W.from_u32(1)],M.empty_world(),0n)
  +r = S.step(M.Engine.set_frame(e,M.Frame.set_is_static(M.Engine.frame(e),True{})))
  W.is_zero(World.lookup(M.Account.storage(World.account(M.Engine.world(r),W.zero())),W.zero())) && Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),0n)

def main() -> IO(Unit):
  do IO<Unit>:
    +a : M.Engine = S.step(engine(85,[W.zero(),W.from_u32(7)],M.empty_world(),U32.to_nat(97920)))
    check("cold new slot execution/state",Nat.is_eq(M.Frame.gas(M.Engine.frame(a)),U32.to_nat(187900)) && W.eq(M.Engine.state_used(a),W.from_u32(97920)) && Nat.is_eq(M.Engine.reservoir(a),0n))
    +b : M.Engine = run(85,[W.zero(),W.from_u32(9)],a)
    check("dirty write warm 100",Nat.is_eq(M.Frame.gas(M.Engine.frame(b)),U32.to_nat(187800)))
    +c : M.Engine = run(85,[W.zero(),W.zero()],b)
    check("zero restore state refill and execution refund",Nat.is_eq(M.Engine.reservoir(c),U32.to_nat(97920)) && W.is_zero(M.Engine.state_used(c)) && W.eq(M.World.refund(M.Engine.world(c)),W.from_u32(10000)))
    check("original retained",W.is_zero(World.lookup(M.Account.original(World.account(M.Engine.world(c),W.zero())),W.zero())))
    +d : M.Engine = S.step(engine(85,[W.zero(),W.from_u32(7)],M.empty_world(),0n))
    check("state spill",Nat.is_eq(M.Frame.gas(M.Engine.frame(d)),U32.to_nat(89980)) && Nat.is_eq(M.Engine.state_spilled(d),U32.to_nat(97920)))
    +r : M.Engine = run(85,[W.zero(),W.zero()],d)
    check("spill restoration",Nat.is_eq(M.Frame.gas(M.Engine.frame(r)),U32.to_nat(187800)) && Nat.is_eq(M.Engine.state_spilled(r),0n))
    check("signed dirty clear reversal",W.eq(S.refund(W.from_u32(5),W.zero(),W.from_u32(5)),O.sub(W.zero(),W.from_u32(1616))))
    check("clean clear refund",W.eq(S.refund(W.from_u32(5),W.from_u32(5),W.zero()),W.from_u32(11616)))
    +x : M.Engine = S.step(engine(59,[W.from_u32(999)],M.empty_world(),0n))
    check("external missing code size cold 3100",Nat.is_eq(M.Frame.gas(M.Engine.frame(x)),U32.to_nat(196900)) && W.is_zero(top(M.Frame.stack(M.Engine.frame(x)))))
    check("empty account hash",W.is_zero(S.codehash(M.empty_account(W.zero()))))
    +l : M.Engine = engine(161,[W.zero(),W.from_u32(2),W.from_u32(42)],M.empty_world(),0n)
    +lf : M.Frame = M.Engine.frame(l)
    +logged : M.Engine = S.step(M.Engine.set_frame(l,M.Frame.set_memory(lf,Mem.write(M.Frame.memory(lf),0n,[170,187]))))
    check("log gas and bytes",Nat.is_eq(M.Frame.gas(M.Engine.frame(logged)),U32.to_nat(199234)) && Nat.is_eq(List.length(&2,M.Log,M.World.logs(M.Engine.world(logged))),1n))
    check("address low160",W.eq(World.normalize_address(W.W{1,2,3,4,5,6,7,8}),W.W{1,2,3,4,5,0,0,0}))
    check("log exact bytes/topics",log_ok(M.World.logs(M.Engine.world(logged))))
    check("static SSTORE/TSTORE",static_test(85) && static_test(93))
    +zero : M.Engine = S.step(engine(160,[W.W{0,0,0,0,0,0,0,1},W.zero()],M.empty_world(),0n))
    check("zero size ignores huge offset",Nat.is_eq(M.Frame.gas(M.Engine.frame(zero)),U32.to_nat(199625)))
    +huge : M.Engine = S.step(engine(160,[W.W{0,0,0,0,0,0,0,1},W.from_u32(1)],M.empty_world(),0n))
    check("huge nonzero range OOG",Nat.is_eq(M.Frame.gas(M.Engine.frame(huge)),0n))
