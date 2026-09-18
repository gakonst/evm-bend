import Base
import ../evmword.bend as W
import ./model.bend as M
import ./gas.bend as G
import ./world.bend as World
import ./bytes.bend as B
import ./memory.bend as Mem
import ./call-common.bend as C
import ./create-finish.bend as Create

def is_create(+kind: U32) -> Bool:
  Bool.or(U32.is_eq(U32.and(kind,255),240),U32.is_eq(U32.and(kind,255),245))

def output(keep: Bool, bytes: +List<U32>) -> +List<U32>:
  match keep:
    case True{}: bytes
    case False{}: Nil{}

def world(success: Bool, current: M.World, snapshot: M.World) -> M.World:
  match success:
    case True{}: current
    case False{}: snapshot

def resume_frame(creation: Bool, +parent: M.Parent, +child: M.Frame) -> M.Frame:
  match creation:
    case True{}:
      +pf = M.Parent.frame(parent)
      M.Frame.set_ret(C.push(M.Frame.set_gas(pf,Nat.add(M.Frame.gas(pf),M.Frame.gas(child))),C.word(G.successful(M.Frame.action(child)),M.Parent.created_address(parent),W.zero())),output(G.reverted(M.Frame.action(child)),M.Frame.output(child)))
    case False{}:
      +pf = M.Parent.frame(parent)
      +data = output(Bool.or(G.successful(M.Frame.action(child)),G.reverted(M.Frame.action(child))),M.Frame.output(child))
      +copied = B.take(G.minimum(M.Parent.out_size(parent),B.len(data)),data)
      +pf = M.Frame.set_memory(M.Frame.set_ret(pf,data),Mem.write(M.Frame.memory(pf),M.Parent.out_offset(parent),copied))
      C.push(M.Frame.set_gas(pf,Nat.add(M.Frame.gas(pf),M.Frame.gas(child))),C.word(G.successful(M.Frame.action(child)),W.from_u32(1),W.zero()))

def merge(+e: M.Engine, +parent: M.Parent, parents: +List<M.Parent>) -> M.Machine:
  +child = M.Engine.frame(e)
  +success = G.successful(M.Frame.action(child))
  +frame = resume_frame(is_create(M.Parent.kind(parent)),parent,child)
  +resumed = {M.Engine{frame,world(success,M.Engine.world(e),M.Parent.snapshot(parent)),M.Engine.context(e),0n,W.add(M.Parent.state_used(parent),C.word(success,M.Engine.state_used(e),W.zero())),Nat.add(M.Parent.state_spilled(parent),C.nat(success,M.Engine.state_spilled(e),0n))} : M.Engine}
  +absorbed = G.absorb(resumed,M.Engine.reservoir(e))
  M.Machine{C.refund_if(Bool.and(Bool.not(success),U32.is_ne(U32.and(M.Parent.kind(parent),256),0)),absorbed),parents}

def finish_kind(creation: Bool, e: M.Engine, +parent: M.Parent, parents: +List<M.Parent>) -> M.Machine:
  match creation:
    case True{}: merge(G.settle(Create.finish(e,M.Parent.created_address(parent))),parent,parents)
    case False{}: merge(G.settle(e),parent,parents)

def unwind(e: M.Engine, parents: +List<M.Parent>) -> M.Machine:
  match parents:
    case Nil{}: M.Machine{e,Nil{}}
    case Con{+parent,rest}: finish_kind(is_create(M.Parent.kind(parent)),e,parent,rest)
