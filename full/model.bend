import Base
import ../evmword.bend as W
import ./memory.bend as Mem

type Slot is Data:
  Slot{key: W.Word, value: W.Word}

type Log is Data:
  Log{address: W.Word, topics: +List<W.Word>, data: +List<U32>}

type BlockHash is Data:
  BH{number: W.Word, hash: W.Word}

# Action is explicit: the runner alone enters/unwinds child frames.
type Action is Data:
  Running{}
  Stopped{}
  Returned{}
  Reverted{}
  Fault{reason: U32}
  Call{kind: U32, gas: W.Word, target: W.Word, value: W.Word, in_offset: W.Word, in_size: W.Word, out_offset: W.Word, out_size: W.Word}
  Create{kind: U32, value: W.Word, offset: W.Word, size: W.Word, salt: W.Word}
  SelfDestruct{target: W.Word}
  Precompile{address: U32}
  HostLimit{}

type Context is Data:
  Ctx{origin: W.Word, gasprice: W.Word, coinbase: W.Word, timestamp: W.Word, number: W.Word, prevrandao: W.Word, gaslimit: W.Word, chainid: W.Word, basefee: W.Word, blobbasefee: W.Word, slotnum: W.Word, blobhashes: +List<W.Word>, blockhashes: +List<BlockHash>}

def Context.origin(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      origin

def Context.set_origin(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{new, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.gasprice(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      gasprice

def Context.set_gasprice(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, new, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.coinbase(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      coinbase

def Context.set_coinbase(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, new, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.timestamp(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      timestamp

def Context.set_timestamp(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, new, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.number(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      number

def Context.set_number(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, new, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.prevrandao(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      prevrandao

def Context.set_prevrandao(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, new, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.gaslimit(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      gaslimit

def Context.set_gaslimit(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, new, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.chainid(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      chainid

def Context.set_chainid(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, new, basefee, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.basefee(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      basefee

def Context.set_basefee(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, new, blobbasefee, slotnum, blobhashes, blockhashes}

def Context.blobbasefee(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      blobbasefee

def Context.set_blobbasefee(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, new, slotnum, blobhashes, blockhashes}

def Context.slotnum(x: Context) -> W.Word:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      slotnum

def Context.set_slotnum(x: Context, new: W.Word) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, new, blobhashes, blockhashes}

def Context.blobhashes(x: Context) -> +List<W.Word>:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      blobhashes

def Context.set_blobhashes(x: Context, new: +List<W.Word>) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, new, blockhashes}

def Context.blockhashes(x: Context) -> +List<BlockHash>:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      blockhashes

def Context.set_blockhashes(x: Context, new: +List<BlockHash>) -> Context:
  match x:
    case Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, blockhashes}:
      Ctx{origin, gasprice, coinbase, timestamp, number, prevrandao, gaslimit, chainid, basefee, blobbasefee, slotnum, blobhashes, new}

type Account is Data:
  Account{address: W.Word, balance: W.Word, nonce: W.Word, code: +List<U32>, storage: +List<Slot>, original: +List<Slot>, transient: +List<Slot>, warm: Bool, exists: Bool, created: Bool, storage_warm: +List<W.Word>}

def Account.address(x: Account) -> W.Word:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      address

def Account.set_address(x: Account, new: W.Word) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{new, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}

def Account.balance(x: Account) -> W.Word:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      balance

def Account.set_balance(x: Account, new: W.Word) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, new, nonce, code, storage, original, transient, warm, exists, created, storage_warm}

def Account.nonce(x: Account) -> W.Word:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      nonce

def Account.set_nonce(x: Account, new: W.Word) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, new, code, storage, original, transient, warm, exists, created, storage_warm}

def Account.code(x: Account) -> +List<U32>:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      code

def Account.set_code(x: Account, new: +List<U32>) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, new, storage, original, transient, warm, exists, created, storage_warm}

def Account.storage(x: Account) -> +List<Slot>:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      storage

def Account.set_storage(x: Account, new: +List<Slot>) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, code, new, original, transient, warm, exists, created, storage_warm}

def Account.original(x: Account) -> +List<Slot>:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      original

def Account.set_original(x: Account, new: +List<Slot>) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, code, storage, new, transient, warm, exists, created, storage_warm}

def Account.transient(x: Account) -> +List<Slot>:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      transient

def Account.set_transient(x: Account, new: +List<Slot>) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, code, storage, original, new, warm, exists, created, storage_warm}

def Account.warm(x: Account) -> Bool:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      warm

def Account.set_warm(x: Account, new: Bool) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, code, storage, original, transient, new, exists, created, storage_warm}

def Account.exists(x: Account) -> Bool:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      exists

def Account.set_exists(x: Account, new: Bool) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, code, storage, original, transient, warm, new, created, storage_warm}

def Account.created(x: Account) -> Bool:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      created

def Account.set_created(x: Account, new: Bool) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, code, storage, original, transient, warm, exists, new, storage_warm}

def Account.storage_warm(x: Account) -> +List<W.Word>:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      storage_warm

def Account.set_storage_warm(x: Account, new: +List<W.Word>) -> Account:
  match x:
    case Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, storage_warm}:
      Account{address, balance, nonce, code, storage, original, transient, warm, exists, created, new}

type World is Data:
  World{accounts: +List<Account>, logs: +List<Log>, refund: W.Word, selfdestructs: +List<W.Word>}

def World.accounts(x: World) -> +List<Account>:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      accounts

def World.set_accounts(x: World, new: +List<Account>) -> World:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      World{new, logs, refund, selfdestructs}

def World.logs(x: World) -> +List<Log>:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      logs

def World.set_logs(x: World, new: +List<Log>) -> World:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      World{accounts, new, refund, selfdestructs}

def World.refund(x: World) -> W.Word:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      refund

def World.set_refund(x: World, new: W.Word) -> World:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      World{accounts, logs, new, selfdestructs}

def World.selfdestructs(x: World) -> +List<W.Word>:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      selfdestructs

def World.set_selfdestructs(x: World, new: +List<W.Word>) -> World:
  match x:
    case World{accounts, logs, refund, selfdestructs}:
      World{accounts, logs, refund, new}

type Frame is Data:
  Frame{gas: Nat, pc: Nat, stack: +List<W.Word>, memory: Mem.Mem, code: +List<U32>, input: +List<U32>, ret: +List<U32>, address: W.Word, caller: W.Word, value: W.Word, is_static: Bool, depth: Nat, action: Action, output: +List<U32>}

def Frame.gas(x: Frame) -> Nat:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      gas

def Frame.set_gas(x: Frame, new: Nat) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{new, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}

def Frame.pc(x: Frame) -> Nat:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      pc

def Frame.set_pc(x: Frame, new: Nat) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, new, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}

def Frame.stack(x: Frame) -> +List<W.Word>:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      stack

def Frame.set_stack(x: Frame, new: +List<W.Word>) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, new, memory, code, input, ret, address, caller, value, is_static, depth, action, output}

def Frame.memory(x: Frame) -> Mem.Mem:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      memory

def Frame.set_memory(x: Frame, new: Mem.Mem) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, new, code, input, ret, address, caller, value, is_static, depth, action, output}

def Frame.code(x: Frame) -> +List<U32>:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      code

def Frame.set_code(x: Frame, new: +List<U32>) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, new, input, ret, address, caller, value, is_static, depth, action, output}

def Frame.input(x: Frame) -> +List<U32>:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      input

def Frame.set_input(x: Frame, new: +List<U32>) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, new, ret, address, caller, value, is_static, depth, action, output}

def Frame.ret(x: Frame) -> +List<U32>:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      ret

def Frame.set_ret(x: Frame, new: +List<U32>) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, new, address, caller, value, is_static, depth, action, output}

