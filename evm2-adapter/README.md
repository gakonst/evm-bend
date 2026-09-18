# evm2 raw Shanghai frame adapter

Build with `~/.cargo/bin/cargo build --manifest-path evm2-adapter/Cargo.toml` from the parent directory. Run `evm2-adapter/target/debug/evm2-frame-adapter`.

One JSON object per stdin line: `{"code":[96,2,96,3,1,0],"gas":100}`.
One JSON object per stdout line: `{"status":"halted","gas":91,"pc":5,"stack":["0x5"]}`.

`stack` is **top first**, each word an unsigned `0x` hexadecimal string (not a JSON number, preserving all 256 bits). `pc` is the terminal opcode byte offset in analyzed code, which may be past original bytes for truncated PUSH. `status` normalizes Stop/Return/SelfDestruct to `halted`, StackUnderflow to `underflow`, StackOverflow to `overflow`, InvalidOpcode/NotActivated to `invalid`, and out-of-gas variants to `out_of_gas`; other outcomes retain evm2 variant spelling (e.g. Revert, InvalidJump). `gas` is settled frame gas: exceptional halts consume all gas, whereas Stop/Return/Revert preserve remaining gas. The stack is evm2's post-instruction/debug observable stack, including on errors; it is not a committed transaction output.

Shanghai is pinned via `Version::new(SpecId::SHANGHAI)`. Frames begin with empty stack, zero/default transaction and message context, empty memory, and exactly the requested gas (no intrinsic charge). An empty inspector preserves terminal PC. Host-dependent actions return `{"error":"unsupported_host_operation"}`; no fake state oracle is provided. Malformed input returns `{"error":"invalid_input","detail":"..."}`. This is a raw frame/subset comparison adapter, not a full transaction oracle. No JIT/LLVM dependency or reference-checkout modification is required. Cargo.lock pins resolved dependencies.

The runner executes until EVM termination; bound gas and code size in callers. Diagnostics go to stderr. Only result JSON goes to stdout.

No static filtering of bytecode is performed: unsupported bytes within PUSH immediates never cause rejection. Host-operation rejection occurs only when a host method actually executes. The parent decides which Bend NotImplemented executions are outside its implemented subset. Terminal PC is the inspector-preserved evm2 PC without additional normalization.
