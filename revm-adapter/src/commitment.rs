//! Ethereum secure state/storage tries and EEST's keccak256(RLP(logs)).
use alloy_rlp::Encodable;
use alloy_trie::{
    TrieAccount,
    root::{state_root_unhashed, storage_root_unhashed},
};
use revm::primitives::{Address, B256, U256, hex, keccak256};
use serde_json::{Value, json};
use std::{collections::BTreeMap, str::FromStr};

fn uint(value: Option<&Value>) -> Result<U256, String> {
    match value {
        None | Some(Value::Null) => Ok(U256::ZERO),
        Some(Value::String(s)) => U256::from_str(s).map_err(|e| format!("invalid integer: {e}")),
        Some(v) => v
            .as_u64()
            .map(U256::from)
            .ok_or_else(|| "expected unsigned integer or integer string".into()),
    }
}
fn bytes(value: Option<&Value>) -> Result<Vec<u8>, String> {
    match value {
        None => Ok(Vec::new()),
        Some(Value::String(s)) => hex::decode(s).map_err(|e| format!("invalid hex bytes: {e}")),
        Some(Value::Array(v)) => v
            .iter()
            .map(|b| {
                b.as_u64()
                    .and_then(|n| u8::try_from(n).ok())
                    .ok_or_else(|| "byte outside 0..255".into())
            })
            .collect(),
        _ => Err("expected byte array or hex string".into()),
    }
}
fn address(v: &Value) -> Result<Address, String> {
    if let Some(s) = v.as_str() {
        return Address::from_str(s).map_err(|e| format!("invalid address: {e}"));
    }
    let b = bytes(Some(v))?;
    if b.len() != 20 {
        return Err("address must contain 20 bytes".into());
    }
    Ok(Address::from_slice(&b))
}
fn list(payload: Vec<u8>) -> Vec<u8> {
    let mut out = Vec::new();
    alloy_rlp::Header {
        list: true,
        payload_length: payload.len(),
    }
    .encode(&mut out);
    out.extend(payload);
    out
}
fn account(v: &Value) -> Result<TrieAccount, String> {
    if !v.is_object() {
        return Err("account must be an object".into());
    }
    let mut storage = BTreeMap::new();
    let mut insert = |k: &Value, v: &Value| -> Result<(), String> {
        let key = B256::from(uint(Some(k))?.to_be_bytes::<32>());
        if storage.insert(key, uint(Some(v))?).is_some() {
            return Err("duplicate storage key".into());
        }
        Ok(())
    };
    match v.get("storage") {
        None => (),
        Some(Value::Object(slots)) => {
            for (k, v) in slots {
                insert(&Value::String(k.clone()), v)?;
            }
        }
        Some(Value::Array(slots)) => {
            for pair in slots {
                let pair = pair
                    .as_array()
                    .filter(|p| p.len() == 2)
                    .ok_or("storage must contain key/value pairs")?;
                insert(&pair[0], &pair[1])?;
            }
        }
        _ => return Err("storage must be an object or pair array".into()),
    }
    Ok(TrieAccount {
        nonce: u64::try_from(uint(v.get("nonce"))?).map_err(|_| "nonce exceeds u64")?,
        balance: uint(v.get("balance"))?,
        storage_root: storage_root_unhashed(
            storage.into_iter().filter(|(_, value)| !value.is_zero()),
        ),
        code_hash: keccak256(bytes(v.get("code"))?),
    })
}

