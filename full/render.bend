import Base
import ../evmword.bend as W
import ./model.bend as M
import ./memory.bend as Mem

# Tail-recursive append avoids JS call-stack growth for large rendered code.
def append(a: String, b: String) -> String:
  String.reverse.go(String.reverse(a), b)

def word(w: W.Word) -> String:
  match w:
    case W.W{a, b, c, d, e, f, g, h}:
      append("[", append(U32.show(a), append(",", append(U32.show(b), append(",", append(U32.show(c), append(",", append(U32.show(d), append(",", append(U32.show(e), append(",", append(U32.show(f), append(",", append(U32.show(g), append(",", append(U32.show(h), "]"))))))))))))))))

def bytes_rev(xs: +List<U32>, acc: String) -> String:
  match xs:
    case Nil{}: acc
    case Con{x, rest}: bytes_rev(rest, append(",", append(U32.show(x), acc)))

def bytes_tail(xs: +List<U32>) -> String:
  bytes_rev(List.reverse(&2, U32, xs), "")

def bytes(xs: +List<U32>) -> String:
  match xs:
    case Nil{}: "[]"
    case Con{x, rest}:
      append("[", append(U32.show(x), bytes_rev(List.reverse(&2, U32, rest), "]")))

def words_tail(xs: +List<W.Word>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      append(",", append(word(x), words_tail(rest)))

def words(xs: +List<W.Word>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      append("[", append(word(x), append(words_tail(rest), "]")))

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
      append("[", append(word(key), append(",", append(word(value), "]"))))

def slots_tail(xs: +List<M.Slot>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      append(",", append(slot(x), slots_tail(rest)))

def slots(xs: +List<M.Slot>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      append("[", append(slot(x), append(slots_tail(rest), "]")))

def account(+a: M.Account) -> String:
  append("{\"address\":", append(word(M.Account.address(a)), append(",\"balance\":", append(word(M.Account.balance(a)), append(",\"nonce\":", append(word(M.Account.nonce(a)), append(",\"code\":", append(bytes(M.Account.code(a)), append(",\"storage\":", append(slots(M.Account.storage(a)), append(",\"transient\":", append(slots(M.Account.transient(a)), append(",\"exists\":", append(boolean(M.Account.exists(a)), append(",\"created\":", append(boolean(M.Account.created(a)), append(",\"warm\":", append(boolean(M.Account.warm(a)), append(",\"warm_slots\":", append(words(M.Account.storage_warm(a)), "}"))))))))))))))))))))

def accounts_tail(xs: +List<M.Account>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      append(",", append(account(x), accounts_tail(rest)))

def accounts(xs: +List<M.Account>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      append("[", append(account(x), append(accounts_tail(rest), "]")))

def log(x: M.Log) -> String:
  match x:
    case M.Log{address, topics, data}:
      append("{\"address\":", append(word(address), append(",\"topics\":", append(words(topics), append(",\"data\":", append(bytes(data), "}"))))))

def logs_tail(xs: +List<M.Log>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      append(",", append(log(x), logs_tail(rest)))

def logs(xs: +List<M.Log>) -> String:
  match xs:
    case Nil{}:
      "[]"
    case Con{x, rest}:
      append("[", append(log(x), append(logs_tail(rest), "]")))

def frame_header(+f: M.Frame) -> String:
  append("{\"status\":\"", append(status(M.Frame.action(f)), append("\",\"reason\":", append(U32.show(reason(M.Frame.action(f))), append(",\"gas\":", append(Nat.show(M.Frame.gas(f)), append(",\"pc\":", Nat.show(M.Frame.pc(f)))))))))

def frame_data(+f: M.Frame) -> String:
  append(",\"stack\":", append(words(M.Frame.stack(f)), append(",\"memory\":", append(bytes(Mem.read(M.Frame.memory(f), 0n, Mem.size(M.Frame.memory(f)))), append(",\"output\":", bytes(M.Frame.output(f)))))))

def gas_data(+e: M.Engine) -> String:
  append(",\"reservoir\":", append(Nat.show(M.Engine.reservoir(e)), append(",\"state_used\":", append(word(M.Engine.state_used(e)), append(",\"state_spilled\":", Nat.show(M.Engine.state_spilled(e)))))))

def world_data(+world: M.World) -> String:
  append(",\"accounts\":", append(accounts(M.World.accounts(world)), append(",\"logs\":", append(logs(M.World.logs(world)), append(",\"refund\":", append(word(M.World.refund(world)), append(",\"selfdestructs\":", words(M.World.selfdestructs(world)))))))))

def engine(+e: M.Engine) -> String:
  append(frame_header(M.Engine.frame(e)), append(frame_data(M.Engine.frame(e)), append(gas_data(e), append(world_data(M.Engine.world(e)), "}"))))
