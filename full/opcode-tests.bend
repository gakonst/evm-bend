import Base
import ./opcodes.bend as O
import ./model.bend as M
import ./opcode-common.bend as H
import ../evmword.bend as W
import ../word-ops.bend as WO
import ./memory.bend as Mem

def run(n: Nat,f: M.Frame) -> M.Frame:
  match n:
    case 0n: f
    case 1n+p: run(p,O.step(f,M.default_context()))

def frame(code: +List<U32>,stack: +List<W.Word>,gas: Nat) -> M.Frame:
  M.Frame.set_stack(M.initial_frame(code,gas,Nil{},W.zero(),W.zero(),W.zero()),stack)

def fault(a: M.Action,n: U32) -> Bool:
  match a:
    case M.Fault{r}: U32.is_eq(r,n)
    case other: False{}

def report(name: String,b: Bool) -> IO(Unit):
  match b:
    case True{}: IO.print(name ++ ": PASS")
    case False{}: IO.print(name ++ ": FAIL")

def test_op1() -> Bool:
  W.eq(H.arg(O.step(frame([1],[W.from_u32(3),W.from_u32(7)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(10))

def test_op2() -> Bool:
  W.eq(H.arg(O.step(frame([2],[W.from_u32(3),W.from_u32(7)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(21))

def test_op3() -> Bool:
  W.eq(H.arg(O.step(frame([3],[W.from_u32(7),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(4))

def test_op4() -> Bool:
  W.eq(H.arg(O.step(frame([4],[W.from_u32(7),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(2))

def test_op5() -> Bool:
  W.eq(H.arg(O.step(frame([5],[W.from_u32(7),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(2))

def test_op6() -> Bool:
  W.eq(H.arg(O.step(frame([6],[W.from_u32(7),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(1))

def test_op7() -> Bool:
  W.eq(H.arg(O.step(frame([7],[W.from_u32(7),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(1))

def test_op10() -> Bool:
  W.eq(H.arg(O.step(frame([10],[W.from_u32(3),W.from_u32(2)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(9))

def test_op11() -> Bool:
  W.eq(H.arg(O.step(frame([11],[W.from_u32(31),W.from_u32(42)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(42))

def test_op16() -> Bool:
  W.eq(H.arg(O.step(frame([16],[W.from_u32(2),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(1))

def test_op17() -> Bool:
  W.eq(H.arg(O.step(frame([17],[W.from_u32(2),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(0))

def test_op18() -> Bool:
  W.eq(H.arg(O.step(frame([18],[W.from_u32(2),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(1))

def test_op19() -> Bool:
  W.eq(H.arg(O.step(frame([19],[W.from_u32(2),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(0))

def test_op20() -> Bool:
  W.eq(H.arg(O.step(frame([20],[W.from_u32(3),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(1))

def test_op22() -> Bool:
  W.eq(H.arg(O.step(frame([22],[W.from_u32(6),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(2))

def test_op23() -> Bool:
  W.eq(H.arg(O.step(frame([23],[W.from_u32(6),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(7))

def test_op24() -> Bool:
  W.eq(H.arg(O.step(frame([24],[W.from_u32(6),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(5))

def test_op26() -> Bool:
  W.eq(H.arg(O.step(frame([26],[W.from_u32(31),W.from_u32(42)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(42))

def test_op27() -> Bool:
  W.eq(H.arg(O.step(frame([27],[W.from_u32(2),W.from_u32(3)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(12))

def test_op28() -> Bool:
  W.eq(H.arg(O.step(frame([28],[W.from_u32(2),W.from_u32(12)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(3))

def test_op29() -> Bool:
  W.eq(H.arg(O.step(frame([29],[W.from_u32(2),W.from_u32(12)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(3))

def test_op8() -> Bool:
  W.eq(H.arg(O.step(frame([8],[W.from_u32(7),W.from_u32(3),W.from_u32(5)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(0))

def test_op9() -> Bool:
  W.eq(H.arg(O.step(frame([9],[W.from_u32(7),W.from_u32(3),W.from_u32(7)],U32.to_nat(1000)),M.default_context()),0n),W.zero())

def test_unary21_0() -> Bool:
  W.eq(H.arg(O.step(frame([21],[W.from_u32(0)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(1))

def test_unary30_0() -> Bool:
  W.eq(H.arg(O.step(frame([30],[W.from_u32(0)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(256))

def test_unary30_1() -> Bool:
  W.eq(H.arg(O.step(frame([30],[W.from_u32(1)],U32.to_nat(1000)),M.default_context()),0n),W.from_u32(255))

def test_push_padding() -> Bool:
  W.eq(H.arg(O.step(frame([97,18],Nil{},U32.to_nat(100)),M.default_context()),0n),W.from_u32(4608))

def test_push_pc() -> Bool:
  Nat.is_eq(M.Frame.pc(O.step(frame([97,18],Nil{},U32.to_nat(100)),M.default_context())),3n)

def test_gas() -> Bool:
  W.eq(H.arg(O.step(frame([90],Nil{},U32.to_nat(100)),M.default_context()),0n),W.from_u32(98))

def test_underflow() -> Bool:
  fault(M.Frame.action(O.step(frame([1],Nil{},U32.to_nat(100)),M.default_context())),2)

def test_oog() -> Bool:
  fault(M.Frame.action(O.step(frame([1],[W.zero(),W.zero()],2n),M.default_context())),1)

def test_invalid() -> Bool:
  fault(M.Frame.action(O.step(frame([254],Nil{},U32.to_nat(100)),M.default_context())),4)

def test_jump_data() -> Bool:
  fault(M.Frame.action(O.step(frame([86,96,91],[W.from_u32(2)],U32.to_nat(100)),M.default_context())),5)

def test_jump_good() -> Bool:
  Nat.is_eq(M.Frame.pc(O.step(frame([86,91],[W.from_u32(1)],U32.to_nat(100)),M.default_context())),1n)

def test_jumpi_ignored() -> Bool:
  Nat.is_eq(M.Frame.pc(O.step(frame([87],[WO.ones(),W.zero()],U32.to_nat(100)),M.default_context())),1n)

def test_immediate_invalid() -> Bool:
  fault(M.Frame.action(O.step(frame([230,91],[W.zero()],U32.to_nat(100)),M.default_context())),8)

def test_immediate_missing() -> Bool:
  fault(M.Frame.action(O.step(frame([230],[W.zero()],U32.to_nat(100)),M.default_context())),8)

def test_exchange() -> Bool:
  W.eq(H.arg(O.step(frame([232,142],[W.from_u32(1),W.from_u32(2),W.from_u32(3)],U32.to_nat(100)),M.default_context()),1n),W.from_u32(3))

def test_mstoreload() -> Bool:
  W.eq(H.arg(run(6n,frame([96,42,95,82,95,81,0],Nil{},U32.to_nat(1000))),0n),W.from_u32(42))

def test_zero_return() -> Bool:
  Nat.is_eq(Mem.size(M.Frame.memory(O.step(frame([243],[WO.ones(),W.zero()],U32.to_nat(100)),M.default_context()))),0n)

def test_huge_memory() -> Bool:
  fault(M.Frame.action(O.step(frame([81],[WO.ones()],U32.to_nat(100)),M.default_context())),1)

def test_retbounds_zero() -> Bool:
  fault(M.Frame.action(O.step(frame([62],[W.zero(),W.from_u32(1),W.zero()],U32.to_nat(100)),M.default_context())),7)

def main() -> IO(Unit):
  do IO<Unit>:
    report("op1",test_op1())
    report("op2",test_op2())
    report("op3",test_op3())
    report("op4",test_op4())
    report("op5",test_op5())
    report("op6",test_op6())
    report("op7",test_op7())
    report("op10",test_op10())
    report("op11",test_op11())
    report("op16",test_op16())
    report("op17",test_op17())
    report("op18",test_op18())
    report("op19",test_op19())
    report("op20",test_op20())
    report("op22",test_op22())
    report("op23",test_op23())
    report("op24",test_op24())
    report("op26",test_op26())
    report("op27",test_op27())
    report("op28",test_op28())
    report("op29",test_op29())
    report("op8",test_op8())
    report("op9",test_op9())
    report("unary21_0",test_unary21_0())
    report("unary30_0",test_unary30_0())
    report("unary30_1",test_unary30_1())
    report("push_padding",test_push_padding())
    report("push_pc",test_push_pc())
    report("gas",test_gas())
    report("underflow",test_underflow())
    report("oog",test_oog())
    report("invalid",test_invalid())
    report("jump_data",test_jump_data())
    report("jump_good",test_jump_good())
    report("jumpi_ignored",test_jumpi_ignored())
    report("immediate_invalid",test_immediate_invalid())
    report("immediate_missing",test_immediate_missing())
    report("exchange",test_exchange())
    report("mstoreload",test_mstoreload())
    report("zero_return",test_zero_return())
    report("huge_memory",test_huge_memory())
    report("retbounds_zero",test_retbounds_zero())