/// Hash a complete allocation (including explicitly present empty accounts).
/// Accepts `accounts: [{address,balance,nonce,code,storage}]` or `alloc`/`allocation`
/// address-keyed objects. Missing accounts/logs mean empty; zero storage is omitted.
/// Returns `mode`, `state_root`/`stateRoot`, and `logs_hash`/`logsHash` as lowercase 0x-prefixed hashes.
pub fn commit(input: &Value) -> Result<Value, String> {
    if !input.is_object() {
        return Err("commitment input must be an object".into());
    }
    let sources = ["accounts", "alloc", "allocation"]
        .iter()
        .filter(|key| input.get(**key).is_some())
        .count();
    if sources > 1 {
        return Err("provide only one allocation field".into());
    }
    let mut accounts = BTreeMap::new();
    let mut insert = |address, value: &Value| -> Result<(), String> {
        if accounts.insert(address, account(value)?).is_some() {
            return Err("duplicate account address".into());
        }
        Ok(())
    };
    match input
        .get("accounts")
        .or_else(|| input.get("alloc"))
        .or_else(|| input.get("allocation"))
    {
        None => (),
        Some(Value::Array(values)) => {
            for value in values {
                insert(
                    address(value.get("address").ok_or("missing account address")?)?,
                    value,
                )?;
            }
        }
        Some(Value::Object(values)) => {
            for (key, value) in values {
                insert(address(&Value::String(key.clone()))?, value)?;
            }
        }
        _ => return Err("allocation must be an array or object".into()),
    }
    let mut logs_payload = Vec::new();
    if let Some(logs) = input.get("logs") {
        for log in logs.as_array().ok_or("logs must be an array")? {
            let mut payload = Vec::new();
            address(log.get("address").ok_or("missing log address")?)?.encode(&mut payload);
            let mut topics_payload = Vec::new();
            if let Some(topics) = log.get("topics") {
                let topics = topics.as_array().ok_or("topics must be an array")?;
                if topics.len() > 4 {
                    return Err("log has more than four topics".into());
                }
                for topic in topics {
                    let b = bytes(Some(topic))?;
                    if b.len() != 32 {
                        return Err("log topic must contain 32 bytes".into());
                    }
                    b.as_slice().encode(&mut topics_payload);
                }
            }
            payload.extend(list(topics_payload));
            bytes(log.get("data"))?.as_slice().encode(&mut payload);
            logs_payload.extend(list(payload));
        }
    }
    let state_root = format!("{:#x}", state_root_unhashed(accounts));
    let logs_hash = format!("{:#x}", keccak256(list(logs_payload)));
    Ok(
        json!({"mode":"commitment", "state_root":state_root, "stateRoot":state_root, "logs_hash":logs_hash, "logsHash":logs_hash}),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn empty_constants() {
        let result = commit(&json!({})).unwrap();
        assert_eq!(result["stateRoot"], result["state_root"]);
        assert_eq!(result["logsHash"], result["logs_hash"]);
        assert_eq!(
            result["state_root"],
            "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"
        );
        assert_eq!(
            result["logs_hash"],
            "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"
        );
    }
    // Independent one-leaf MPT construction: hex-prefix 0x20 followed by the
    // entire hashed key. All RLP framing is literal, without alloy-trie/RLP.
    #[test]
    fn nonempty_independent_leaf_vector() {
        let addr = Address::with_last_byte(1);
        let slot_hash = keccak256([0u8; 32]);
        let mut storage_leaf = vec![0xe3, 0xa1, 0x20];
        storage_leaf.extend(slot_hash.as_slice());
        storage_leaf.push(0x01); // RLP(value=1), itself encoded as a byte string
        let storage_root = keccak256(storage_leaf);
        let mut account_rlp = vec![0xf8, 0x44, 0x01, 0x02, 0xa0];
        account_rlp.extend(storage_root.as_slice());
        account_rlp.push(0xa0);
        account_rlp.extend(keccak256([0x00]).as_slice());
        let mut state_leaf = vec![0xf8, 0x6a, 0xa1, 0x20];
        state_leaf.extend(keccak256(addr).as_slice());
        state_leaf.extend([0xb8, 0x46]);
        state_leaf.extend(account_rlp);
        let input = json!({"accounts":[{"address":format!("{addr:#x}"),"nonce":1,"balance":"0x2","code":[0],"storage":[["0x0","0x1"],["0x1","0x0"]]}]});
        assert_eq!(
            commit(&input).unwrap()["state_root"],
            format!("{:#x}", keccak256(state_leaf))
        );
        let allocation = json!({"alloc":{format!("{addr:#x}"):{"nonce":"0x1","balance":"0x2","code":"0x00","storage":{"0x0":"0x1"}}}});
        assert_eq!(commit(&input).unwrap(), commit(&allocation).unwrap());
    }
    #[test]
    fn independent_log_rlp() {
        let mut rlp = vec![0xf8, 0x3c, 0xf8, 0x3a, 0x94];
        rlp.extend([0u8; 20]);
        rlp.extend([0xe1, 0xa0]);
        rlp.extend([1u8; 32]);
        rlp.extend([0x82, 0xaa, 0xbb]);
        let result = commit(
            &json!({"logs":[{"address":vec![0;20],"topics":[vec![1;32]],"data":[170,187]}]}),
        )
        .unwrap();
        assert_eq!(result["logs_hash"], format!("{:#x}", keccak256(rlp)));
    }
    #[test]
    fn rejects_duplicate_and_malformed_inputs() {
        let a = json!({"address":format!("{:#x}",Address::ZERO)});
        assert!(commit(&json!({"accounts":[a.clone(),a]})).is_err());
        assert!(commit(&json!({"accounts":[{"address":format!("{:#x}",Address::ZERO),"storage":[["0","1"],["0x0","2"]]}]})).is_err());
        assert!(commit(&json!({"logs":[{"address":vec![0;20],"topics":[[0]]}]})).is_err());
    }
}
