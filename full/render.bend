import Base
import ../evmword.bend as W
import ./model.bend as M
import ./memory.bend as Mem

def word(w: W.Word) -> String:
  match w:
    case W.W{a, b, c, d, e, f, g, h}:
      "[" ++ U32.show(a) ++ "," ++ U32.show(b) ++ "," ++ U32.show(c) ++ "," ++ U32.show(d) ++ "," ++ U32.show(e) ++ "," ++ U32.show(f) ++ "," ++ U32.show(g) ++ "," ++ U32.show(h) ++ "]"

def bytes_tail(xs: +List<U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      "," ++ U32.show(x) ++ bytes_tail(rest)

def bytes(xs: +List<U32>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      "[" ++ U32.show(x) ++ bytes_tail(rest) ++ "]"

def words_tail(xs: +List<W.Word>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      "," ++ word(x) ++ words_tail(rest)

def words(xs: +List<W.Word>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      "[" ++ word(x) ++ words_tail(rest) ++ "]"

def boolean(b: Bool) -> String:
  match b:
    case False{}:
      "false"
    case True{}:
      "true"

def status(action: M.Action) -> String:
  match action:
    case M.Running{}:
      "running"
    case M.Stopped{}:
      "success"
    case M.Returned{}:
      "success"
    case M.Reverted{}:
      "revert"
    case M.Fault{reason}:
      "halt"
    case M.HostLimit{}:
      "host_limit"
    case other:
      "pending"

def reason(action: M.Action) -> U32:
  match action:
    case M.Fault{r}:
      r
    case other:
      0

def slot(s: M.Slot) -> String:
  match s:
    case M.Slot{key, value}:
      "[" ++ word(key) ++ "," ++ word(value) ++ "]"

def slots_tail(xs: +List<M.Slot>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      "," ++ slot(x) ++ slots_tail(rest)

def slots(xs: +List<M.Slot>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      "[" ++ slot(x) ++ slots_tail(rest) ++ "]"

def account(+a: M.Account) -> String:
  "{\"address\":" ++ word(M.Account.address(a)) ++ ",\"balance\":" ++ word(M.Account.balance(a)) ++ ",\"nonce\":" ++ word(M.Account.nonce(a)) ++ ",\"code\":" ++ bytes(M.Account.code(a)) ++ ",\"storage\":" ++ slots(M.Account.storage(a)) ++ ",\"transient\":" ++ slots(M.Account.transient(a)) ++ ",\"exists\":" ++ boolean(M.Account.exists(a)) ++ ",\"created\":" ++ boolean(M.Account.created(a)) ++ ",\"warm\":" ++ boolean(M.Account.warm(a)) ++ ",\"warm_slots\":" ++ words(M.Account.storage_warm(a)) ++ "}"

def accounts_tail(xs: +List<M.Account>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      "," ++ account(x) ++ accounts_tail(rest)

def accounts(xs: +List<M.Account>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      "[" ++ account(x) ++ accounts_tail(rest) ++ "]"

def log(x: M.Log) -> String:
  match x:
    case M.Log{address, topics, data}:
      "{\"address\":" ++ word(address) ++ ",\"topics\":" ++ words(topics) ++ ",\"data\":" ++ bytes(data) ++ "}"

def logs_tail(xs: +List<M.Log>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      "," ++ log(x) ++ logs_tail(rest)

def logs(xs: +List<M.Log>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      "[" ++ log(x) ++ logs_tail(rest) ++ "]"

def frame_header(+f: M.Frame) -> String:
  "{\"status\":\"" ++ status(M.Frame.action(f)) ++ "\",\"reason\":" ++ U32.show(reason(M.Frame.action(f))) ++ ",\"gas\":" ++ Nat.show(M.Frame.gas(f)) ++ ",\"pc\":" ++ Nat.show(M.Frame.pc(f))

def frame_data(+f: M.Frame) -> String:
  ",\"stack\":" ++ words(M.Frame.stack(f)) ++ ",\"memory\":" ++ bytes(Mem.read(M.Frame.memory(f), 0n, Mem.size(M.Frame.memory(f)))) ++ ",\"output\":" ++ bytes(M.Frame.output(f))

def gas_data(+e: M.Engine) -> String:
  ",\"reservoir\":" ++ Nat.show(M.Engine.reservoir(e)) ++ ",\"state_used\":" ++ word(M.Engine.state_used(e)) ++ ",\"state_spilled\":" ++ Nat.show(M.Engine.state_spilled(e))

def world_data(+world: M.World) -> String:
  ",\"accounts\":" ++ accounts(M.World.accounts(world)) ++ ",\"logs\":" ++ logs(M.World.logs(world)) ++ ",\"refund\":" ++ word(M.World.refund(world)) ++ ",\"selfdestructs\":" ++ words(M.World.selfdestructs(world))

def engine(+e: M.Engine) -> String:
  frame_header(M.Engine.frame(e)) ++ frame_data(M.Engine.frame(e)) ++ gas_data(e) ++ world_data(M.Engine.world(e)) ++ "}"
