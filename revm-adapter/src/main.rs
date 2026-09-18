mod commitment;
mod authorization_crypto;
mod fixture;
use revm::{
    ExecuteEvm, MainBuilder, MainContext,
    context::{BlockEnv, CfgEnv, Context, TxEnv},
    database::InMemoryDB,
    primitives::{Address, B256, TxKind, U256, hardfork::SpecId},
    state::{AccountInfo, Bytecode},
};
use serde::Deserialize;
use serde_json::{Value, json};
use std::{
    collections::BTreeMap,
    io::{self, BufRead},
    str::FromStr,
};
// Checked wider arithmetic avoids overflow in REVM's u128 Taylor intermediates.
fn blob_price_wide(excess:u64,denominator:u64)->Result<u128,String>{
 let den=U256::from(denominator);let mut acc=den;let mut out=U256::ZERO;let mut i=1u64;
 while !acc.is_zero(){
  out=out.checked_add(acc).ok_or("blob-price intermediate overflow")?;
  if out/den>U256::from(u128::MAX){return Err("blob price exceeds oracle u128 representation".into())}
  acc=acc.checked_mul(U256::from(excess)).ok_or("blob-price product overflow")?/(den*U256::from(i));i+=1;
 }
 (out/den).try_into().map_err(|_|"blob price exceeds oracle u128 representation".into())
}
fn quantity<'de, D: serde::Deserializer<'de>>(d: D) -> Result<U256, D::Error> {
    let v = Value::deserialize(d)?;
    match v {
        Value::Number(n) => n
            .as_u64()
            .map(U256::from)
            .ok_or_else(|| serde::de::Error::custom("invalid quantity")),
        Value::String(s) => uint(&s).map_err(serde::de::Error::custom),
        _ => Err(serde::de::Error::custom("invalid quantity")),
    }
}
fn one() -> u64 {
    1
}
fn gas() -> u64 {
    1_000_000
}
fn block_gas() -> u64 {
    30_000_000
}
fn zero() -> String {
    "0x0".into()
}
fn caller() -> String {
    format!("0x{:040x}", 0x1000)
}
fn target() -> String {
    format!("0x{:040x}", 0x2000)
}
fn fork() -> String {
    "amsterdam".into()
}
fn mode() -> String {
    "transaction".into()
}
#[derive(Deserialize, Default)]
#[serde(default)]
struct Account {
    address: String,
    balance: Option<String>,
    nonce: u64,
    code: Vec<u8>,
    storage: Vec<(String, String)>,
}
#[derive(Deserialize)]
#[serde(default)]
struct Block {
    #[serde(deserialize_with = "quantity")]
    number: U256,
    #[serde(deserialize_with = "quantity")]
    timestamp: U256,
    difficulty: U256,
    slot_num: u64,
    excess_blob_gas: u64,
    blob_gasprice: Option<u128>,
    gas_limit: u64,
    basefee: u64,
    beneficiary: String,
    prevrandao: String,
}
impl Default for Block {
    fn default() -> Self {
        Self {
            number: U256::ZERO,
            timestamp: U256::ZERO,
            difficulty: U256::ZERO,
            slot_num: 0,
            excess_blob_gas: 0,
            blob_gasprice: None,
            gas_limit: block_gas(),
            basefee: 0,
            beneficiary: format!("0x{:040x}", 0),
            prevrandao: format!("0x{:064x}", 0),
        }
    }
}
#[derive(Deserialize)]
struct Input {
    #[serde(default = "mode")]
    mode: String,
    #[serde(default = "fork")]
    fork: String,
    #[serde(default)]
    code: Option<Vec<u8>>,
    #[serde(default = "gas")]
    gas: u64,
    #[serde(default)]
    calldata: Vec<u8>,
    #[serde(default = "caller")]
    caller: String,
    #[serde(default = "target")]
    target: String,
    #[serde(default = "zero")]
    value: String,
    #[serde(default)]
    nonce: u64,
    #[serde(default)]
    gas_price: u128,
    #[serde(default)]
    tx_type: u8,
    #[serde(default)]
    create: bool,
    #[serde(default)]
    chain_id: Option<u64>,
    #[serde(default = "one")]
    cfg_chain_id: u64,
    #[serde(default)]
    max_fee_per_gas: Option<u128>,
    #[serde(default)]
    max_priority_fee_per_gas: Option<u128>,
    #[serde(default)]
    access_list: revm::context_interface::transaction::AccessList,
    #[serde(default, alias = "blob_versioned_hashes")]
    blob_hashes: Vec<B256>,
    #[serde(default)]
    max_fee_per_blob_gas: u128,
    #[serde(default)]
    authorization_list: Vec<revm::context_interface::transaction::SignedAuthorization>,
    #[serde(default)]
    block_hashes: BTreeMap<u64, B256>,
    #[serde(default)]
    strict: bool,
    #[serde(default)]
    accounts: Vec<Account>,
    #[serde(default)]
    block: Block,
}
fn uint(s: &str) -> Result<U256, String> {
    U256::from_str(s).map_err(|e| format!("invalid integer {s}: {e}"))
}
fn addr(s: &str) -> Result<Address, String> {
    Address::from_str(s).map_err(|e| format!("invalid address {s}: {e}"))
}
fn rejected(fork: &str, reason: String) -> Value {
    json!({"mode":"transaction","fork":fork,"status":"rejected","reason":reason,"gas_used":0,"output":[],"logs":[],"state":{"accounts":[],"storage":[]}})
}
fn run(i: Input) -> Result<Value, String> {
    if i.mode != "transaction" {
        return Err("only transaction mode is supported".into());
    }
    let spec = match i.fork.as_str() {
        "amsterdam" => SpecId::AMSTERDAM,
        "shanghai" => SpecId::SHANGHAI,
        _ => return Err("unsupported fork".into()),
    };
    let caller = addr(&i.caller)?;
    let target = addr(&i.target)?;
    let mut initial = BTreeMap::new();
    let mut storage = BTreeMap::new();
    for a in i.accounts {
        let address = addr(&a.address)?;
        if initial.contains_key(&address) {
            return Err("duplicate account address".into());
        }
        let code = Bytecode::new_raw_checked(a.code.into())
            .map_err(|e| format!("invalid account bytecode: {e:?}"))?;
        initial.insert(
            address,
            AccountInfo {
                balance: uint(a.balance.as_deref().unwrap_or("0x0"))?,
                nonce: a.nonce,
                code_hash: code.hash_slow(),
                code: Some(code),
                ..Default::default()
            },
        );
        for (k, v) in a.storage {
            if storage.insert((address, uint(&k)?), uint(&v)?).is_some() {
                return Err("duplicate storage key".into());
            }
        }
    }
    if !i.strict {
        initial.entry(caller).or_insert_with(|| AccountInfo {
            balance: U256::from(10u64).pow(U256::from(30)),
            ..Default::default()
        });
    }
    if let Some(bytes) = i.code {
        let code = Bytecode::new_legacy(bytes.into());
        let a = initial.entry(target).or_default();
        a.code_hash = code.hash_slow();
        a.code = Some(code);
    }
    let mut db = InMemoryDB::default();
    for (address, info) in &initial {
        db.insert_account_info(*address, info.clone());
    }
    for ((address, key), value) in &storage {
        db.insert_account_storage(*address, *key, *value)
            .map_err(|e| format!("{e:?}"))?;
    }
    let mut cfg = CfgEnv::new();
    cfg.set_spec_and_mainnet_gas_params(spec);
    cfg.chain_id = i.cfg_chain_id;
    if !i.strict {
        cfg = cfg.disable_tx_chain_id_check();
    }
    for (n, h) in i.block_hashes {
        db.cache.block_hashes.insert(U256::from(n), h);
    }
    let mut committed = db.clone();
    let mut blob = if spec == SpecId::AMSTERDAM {
        revm::context_interface::block::BlobExcessGasAndPrice { excess_blob_gas:i.block.excess_blob_gas, blob_gasprice:blob_price_wide(i.block.excess_blob_gas,11_684_671)? }
    } else {
        revm::context_interface::block::BlobExcessGasAndPrice::new_with_spec(
            i.block.excess_blob_gas,
            spec,
        )
    };
    if let Some(price) = i.block.blob_gasprice {
        blob.blob_gasprice = price;
    }
    let block = BlockEnv {
        difficulty: i.block.difficulty,
        slot_num: i.block.slot_num,
        blob_excess_gas_and_price: Some(blob),
        number: U256::from(i.block.number),
        timestamp: U256::from(i.block.timestamp),
        gas_limit: i.block.gas_limit,
        basefee: i.block.basefee,
        beneficiary: addr(&i.block.beneficiary)?,
        prevrandao: Some(B256::from_str(&i.block.prevrandao).map_err(|e| e.to_string())?),
        ..Default::default()
    };
    let mut evm = Context::mainnet()
        .with_cfg(cfg)
        .with_block(block)
        .with_db(db)
        .build_mainnet();
    let tx = TxEnv {
        tx_type: i.tx_type,
        caller,
        kind: if i.create {
            TxKind::Create
        } else {
            TxKind::Call(target)
        },
        gas_limit: i.gas,
        gas_price: i.max_fee_per_gas.unwrap_or(i.gas_price),
        value: uint(&i.value)?,
        data: i.calldata.into(),
        nonce: i.nonce,
        chain_id: i.chain_id,
        gas_priority_fee: i.max_priority_fee_per_gas,
        access_list: i.access_list,
        blob_hashes: i.blob_hashes,
        max_fee_per_blob_gas: i.max_fee_per_blob_gas,
        authorization_list: i
            .authorization_list
            .into_iter()
            .map(revm::context_interface::either::Either::Left)
            .collect(),
    };
    let executed = evm.transact(tx).map_err(|e| format!("{e:?}"))?;
    revm::DatabaseCommit::commit(&mut committed, executed.state.clone());
    for (address, a) in &executed.state {
        if a.is_touched() && a.info.is_empty() {
            committed.cache.accounts.remove(address);
        }
    }
    let mut post_allocation = Vec::new();
    let ordered: BTreeMap<_, _> = committed.cache.accounts.iter().collect();
    for (address, a) in ordered {
        if a.info().is_none() {
            continue;
        }
        let code = committed
            .cache
            .contracts
            .get(&a.info.code_hash)
            .ok_or("missing committed bytecode")?;
        let slots: BTreeMap<_, _> = a.storage.iter().filter(|(_, v)| !v.is_zero()).collect();
        post_allocation.push(json!({"address":format!("{address:#x}"),"balance":format!("{:#x}",a.info.balance),"nonce":a.info.nonce,"code":code.original_bytes().to_vec(),"storage":slots.into_iter().map(|(k,v)|(format!("{k:#x}"),format!("{v:#x}"))).collect::<Vec<_>>()}));
    }
    let result = executed.result;
    let (status, reason) = match &result {
        revm::context_interface::result::ExecutionResult::Success { reason, .. } => {
            ("halted", format!("{reason:?}"))
        }
        revm::context_interface::result::ExecutionResult::Revert { .. } => {
            ("revert", "Revert".into())
        }
        revm::context_interface::result::ExecutionResult::Halt { reason, .. } => {
            ("exception", format!("{reason:?}"))
        }
    };
    let mut accounts = BTreeMap::new();
    let mut slots = BTreeMap::new();
    for (address, a) in executed.state {
        if !a.is_touched() && !a.is_created() && !a.is_selfdestructed() {
            continue;
        }
        let original = initial.get(&address);
        let deleted = a.is_selfdestructed() || a.info.is_empty();
        if deleted {
            if original.is_some() {
                accounts.insert(address,json!({"address":format!("{address:#x}"),"exists":false,"balance":"0x0","nonce":0,"code_hash":format!("{:#x}",B256::ZERO)}));
                for ((sa, key), value) in &storage {
                    if *sa == address && !value.is_zero() {
                        slots.insert((address,*key),json!({"address":format!("{address:#x}"),"key":format!("{key:#x}"),"value":"0x0"}));
                    }
                }
            }
            continue;
        }
        if original.is_none_or(|o| {
            o.balance != a.info.balance
                || o.nonce != a.info.nonce
                || o.code_hash != a.info.code_hash
        }) {
            accounts.insert(address,json!({"address":format!("{address:#x}"),"exists":true,"balance":format!("{:#x}",a.info.balance),"nonce":a.info.nonce,"code_hash":format!("{:#x}",a.info.code_hash)}));
        }
        for (key, slot) in a.changed_storage_slots() {
            slots.insert((address,*key),json!({"address":format!("{address:#x}"),"key":format!("{key:#x}"),"value":format!("{:#x}",slot.present_value())}));
        }
    }
    let logs:Vec<_>=result.logs().iter().map(|l|json!({"address":format!("{:#x}",l.address),"topics":l.data.topics().iter().map(|t|format!("{t:#x}")).collect::<Vec<_>>(),"data":l.data.data.to_vec()})).collect();
    let commitments = commitment::commit(&json!({"accounts":post_allocation,"logs":logs}))?;
    Ok(
        json!({"post_allocation":post_allocation,"stateRoot":commitments["stateRoot"],"logsHash":commitments["logsHash"],"block_regular_gas_used":result.gas().block_regular_gas_used(),"block_state_gas_used":result.gas().block_state_gas_used(),"gas_refunded":result.gas().inner_refunded(),"effective_gas_refunded":result.gas().final_refunded(),"floor_gas":result.gas().floor_gas(),"created_address":result.created_address(),"mode":"transaction","fork":i.fork,"status":status,"reason":reason,"gas_used":result.tx_gas_used(),"total_gas_spent":result.gas().total_gas_spent(),"state_gas_spent":result.gas().state_gas_spent_final(),"output":result.output().map(|v|v.to_vec()).unwrap_or_default(),"logs":logs,"state":{"accounts":accounts.into_values().collect::<Vec<_>>(),"storage":slots.into_values().collect::<Vec<_>>()}}),
    )
}
fn execute_input(v: Value) -> Value {
    if v.get("mode").and_then(Value::as_str)==Some("recover_authorizations") { return authorization_crypto::recover(&v); }
    if v.get("mode").and_then(Value::as_str) == Some("commitment") {
        return commitment::commit(&v)
            .unwrap_or_else(|e| json!({"mode":"commitment","status":"error","reason":e}));
    }
    match serde_json::from_value::<Input>(v) {
        Ok(i) => {
            let fork = i.fork.clone();
            run(i).unwrap_or_else(|e| rejected(&fork, e))
        }
        Err(e) => rejected("amsterdam", format!("invalid input: {e}")),
    }
}
/// Optional expected output comparison is exact for each supplied field.
fn dispatch(v: Value) -> Value {
    if v.get("format").is_some() {
        return fixture::execute(&v);
    }
    let expected = v.get("expected").cloned();
    let mut actual = execute_input(v);
    if let Some(expected) = expected {
        let mut mismatches = Vec::new();
        if let Some(fields) = expected.as_object() {
            for (key, value) in fields {
                if actual.get(key) != Some(value) {
                    mismatches.push(json!({"field":key,"expected":value,"actual":actual.get(key)}));
                }
            }
        } else {
            mismatches.push(json!({"field":"expected","reason":"must be an object"}));
        }
        actual["verification"] = json!({"passed":mismatches.is_empty(),"mismatches":mismatches});
    }
    actual
}
fn main() {
    for line in io::stdin().lock().lines() {
        let line = match line {
            Ok(v) => v,
            Err(e) => {
                eprintln!("stdin: {e}");
                break;
            }
        };
        if line.trim().is_empty() {
            continue;
        }
        let output = match serde_json::from_str::<Value>(&line) {
            Ok(v) => dispatch(v),
            Err(e) => rejected("amsterdam", format!("invalid input: {e}")),
        };
        println!("{output}");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn legacy_stop_complete_state() {
        let v = dispatch(
            json!({"code":[0],"accounts":[{"address":"0x0000000000000000000000000000000000003000","balance":"0x7","storage":[["0x1","0x2"]]}]}),
        );
        assert_eq!(v["status"], "halted", "{v}");
        assert_eq!(v["gas_used"], 15000);
        assert!(
            v["post_allocation"]
                .as_array()
                .unwrap()
                .iter()
                .any(
                    |a| a["address"] == "0x0000000000000000000000000000000000003000"
                        && a["storage"][0][1] == "0x2"
                )
        );
        let c =
            dispatch(json!({"mode":"commitment","accounts":v["post_allocation"],"logs":v["logs"]}));
        assert_eq!(c["stateRoot"], v["stateRoot"]);
    }
    #[test]
    fn typed_access_and_fee_transactions() {
        for ty in [1, 2] {
            let v = dispatch(
                json!({"code":[0],"tx_type":ty,"chain_id":1,"max_fee_per_gas":10,"max_priority_fee_per_gas":0,"access_list":[{"address":"0x0000000000000000000000000000000000002000","storageKeys":[]}]}),
            );
            assert_eq!(v["status"], "halted", "{v}");
            assert_eq!(v["gas_used"], 19180);
        }
    }
    #[test]
    fn strict_chain_and_funding() {
        let v = dispatch(json!({"strict":true,"chain_id":2}));
        assert_eq!(v["status"], "rejected");
        let v = dispatch(json!({"strict":true,"gas_price":1}));
        assert_eq!(v["status"], "rejected");
    }
    #[test]
    fn clear_storage_refund_and_preserve_other_slots() {
        let v = dispatch(
            json!({"code":[95,95,85,0],"accounts":[{"address":"0x0000000000000000000000000000000000002000","storage":[["0x0","0x1"],["0x2","0x3"]]}]}),
        );
        assert_eq!(v["status"], "halted", "{v}");
        assert!(v["gas_refunded"].as_u64().unwrap() > 0);
        let a = v["post_allocation"]
            .as_array()
            .unwrap()
            .iter()
            .find(|a| a["address"] == target())
            .unwrap();
        assert_eq!(a["storage"], json!([["0x2", "0x3"]]));
    }
    #[test]
    fn create_returns_runtime_code() {
        let v = dispatch(json!({"create":true,"calldata":[96,0,96,0,83,96,1,96,0,243]}));
        assert_eq!(v["status"], "halted", "{v}");
        let address = &v["created_address"];
        assert!(
            v["post_allocation"]
                .as_array()
                .unwrap()
                .iter()
                .any(|a| &a["address"] == address && a["code"] == json!([0]))
        );
    }
}

#[cfg(test)]
mod environment_tests {
    use super::*;
    #[test]
    fn blob_transaction() {
        let v = dispatch(
            json!({"tx_type":3,"chain_id":1,"max_fee_per_gas":1,"max_priority_fee_per_gas":0,"max_fee_per_blob_gas":1,"blob_hashes":[format!("0x01{}","00".repeat(31))],"code":[0]}),
        );
        assert_eq!(v["status"], "halted", "{v}");
    }
    #[test]
    fn authorization_transaction() {
        let v = dispatch(
            json!({"tx_type":4,"chain_id":1,"max_fee_per_gas":1,"max_priority_fee_per_gas":0,"authorization_list":[{"chainId":"0x1","address":target(),"nonce":"0x0","yParity":"0x0","r":"0x0","s":"0x0"}],"code":[0]}),
        );
        // Invalid signatures are skipped under EIP-7702, while intrinsic authorization gas is charged.
        assert_eq!(v["status"], "halted", "{v}");
        assert!(v["gas_used"].as_u64().unwrap() > 21000);
    }
    #[test]
    fn block_hash_and_numeric_block_compatibility() {
        let hash = format!("0x{}", "11".repeat(32));
        let v = dispatch(
            json!({"block":{"number":2,"timestamp":3},"block_hashes":{"1":hash},"code":[96,1,64,95,82,96,32,95,243]}),
        );
        assert_eq!(v["status"], "halted", "{v}");
        assert_eq!(v["output"], json!(vec![17; 32]));
    }
    #[test]
    fn revert_preserves_storage() {
        let v = dispatch(
            json!({"code":[95,95,85,95,95,253],"accounts":[{"address":target(),"storage":[["0x0","0x1"]]}]}),
        );
        assert_eq!(v["status"], "revert", "{v}");
        let a = v["post_allocation"]
            .as_array()
            .unwrap()
            .iter()
            .find(|a| a["address"] == target())
            .unwrap();
        assert_eq!(a["storage"], json!([["0x0", "0x1"]]));
    }
}

#[cfg(test)]
mod fixture_tests {
    use super::*;
    #[test]
    fn strict_stop_fixture() {
        let v = dispatch(serde_json::from_str(include_str!("../fixtures/stop.json")).unwrap());
        assert_eq!(v["verification"]["passed"], true, "{v}");
        assert_eq!(v["stateRoot"].as_str().unwrap().len(), 66);
    }
    #[test]
    fn pinned_amsterdam_blob_base_fee() {
        let v =
            dispatch(json!({"code":[74,95,82,96,32,95,243],"block":{"excess_blob_gas":11684671}}));
        assert_eq!(v["status"], "halted", "{v}");
        assert_eq!(v["output"][31], 2); // floor(e^1); Prague's fraction produces 10.
    }
    #[test]
    fn verification_reports_failure() {
        let v = dispatch(json!({"mode":"commitment","expected":{"stateRoot":"wrong"}}));
        assert_eq!(v["verification"]["passed"], false);
    }
}
