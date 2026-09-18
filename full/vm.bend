import Base
import ../evmword.bend as W
import ./model.bend as M
import ./bytes.bend as B
import ./opcodes.bend as Opcodes
import ./state-ops.bend as State
import ./call-enter.bend as Call
import ./create-enter.bend as Create
import ./call-finish.bend as Finish
import ./call-selfdestruct.bend as Destroy

# One transition; the host runner supplies fuel and precompile IO.
def state_opcode(+op: U32) -> Bool:
  match op:
    case 49: True{}
    case 59: True{}
    case 60: True{}
    case 63: True{}
    case 71: True{}
    case 84: True{}
    case 85: True{}
    case 92: True{}
    case 93: True{}
    case other: Bool.and(U32.is_ge(other,160),U32.is_le(other,164))

def execute_state(state: Bool, +e: M.Engine) -> M.Engine:
  match state:
    case True{}: State.step(e)
    case False{}: M.Engine.set_frame(e,Opcodes.step(M.Engine.frame(e),M.Engine.context(e)))

def execute(+e: M.Engine) -> M.Engine:
  execute_state(state_opcode(B.get(M.Frame.pc(M.Engine.frame(e)),M.Frame.code(M.Engine.frame(e)))),e)

def action(action: M.Action, e: M.Engine, parents: +List<M.Parent>) -> M.Machine:
  match action:
    case M.Running{}: M.Machine{execute(e),parents}
    case M.Call{kind,gas,target,value,in_offset,in_size,out_offset,out_size}:
      Call.start(e,parents,kind,gas,target,value,in_offset,in_size,out_offset,out_size)
    case M.Create{kind,value,offset,size,salt}:
      Create.start(e,parents,kind,value,offset,size,salt)
    case M.SelfDestruct{target}: M.Machine{Destroy.start(e,target),parents}
    case M.Precompile{address}: M.Machine{e,parents}
    case M.HostLimit{}: M.Machine{e,parents}
    case terminal: Finish.unwind(e,parents)

def step(machine: M.Machine) -> M.Machine:
  match machine:
    case M.Machine{+engine,parents}: action(M.Frame.action(M.Engine.frame(engine)),engine,parents)

def terminal(action: M.Action) -> Bool:
  match action:
    case M.Running{}: False{}
    case M.Call{kind,gas,target,value,in_offset,in_size,out_offset,out_size}: False{}
    case M.Create{kind,value,offset,size,salt}: False{}
    case M.SelfDestruct{target}: False{}
    case M.Precompile{address}: False{}
    case other: True{}

def finished(machine: M.Machine) -> Bool:
  match machine:
    case M.Machine{engine,parents}:
      match parents:
        case Nil{}: terminal(M.Frame.action(M.Engine.frame(engine)))
        case Con{parent,rest}: False{}

def initial(frame: M.Frame, world: M.World, context: M.Context, reservoir: Nat) -> M.Machine:
  M.Machine{M.Engine{frame,world,context,reservoir,W.zero(),0n},Nil{}}