def Frame.address(x: Frame) -> W.Word:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      address

def Frame.set_address(x: Frame, new: W.Word) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, ret, new, caller, value, is_static, depth, action, output}

def Frame.caller(x: Frame) -> W.Word:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      caller

def Frame.set_caller(x: Frame, new: W.Word) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, ret, address, new, value, is_static, depth, action, output}

def Frame.value(x: Frame) -> W.Word:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      value

def Frame.set_value(x: Frame, new: W.Word) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, ret, address, caller, new, is_static, depth, action, output}

def Frame.is_static(x: Frame) -> Bool:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      is_static

def Frame.set_is_static(x: Frame, new: Bool) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, new, depth, action, output}

def Frame.depth(x: Frame) -> Nat:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      depth

def Frame.set_depth(x: Frame, new: Nat) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, new, action, output}

def Frame.action(x: Frame) -> Action:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      action

def Frame.set_action(x: Frame, new: Action) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, new, output}

def Frame.output(x: Frame) -> +List<U32>:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      output

def Frame.set_output(x: Frame, new: +List<U32>) -> Frame:
  match x:
    case Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, output}:
      Frame{gas, pc, stack, memory, code, input, ret, address, caller, value, is_static, depth, action, new}

type Engine is Data:
  Engine{frame: Frame, world: World, context: Context, reservoir: Nat, state_used: W.Word, state_spilled: Nat}

def Engine.frame(x: Engine) -> Frame:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      frame

def Engine.set_frame(x: Engine, new: Frame) -> Engine:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      Engine{new, world, context, reservoir, state_used, state_spilled}

def Engine.world(x: Engine) -> World:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      world

def Engine.set_world(x: Engine, new: World) -> Engine:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      Engine{frame, new, context, reservoir, state_used, state_spilled}

