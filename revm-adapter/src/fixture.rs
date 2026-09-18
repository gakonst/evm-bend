//! Input-only EEST state-test bridge. Expected results never enter execution.
use super::*;
use revm::primitives::hex;
fn q(v: Option<&Value>) -> Result<U256, String> {
    match v {
        None | Some(Value::Null) => Ok(U256::ZERO),
        Some(Value::String(s)) => uint(s),
        Some(v) => v.as_u64().map(U256::from).ok_or("invalid quantity".into()),
    }
}
fn u64q(v: Option<&Value>) -> Result<u64, String> {
    q(v)?
        .try_into()
        .map_err(|_| "quantity overflows u64".into())
}
fn u128q(v: Option<&Value>) -> Result<u128, String> {
    q(v)?
        .try_into()
        .map_err(|_| "quantity overflows u128".into())
}
fn bytes(v: Option<&Value>) -> Result<Vec<u8>, String> {
    match v {
        None => Ok(vec![]),
        Some(Value::String(s)) => hex::decode(s).map_err(|e| e.to_string()),
        Some(v) => serde_json::from_value(v.clone()).map_err(|e| e.to_string()),
    }
}
fn string(v: Option<&Value>, default: &str) -> String {
    v.and_then(Value::as_str).unwrap_or(default).into()
}
fn normalize(v: &Value) -> Result<Input, String> {
    if v.get("fork").and_then(Value::as_str) != Some("Amsterdam") {
        return Err("only Amsterdam fixture bridge is supported".into());
    }
    let t = v
        .get("transaction")
        .and_then(Value::as_object)
        .ok_or("missing transaction")?;
    let e = v
        .get("env")
        .and_then(Value::as_object)
        .ok_or("missing env")?;
    if e.contains_key("currentBeaconRoot") || e.contains_key("previousHash") {
        return Err("pre-block system calls are not implemented".into());
    }
    let pre = v
        .get("pre")
        .and_then(Value::as_object)
        .ok_or("missing pre allocation")?;
    let mut i: Input = serde_json::from_value(json!({})).map_err(|e| e.to_string())?;
    i.strict = true;
    i.caller = t
        .get("sender")
        .and_then(Value::as_str)
        .ok_or("explicit sender required; secret-key recovery not implemented")?
        .into();
    i.target = string(t.get("to"), "");
    i.create = i.target.is_empty();
    if i.create {
        i.target = target();
    }
    i.gas = u64q(t.get("gasLimit"))?;
    i.nonce = u64q(t.get("nonce"))?;
    i.value = format!("{:#x}", q(t.get("value"))?);
    i.calldata = bytes(t.get("data"))?;
    i.chain_id = t.get("chainId").map(|v| u64q(Some(v))).transpose()?;
    i.cfg_chain_id = e
        .get("currentChainID")
        .or_else(|| e.get("currentChainId"))
        .map(|v| u64q(Some(v)))
        .transpose()?
        .unwrap_or(1);
    i.gas_price = u128q(t.get("gasPrice"))?;
    i.max_fee_per_gas = t.get("maxFeePerGas").map(|v| u128q(Some(v))).transpose()?;
    i.max_priority_fee_per_gas = t
        .get("maxPriorityFeePerGas")
        .map(|v| u128q(Some(v)))
        .transpose()?;
    if i.max_fee_per_gas.is_some() && i.max_priority_fee_per_gas.is_none() {
        i.max_priority_fee_per_gas = Some(0);
    }
    if let Some(a) = t.get("accessList").filter(|a| !a.is_null()) {
        i.access_list = serde_json::from_value(a.clone()).map_err(|e| e.to_string())?;
    }
    if let Some(a) = t.get("blobVersionedHashes") {
        i.blob_hashes = serde_json::from_value(a.clone()).map_err(|e| e.to_string())?;
    }
    i.max_fee_per_blob_gas = u128q(t.get("maxFeePerBlobGas"))?;
    if let Some(auth) = t.get("authorizationList") {
        for a in auth.as_array().ok_or("authorizationList must be array")? {
            let mut a = a.clone();
            let o = a.as_object_mut().ok_or("authorization must be object")?;
            o.remove("signer"); // Fixture annotation, never an authority override.
            if o.contains_key("yParity") {
                o.remove("v");
            } else if let Some(parity) = o.remove("v") {
                o.insert("yParity".into(), parity);
            }
            i.authorization_list
                .push(serde_json::from_value(a).map_err(|e| e.to_string())?);
        }
    }
    i.tx_type = if let Some(v) = t.get("type") {
        u8::try_from(u64q(Some(v))?).map_err(|_| "type overflows u8")?
    } else if t.contains_key("authorizationList") {
        4
    } else if t.contains_key("maxFeePerBlobGas") || t.contains_key("blobVersionedHashes") {
        3
    } else if t.contains_key("maxFeePerGas") {
        2
    } else if t.get("accessList").is_some_and(|a| !a.is_null()) {
        1
    } else {
        0
    };
    for (address, a) in pre {
        let mut storage = Vec::new();
        if let Some(s) = a.get("storage") {
            for (k, v) in s.as_object().ok_or("storage must be object")? {
                storage.push((k.clone(), format!("{:#x}", q(Some(v))?)));
            }
        }
        i.accounts.push(Account {
            address: address.clone(),
            balance: Some(format!("{:#x}", q(a.get("balance"))?)),
            nonce: u64q(a.get("nonce"))?,
            code: bytes(a.get("code"))?,
            storage,
        });
    }
    i.block = Block {
        number: q(e.get("currentNumber"))?,
        timestamp: q(e.get("currentTimestamp"))?,
        difficulty: q(e.get("currentDifficulty"))?,
        slot_num: u64q(e.get("slotNumber"))?,
        excess_blob_gas: u64q(e.get("currentExcessBlobGas"))?,
        blob_gasprice: None,
        gas_limit: u64q(e.get("currentGasLimit"))?,
        basefee: u64q(e.get("currentBaseFee"))?,
        beneficiary: string(
            e.get("currentCoinbase"),
            "0x0000000000000000000000000000000000000000",
        ),
        prevrandao: format!("{:#066x}", q(e.get("currentRandom"))?),
    };
    if let Some(h) = e.get("blockHashes") {
        for (k, v) in h.as_object().ok_or("blockHashes must be object")? {
            i.block_hashes.insert(
                u64q(Some(&json!(k)))?,
                B256::from_str(v.as_str().ok_or("invalid block hash")?)
                    .map_err(|e| e.to_string())?,
            );
        }
    }
    Ok(i)
}
pub fn execute(v: &Value) -> Value {
    if v.get("format").and_then(Value::as_str) != Some("state_test") {
        return json!({"status":"unsupported","reason":"raw signed transaction and blockchain formats are not implemented"});
    }
    let input = match normalize(v) {
        Ok(i) => i,
        Err(e) => return json!({"status":"unsupported","reason":e}),
    };
    match run(input) {
        Ok(mut out) => {
            out["state_root"] = out["stateRoot"].clone();
            out["logs_hash"] = out["logsHash"].clone();
            out["output"] = json!(format!(
                "0x{}",
                hex::encode(serde_json::from_value::<Vec<u8>>(out["output"].clone()).unwrap())
            ));
            out["exception"] = Value::Null; // EVM REVERT/HALT is not transaction rejection.
            let mut alloc = serde_json::Map::new();
            for a in out["post_allocation"].as_array().unwrap() {
                let mut slots = serde_json::Map::new();
                for p in a["storage"].as_array().unwrap() {
                    slots.insert(p[0].as_str().unwrap().into(), p[1].clone());
                }
                alloc.insert(a["address"].as_str().unwrap().into(),json!({"balance":a["balance"],"nonce":format!("0x{:x}",a["nonce"].as_u64().unwrap()),"code":format!("0x{}",hex::encode(serde_json::from_value::<Vec<u8>>(a["code"].clone()).unwrap())),"storage":slots}));
            }
            out["post_state"] = Value::Object(alloc);
            out
        }
        Err(e) => {
            // REVM validation failure leaves prestate unchanged; no expected data is used.
            let exception = if e.starts_with("Transaction(CallGasCostMoreThanGasLimit")
                || e.starts_with("Transaction(GasFloorMoreThanGasLimit")
            {
                Some("TransactionException.INTRINSIC_GAS_TOO_LOW")
            } else {
                None
            };
            if let Some(exception) = exception {
                match commitment::commit(&json!({"alloc":v["pre"],"logs":[]})) {
                    Ok(c) => {
                        json!({"status":"rejected","reason":e,"exception":exception,"state_root":c["state_root"],"logs_hash":c["logs_hash"],"post_state":v["pre"],"output":"0x","logs":[],"gas_used":0})
                    }
                    Err(e) => json!({"status":"host_error","reason":e}),
                }
            } else {
                json!({"status":"unsupported","reason":format!("transaction rejection requires EEST exception mapping: {e}")})
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn request() -> Value {
        json!({"format":"state_test","fork":"Amsterdam","env":{"currentChainID":"0x2a","currentGasLimit":"0x7270e00","slotNumber":"0xffffffffffffffff"},"pre":{},"transaction":{"sender":caller(),"to":target(),"gasLimit":"0x7270e00","chainId":"0x2a","authorizationList":[{"chainId":"0x0","address":target(),"nonce":"0x0","yParity":"0x1","v":"0x0","r":"0x1","s":"0x1","signer":caller()}]}})
    }
    #[test]
    fn quantities_chain_and_authorization_annotation() {
        let i = normalize(&request()).unwrap();
        assert_eq!(i.gas, 120_000_000);
        assert_eq!(i.block.gas_limit, 120_000_000);
        assert_eq!(i.block.slot_num, u64::MAX);
        assert_eq!(i.cfg_chain_id, 42);
        assert_eq!(i.chain_id, Some(42));
        assert_eq!(i.tx_type, 4);
        assert_eq!(i.authorization_list.len(), 1);
        let mut v = request();
        v["transaction"]["authorizationList"][0]
            .as_object_mut()
            .unwrap()
            .remove("signer");
        assert_eq!(
            i.authorization_list,
            normalize(&v).unwrap().authorization_list
        );
    }
    #[test]
    fn unsupported_formats_do_not_fall_through_to_execution() {
        for format in [
            "transaction_test",
            "blockchain_test",
            "blockchain_test_engine",
        ] {
            assert_eq!(
                dispatch(json!({"format":format,"txbytes":"0x"}))["status"],
                "unsupported"
            );
        }
    }
    #[test]
    fn expected_values_never_affect_fixture_execution() {
        let mut v = request();
        v["expected"] = json!({"state_root":"forged"});
        let out = dispatch(v.clone());
        v.as_object_mut().unwrap().remove("expected");
        assert_eq!(out, dispatch(v));
        assert!(out.get("verification").is_none());
    }
}
