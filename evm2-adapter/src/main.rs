use alloy_primitives::{Address, B256, Log};
use evm2::{
    BaseEvmConfigSelector, EvmFeatures, EvmTypesHost, ExecutionConfig, SpecId,
    bytecode::Bytecode,
    env::{BlockEnv, TxEnv},
    evm::{AccountLoad, SLoad, SStore, SelfDestructResult},
    interpreter::{Host, InstrStop, Interpreter, Message, MessageResult, Word},
};
use serde::Deserialize;
use serde_json::{Value, json};
use std::io::{self, BufRead};

#[derive(Clone, Copy, Debug)]
struct Types;
impl EvmTypesHost for Types {
    type ConfigSelector = BaseEvmConfigSelector;
    type SpecId = SpecId;
    type Tx = ();
    type EvmExt = ();
    type MessageExt = ();
    type MessageResultExt = ();
    type TxEnvExt = ();
    type TxResultExt = ();
    type BlockEnvExt = ();
    type Host<'a> = NoHost;
}
#[derive(Debug, Default)]
struct NoHost {
    block: BlockEnv<Types>,
    used: bool,
}
impl NoHost {
    fn unsupported<T>(&mut self) -> Result<T, InstrStop> {
        self.used = true;
        Err(InstrStop::FatalExternalError)
    }
}
impl Host<Types> for NoHost {
    fn spec_id(&self) -> SpecId {
        SpecId::SHANGHAI
    }
    fn block_env(&mut self) -> &BlockEnv<Types> {
        self.used = true;
        &self.block
    }
    fn load_account(&mut self, _: &Address, _: bool, _: bool) -> Result<AccountLoad, InstrStop> {
        self.unsupported()
    }
    fn target_is_empty_for_new_account_gas(
        &mut self,
        _: &Address,
        _: EvmFeatures,
    ) -> Result<bool, InstrStop> {
        self.unsupported()
    }
    fn block_hash(&mut self, _: &Word) -> Result<B256, InstrStop> {
        self.unsupported()
    }
    fn sload(&mut self, _: &Address, _: &Word, _: bool) -> Result<SLoad, InstrStop> {
        self.unsupported()
    }
    fn sstore(&mut self, _: &Address, _: &Word, _: &Word, _: bool) -> Result<SStore, InstrStop> {
        self.unsupported()
    }
    fn tload(&mut self, _: &Address, _: &Word) -> Word {
        self.used = true;
        Word::ZERO
    }
    fn tstore(&mut self, _: &Address, _: &Word, _: &Word) {
        self.used = true;
    }
    fn log(&mut self, _: Log) {
        self.used = true;
    }
    fn execute_message(
        &mut self,
        _: &TxEnv<Types>,
        _: &mut Message<Types>,
    ) -> MessageResult<Types> {
        self.used = true;
        MessageResult::<Types> {
            stop: InstrStop::FatalExternalError,
            ..Default::default()
        }
    }
    fn selfdestruct(
        &mut self,
        _: &Address,
        _: &Address,
        _: bool,
    ) -> Result<SelfDestructResult, InstrStop> {
        self.unsupported()
    }
}
struct Observer;
impl evm2::inspector::Inspector<Types> for Observer {}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Input {
    code: Vec<u8>,
    gas: u64,
}
fn run(input: Input) -> Value {
    let tx = TxEnv::<Types>::default();
    let message = Message::<Types> {
        code: Bytecode::new_legacy(input.code.into()),
        gas_limit: input.gas,
        ..Default::default()
    };
    let config = ExecutionConfig::<Types>::for_spec_and_version(
        SpecId::SHANGHAI,
        evm2::Version::new(SpecId::SHANGHAI),
    );
    let mut host = NoHost::default();
    let mut interp = Interpreter::<Types>::new(&tx, &message);
    let stop = interp.run_inspect(&config, &mut host, &mut Observer);
    if host.used {
        return json!({"error":"unsupported_host_operation"});
    }
    let mut gas = *interp.gas().tracker();
    gas.settle_gas(stop);
    let stack: Vec<String> = interp
        .stack()
        .as_slice()
        .iter()
        .rev()
        .map(|word| format!("{word:#x}"))
        .collect();
    let status = match stop {
        InstrStop::Stop | InstrStop::Return | InstrStop::SelfDestruct => "halted".to_owned(),
        InstrStop::StackUnderflow => "underflow".to_owned(),
        InstrStop::StackOverflow => "overflow".to_owned(),
        InstrStop::InvalidOpcode | InstrStop::NotActivated => "invalid".to_owned(),
        reason if reason.is_out_of_gas() => "out_of_gas".to_owned(),
        reason => format!("{reason:?}"),
    };
    json!({"status":status, "gas":gas.remaining(), "pc":interp.pc(), "stack":stack})
}
fn main() {
    for line in io::stdin().lock().lines() {
        let response = match line {
            Ok(line) => match serde_json::from_str::<Input>(&line) {
                Ok(input) => run(input),
                Err(e) => json!({"error":"invalid_input", "detail":e.to_string()}),
            },
            Err(e) => {
                eprintln!("stdin: {e}");
                break;
            }
        };
        println!("{response}");
    }
}