def Engine.context(x: Engine) -> Context:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      context

def Engine.set_context(x: Engine, new: Context) -> Engine:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      Engine{frame, world, new, reservoir, state_used, state_spilled}

def Engine.reservoir(x: Engine) -> Nat:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      reservoir

def Engine.set_reservoir(x: Engine, new: Nat) -> Engine:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      Engine{frame, world, context, new, state_used, state_spilled}

def Engine.state_used(x: Engine) -> W.Word:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      state_used

def Engine.set_state_used(x: Engine, new: W.Word) -> Engine:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      Engine{frame, world, context, reservoir, new, state_spilled}

def Engine.state_spilled(x: Engine) -> Nat:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      state_spilled

def Engine.set_state_spilled(x: Engine, new: Nat) -> Engine:
  match x:
    case Engine{frame, world, context, reservoir, state_used, state_spilled}:
      Engine{frame, world, context, reservoir, state_used, new}

type Parent is Data:
  Parent{frame: Frame, snapshot: World, kind: U32, out_offset: Nat, out_size: Nat, created_address: W.Word, state_used: W.Word, state_spilled: Nat}

def Parent.frame(x: Parent) -> Frame:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      frame

def Parent.set_frame(x: Parent, new: Frame) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{new, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}

def Parent.snapshot(x: Parent) -> World:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      snapshot

def Parent.set_snapshot(x: Parent, new: World) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{frame, new, kind, out_offset, out_size, created_address, state_used, state_spilled}

def Parent.kind(x: Parent) -> U32:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      kind

def Parent.set_kind(x: Parent, new: U32) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{frame, snapshot, new, out_offset, out_size, created_address, state_used, state_spilled}

def Parent.out_offset(x: Parent) -> Nat:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      out_offset

def Parent.set_out_offset(x: Parent, new: Nat) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{frame, snapshot, kind, new, out_size, created_address, state_used, state_spilled}

def Parent.out_size(x: Parent) -> Nat:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      out_size

def Parent.set_out_size(x: Parent, new: Nat) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{frame, snapshot, kind, out_offset, new, created_address, state_used, state_spilled}

def Parent.created_address(x: Parent) -> W.Word:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      created_address

def Parent.set_created_address(x: Parent, new: W.Word) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{frame, snapshot, kind, out_offset, out_size, new, state_used, state_spilled}

def Parent.state_used(x: Parent) -> W.Word:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      state_used

def Parent.set_state_used(x: Parent, new: W.Word) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{frame, snapshot, kind, out_offset, out_size, created_address, new, state_spilled}

def Parent.state_spilled(x: Parent) -> Nat:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      state_spilled

def Parent.set_state_spilled(x: Parent, new: Nat) -> Parent:
  match x:
    case Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, state_spilled}:
      Parent{frame, snapshot, kind, out_offset, out_size, created_address, state_used, new}

type Machine is Data:
  Machine{engine: Engine, parents: +List<Parent>}

def Machine.engine(x: Machine) -> Engine:
  match x:
    case Machine{engine, parents}:
      engine

def Machine.set_engine(x: Machine, new: Engine) -> Machine:
  match x:
    case Machine{engine, parents}:
      Machine{new, parents}

def Machine.parents(x: Machine) -> +List<Parent>:
  match x:
    case Machine{engine, parents}:
      parents

def Machine.set_parents(x: Machine, new: +List<Parent>) -> Machine:
  match x:
    case Machine{engine, parents}:
      Machine{engine, new}

def default_context() -> Context:
  Ctx{W.zero(), W.zero(), W.zero(), W.zero(), W.zero(), W.zero(), W.from_u32(16777216), W.from_u32(1), W.zero(), W.zero(), W.zero(), Nil{}, Nil{}}

def empty_world() -> World:
  World{Nil{}, Nil{}, W.zero(), Nil{}}

def empty_account(address: W.Word) -> Account:
  Account{address, W.zero(), W.zero(), Nil{}, Nil{}, Nil{}, Nil{}, False{}, False{}, False{}, Nil{}}

def initial_frame(code: +List<U32>, gas: Nat, input: +List<U32>, address: W.Word, caller: W.Word, value: W.Word) -> Frame:
  Frame{gas, 0n, Nil{}, Mem.empty(), code, input, Nil{}, address, caller, value, False{}, 0n, Running{}, Nil{}}

# Fault codes: 1 OOG, 2 stack underflow, 3 overflow, 4 invalid opcode,
# 5 invalid jump, 6 static violation, 7 return-data bounds, 8 invalid immediate.
def fault(f: Frame, reason: U32) -> Frame:
  Frame.set_action(Frame.set_output(Frame.set_gas(f, 0n), Nil{}), Fault{reason})
