const EXCEPTIONS: &[&str] = &[
    "TYPE_NOT_SUPPORTED",
    "SENDER_NOT_EOA",
    "ADDRESS_TOO_SHORT",
    "ADDRESS_TOO_LONG",
    "NONCE_MISMATCH_TOO_HIGH",
    "NONCE_MISMATCH_TOO_LOW",
    "NONCE_TOO_BIG",
    "NONCE_IS_MAX",
    "NONCE_OVERFLOW",
    "GASLIMIT_OVERFLOW",
    "VALUE_OVERFLOW",
    "GASPRICE_OVERFLOW",
    "GASLIMIT_PRICE_PRODUCT_OVERFLOW",
    "INVALID_SIGNATURE_VRS",
    "RLP_INVALID_SIGNATURE_R",
    "RLP_INVALID_SIGNATURE_S",
    "RLP_LEADING_ZEROS_GASLIMIT",
    "RLP_LEADING_ZEROS_GASPRICE",
    "RLP_LEADING_ZEROS_VALUE",
    "RLP_LEADING_ZEROS_NONCE",
    "RLP_LEADING_ZEROS_R",
    "RLP_LEADING_ZEROS_S",
    "RLP_LEADING_ZEROS_V",
    "RLP_LEADING_ZEROS_BASEFEE",
    "RLP_LEADING_ZEROS_PRIORITY_FEE",
    "RLP_LEADING_ZEROS_DATA_SIZE",
    "RLP_LEADING_ZEROS_NONCE_SIZE",
    "RLP_TOO_FEW_ELEMENTS",
    "RLP_TOO_MANY_ELEMENTS",
    "RLP_ERROR_EOF",
    "RLP_ERROR_SIZE",
    "RLP_ERROR_SIZE_LEADING_ZEROS",
    "INVALID_CHAINID",
    "RLP_INVALID_DATA",
    "RLP_INVALID_GASLIMIT",
    "RLP_INVALID_NONCE",
    "RLP_INVALID_TO",
    "RLP_INVALID_ACCESS_LIST_ADDRESS_TOO_LONG",
    "RLP_INVALID_ACCESS_LIST_ADDRESS_TOO_SHORT",
    "RLP_INVALID_ACCESS_LIST_STORAGE_TOO_LONG",
    "RLP_INVALID_ACCESS_LIST_STORAGE_TOO_SHORT",
    "RLP_INVALID_HEADER",
    "RLP_INVALID_VALUE",
    "EC_RECOVERY_FAIL",
    "INSUFFICIENT_ACCOUNT_FUNDS",
    "INSUFFICIENT_MAX_FEE_PER_GAS",
    "PRIORITY_OVERFLOW",
    "PRIORITY_GREATER_THAN_MAX_FEE_PER_GAS",
    "PRIORITY_GREATER_THAN_MAX_FEE_PER_GAS_2",
    "INSUFFICIENT_MAX_FEE_PER_BLOB_GAS",
    "INTRINSIC_GAS_TOO_LOW",
    "INTRINSIC_GAS_BELOW_FLOOR_GAS_COST",
    "INITCODE_SIZE_EXCEEDED",
    "TYPE_1_TX_PRE_FORK",
    "TYPE_2_TX_PRE_FORK",
    "TYPE_3_TX_PRE_FORK",
    "TYPE_3_TX_ZERO_BLOBS_PRE_FORK",
    "TYPE_3_TX_INVALID_BLOB_VERSIONED_HASH",
    "TYPE_3_TX_WITH_FULL_BLOBS",
    "TYPE_3_TX_BLOB_COUNT_EXCEEDED",
    "TYPE_3_TX_CONTRACT_CREATION",
    "TYPE_3_TX_MAX_BLOB_GAS_ALLOWANCE_EXCEEDED",
    "GAS_ALLOWANCE_EXCEEDED",
    "GAS_LIMIT_EXCEEDS_MAXIMUM",
    "TYPE_3_TX_ZERO_BLOBS",
    "TYPE_4_EMPTY_AUTHORIZATION_LIST",
    "TYPE_4_INVALID_AUTHORITY_SIGNATURE",
    "TYPE_4_INVALID_AUTHORITY_SIGNATURE_S_TOO_HIGH",
    "TYPE_4_TX_CONTRACT_CREATION",
    "TYPE_4_INVALID_AUTHORIZATION_FORMAT",
    "TYPE_4_TX_PRE_FORK",
    "LOG_MISMATCH",
];
use alloy_primitives::{Signature, U256, keccak256};
use serde::Serialize;
use serde_json::{Value, json};

#[derive(Debug, Serialize)]
pub struct WireError {
    pub category: &'static str,
    pub exception: String,
    pub message: String,
}
type Result<T> = std::result::Result<T, WireError>;
fn err(code: &str, message: impl Into<String>) -> WireError {
    // Never synthesize exception names outside the pinned EEST vocabulary.
    let code = match code {
        "RLP_LEADING_ZEROS_TIP" => "RLP_LEADING_ZEROS_PRIORITY_FEE",
        "RLP_LEADING_ZEROS_FEECAP" => "RLP_LEADING_ZEROS_BASEFEE",
        "RLP_INVALID_CHAINID" | "RLP_LEADING_ZEROS_CHAINID" => "INVALID_CHAINID",
        code if EXCEPTIONS.contains(&code) => code,
        _ => "RLP_INVALID_HEADER",
    };
    WireError {
        category: if code.starts_with("INVALID_SIGNATURE")
            || code.starts_with("TYPE_4_INVALID_AUTHORITY_SIGNATURE")
        {
            "crypto"
        } else {
            "wire"
        },
        exception: format!("TransactionException.{code}"),
        message: message.into(),
    }
}
#[derive(Clone, Copy)]
struct Node<'a> {
    raw: &'a [u8],
    data: &'a [u8],
    list: bool,
}
fn parse<'a>(input: &mut &'a [u8], field: &str) -> Result<Node<'a>> {
    let b = *input.first().ok_or_else(|| err("RLP_ERROR_EOF", field))?;
    let (offset, len, list) = match b {
        0..=127 => (0, 1, false),
        128..=183 => (1, (b - 128) as usize, false),
        184..=191 | 248..=255 => {
            let n = if b < 192 { b - 183 } else { b - 247 } as usize;
            if input.len() < 1 + n {
                return Err(err("RLP_ERROR_EOF", field));
            }
            if input[1] == 0 {
                return Err(err(
                    if field == "DATA" && b < 192 {
                        "RLP_LEADING_ZEROS_DATA_SIZE"
                    } else {
                        "RLP_ERROR_SIZE_LEADING_ZEROS"
                    },
                    field,
                ));
            }
            let mut size = 0usize;
            for x in &input[1..1 + n] {
                size = size
                    .checked_mul(256)
                    .and_then(|v| v.checked_add(*x as usize))
                    .ok_or_else(|| err("RLP_ERROR_SIZE", field))?;
            }
            if size < 56 {
                return Err(err(&format!("RLP_LEADING_ZEROS_{field}_SIZE"), field));
            }
            (1 + n, size, b >= 248)
        }
        192..=247 => (1, (b - 192) as usize, true),
    };
    let end = offset
        .checked_add(len)
        .ok_or_else(|| err("RLP_ERROR_SIZE", field))?;
    if end > input.len() {
        return Err(err("RLP_ERROR_EOF", field));
    }
    if b == 129 && input[1] < 128 {
        return Err(err(&format!("RLP_LEADING_ZEROS_{field}_SIZE"), field));
    }
    let node = Node {
        raw: &input[..end],
        data: &input[offset..end],
        list,
    };
    *input = &input[end..];
    Ok(node)
}
fn invalid(field: &str) -> String {
    format!(
        "RLP_INVALID_{}",
        match field {
            "R" => "SIGNATURE_R",
            "S" => "SIGNATURE_S",
            x => x,
        }
    )
}
fn bytes<'a>(n: Node<'a>, field: &str) -> Result<&'a [u8]> {
    if n.list {
        Err(err(&invalid(field), field))
    } else {
        Ok(n.data)
    }
}
fn uint(n: Node<'_>, field: &str) -> Result<U256> {
    let b = bytes(n, field)?;
    if b.first() == Some(&0) {
        return Err(err(&format!("RLP_LEADING_ZEROS_{field}"), field));
    }
    if b.len() > 32 {
        return Err(err(
            if field == "VALUE" {
                "VALUE_OVERFLOW"
            } else {
                return Err(err(&invalid(field), field));
            },
            field,
        ));
    }
    Ok(U256::from_be_slice(b))
}
fn address(n: Node<'_>, empty: bool) -> Result<Value> {
    let b = bytes(n, "TO")?;
    if empty && b.is_empty() {
        return Ok(json!(""));
    }
    if b.len() != 20 {
        return Err(err(
            if b.len() < 20 {
                "ADDRESS_TOO_SHORT"
            } else {
                "ADDRESS_TOO_LONG"
            },
            "address must be 20 bytes",
        ));
    }
    Ok(json!(hx(b)))
}
fn hx(b: &[u8]) -> String {
    format!("0x{}", hex::encode(b))
}
fn q(v: U256) -> Value {
    json!(format!("0x{v:x}"))
}
fn list(n: Node<'_>) -> Result<Vec<Node<'_>>> {
    if !n.list {
        return Err(err("RLP_INVALID_HEADER", "expected list"));
    }
    let mut p = n.data;
    let mut out = vec![];
    while !p.is_empty() {
        out.push(parse(&mut p, "DATA")?)
    }
    Ok(out)
}
fn count(nodes: &[Node<'_>], n: usize) -> Result<()> {
    if nodes.len() != n {
        Err(err(
            if nodes.len() < n {
                "RLP_TOO_FEW_ELEMENTS"
            } else {
                "RLP_TOO_MANY_ELEMENTS"
            },
            format!("expected {n} fields, got {}", nodes.len()),
        ))
    } else {
        Ok(())
    }
}
fn encode_list(payload: &[u8]) -> Vec<u8> {
    let mut out = vec![];
    if payload.len() < 56 {
        out.push(192 + payload.len() as u8)
    } else {
        let b = payload.len().to_be_bytes();
        let b = &b[b.iter().position(|x| *x != 0).unwrap()..];
        out.push(247 + b.len() as u8);
        out.extend(b)
    }
    out.extend(payload);
    out
}
fn encode_uint(v: U256) -> Vec<u8> {
    if v == U256::ZERO {
        return vec![128];
    }
    let b = v.to_be_bytes::<32>();
    let b = &b[b.iter().position(|x| *x != 0).unwrap()..];
    if b.len() == 1 && b[0] < 128 {
        return b.to_vec();
    }
    let mut out = vec![128 + b.len() as u8];
    out.extend(b);
    out
}
fn recover(r: U256, s: U256, parity: U256, hash: alloy_primitives::B256) -> Result<String> {
    if parity > U256::from(1) {
        return Err(err("INVALID_SIGNATURE_VRS", "parity must be 0 or 1"));
    }
    let sig = Signature::new(r, s, parity == U256::from(1));
    if sig.normalize_s().is_some() {
        return Err(err(
            "INVALID_SIGNATURE_VRS",
            "signature s exceeds secp256k1 half-order",
        ));
    }
    sig.recover_address_from_prehash(&hash)
        .map(|a| hx(a.as_slice()))
        .map_err(|e| err("INVALID_SIGNATURE_VRS", e.to_string()))
}
/// Decode a signed EIP-2718 execution envelope. No account, fee, gas or EVM validation.
pub fn decode(raw: &[u8]) -> Result<Value> {
    decode_inner(raw).map_err(|e| {
        if raw.first() == Some(&4) && e.exception.starts_with("TransactionException.RLP_") {
            err("TYPE_4_INVALID_AUTHORIZATION_FORMAT", e.message)
        } else {
            e
        }
    })
}
fn decode_inner(raw: &[u8]) -> Result<Value> {
    let first = *raw
        .first()
        .ok_or_else(|| err("RLP_ERROR_EOF", "empty transaction"))?;
    let kind = if first >= 192 {
        0
    } else if (1..=4).contains(&first) {
        first
    } else {
        return Err(err("TYPE_NOT_SUPPORTED", "unsupported transaction type"));
    };
    let mut input = if kind == 0 { raw } else { &raw[1..] };
    let root = parse(&mut input, "DATA")?;
    if !input.is_empty() {
        return Err(err("RLP_ERROR_SIZE", "trailing transaction bytes"));
    }
    if !root.list {
        return Err(err("RLP_INVALID_HEADER", "transaction must be list"));
    }
    let names: &[&str] = match kind {
        0 => &[
            "NONCE", "GASPRICE", "GASLIMIT", "TO", "VALUE", "DATA", "V", "R", "S",
        ],
        1 => &[
            "CHAINID",
            "NONCE",
            "GASPRICE",
            "GASLIMIT",
            "TO",
            "VALUE",
            "DATA",
            "ACCESSLIST",
            "V",
            "R",
            "S",
        ],
        2 => &[
            "CHAINID",
            "NONCE",
            "TIP",
            "FEECAP",
            "GASLIMIT",
            "TO",
            "VALUE",
            "DATA",
            "ACCESSLIST",
            "V",
            "R",
            "S",
        ],
        3 => &[
            "CHAINID",
            "NONCE",
            "TIP",
            "FEECAP",
            "GASLIMIT",
            "TO",
            "VALUE",
            "DATA",
            "ACCESSLIST",
            "BLOBFEECAP",
            "BLOBHASHES",
            "V",
            "R",
            "S",
        ],
        _ => &[
            "CHAINID",
            "NONCE",
            "TIP",
            "FEECAP",
            "GASLIMIT",
            "TO",
            "VALUE",
            "DATA",
            "ACCESSLIST",
            "AUTHORIZATIONS",
            "V",
            "R",
            "S",
        ],
    };
    let mut p = root.data;
    let mut fields = vec![];
    for name in names {
        if p.is_empty() {
            return Err(err("RLP_TOO_FEW_ELEMENTS", *name));
        }
        fields.push(parse(&mut p, name)?)
    }
    if !p.is_empty() {
        return Err(err("RLP_TOO_MANY_ELEMENTS", "extra fields"));
    }
    let mut out = serde_json::Map::new();
    out.insert("type".into(), q(U256::from(kind)));
    out.insert("raw".into(), json!(hx(raw)));
    out.insert("hash".into(), json!(hx(keccak256(raw).as_slice())));
    for (name, node) in names.iter().zip(&fields) {
        let value = match *name {
            "TO" => address(*node, true)?,
            "DATA" => json!(hx(bytes(*node, "DATA")?)),
            "ACCESSLIST" => {
                let mut a = vec![];
                for item in list(*node)? {
                    let f = list(item)?;
                    count(&f, 2)?;
                    let addr = address(f[0], false).map_err(|e| match e.exception.as_str() {
                        "TransactionException.ADDRESS_TOO_SHORT" => {
                            err("RLP_INVALID_ACCESS_LIST_ADDRESS_TOO_SHORT", e.message)
                        }
                        "TransactionException.ADDRESS_TOO_LONG" => {
                            err("RLP_INVALID_ACCESS_LIST_ADDRESS_TOO_LONG", e.message)
                        }
                        _ => e,
                    })?;
                    let mut keys = vec![];
                    for key in list(f[1])? {
                        let b = bytes(key, "DATA")?;
                        if b.len() != 32 {
                            return Err(err(
                                if b.len() < 32 {
                                    "RLP_INVALID_ACCESS_LIST_STORAGE_TOO_SHORT"
                                } else {
                                    "RLP_INVALID_ACCESS_LIST_STORAGE_TOO_LONG"
                                },
                                "storage key must be 32 bytes",
                            ));
                        }
                        keys.push(hx(b));
                    }
                    a.push(json!({"address":addr,"storageKeys":keys}));
                }
                json!(a)
            }
            "BLOBHASHES" => {
                let mut a = vec![];
                for h in list(*node)? {
                    let b = bytes(h, "DATA")?;
                    if b.len() != 32 {
                        return Err(err("RLP_INVALID_HEADER", "blob hash must be 32 bytes"));
                    }
                    a.push(hx(b))
                }
                json!(a)
            }
            "AUTHORIZATIONS" => decode_auths(*node)?,
            "GASPRICE" | "GASLIMIT" | "TIP" | "FEECAP" => {
                let b = bytes(*node, name)?;
                if b.first() == Some(&0) {
                    return Err(err(&format!("RLP_LEADING_ZEROS_{name}"), *name));
                }
                if *name == "GASLIMIT" && b.len() > 8 {
                    return Err(err(
                        "GASLIMIT_OVERFLOW",
                        "signed transaction gasLimit exceeds u64",
                    ));
                }
                json!(if b.is_empty() {
                    "0x0".to_string()
                } else {
                    format!("0x{}", hex::encode(b).trim_start_matches('0'))
                })
            }
            _ => {
                let v = uint(*node, name)?;
                if *name == "NONCE" && v > U256::from(u64::MAX) {
                    return Err(err(
                        "NONCE_OVERFLOW",
                        "signed transaction nonce must be less than 2^64",
                    ));
                }
                q(v)
            }
        };
        let key = match *name {
            "GASPRICE" => "gasPrice",
            "GASLIMIT" => "gasLimit",
            "CHAINID" => "chainId",
            "TIP" => "maxPriorityFeePerGas",
            "FEECAP" => "maxFeePerGas",
            "ACCESSLIST" => "accessList",
            "AUTHORIZATIONS" => "authorizationList",
            "BLOBFEECAP" => "maxFeePerBlobGas",
            "BLOBHASHES" => "blobVersionedHashes",
            x => x,
        };
        out.insert(
            if name.chars().all(|c| !c.is_lowercase()) && key == *name {
                key.to_lowercase()
            } else {
                key.to_string()
            },
            value,
        );
    }
    let n = fields.len();
    let v = uint(fields[n - 3], "V")?;
    let r = uint(fields[n - 2], "R")?;
    let s = uint(fields[n - 1], "S")?;
    let mut payload: Vec<u8> = fields[..n - 3]
        .iter()
        .flat_map(|x| x.raw.iter().copied())
        .collect();
    let parity = if kind == 0 {
        if v == U256::from(27) || v == U256::from(28) {
            out.insert("chainId".into(), Value::Null);
            v - U256::from(27)
        } else if v >= U256::from(35) {
            let chain = (v - U256::from(35)) / U256::from(2);
            out.insert("chainId".into(), q(chain));
            payload.extend(encode_uint(chain));
            payload.extend([128, 128]);
            (v - U256::from(35)) % U256::from(2)
        } else {
            return Err(err(
                "INVALID_SIGNATURE_VRS",
                "legacy v must be 27/28 or >=35",
            ));
        }
    } else {
        v
    };
    let mut signing = if kind == 0 { vec![] } else { vec![kind] };
    signing.extend(encode_list(&payload));
    let hash = keccak256(signing);
    out.insert("yParity".into(), q(parity));
    out.insert("signingHash".into(), json!(hx(hash.as_slice())));
    out.insert("sender".into(), json!(recover(r, s, parity, hash)?));
    for key in ["accessList", "blobVersionedHashes", "authorizationList"] {
        out.entry(key).or_insert(json!([]));
    }
    Ok(Value::Object(out))
}
fn decode_auths(node: Node<'_>) -> Result<Value> {
    let inner = || -> Result<Value> {
        let mut out = vec![];
        for a in list(node)? {
            let f = list(a)?;
            count(&f, 6)?;
            let chain = uint(f[0], "CHAINID")?;
            let addr = address(f[1], false)?;
            let nonce = uint(f[2], "NONCE")?;
            if nonce > U256::from(u64::MAX) {
                return Err(err(
                    "TYPE_4_INVALID_AUTHORIZATION_FORMAT",
                    "authorization nonce exceeds u64",
                ));
            }
            let crypto = |n, field| {
                uint(n, field).map_err(|e| {
                    if bytes(n, field).is_ok_and(|b| b.len() > 32) {
                        err("TYPE_4_INVALID_AUTHORITY_SIGNATURE", e.message)
                    } else {
                        e
                    }
                })
            };
            let parity = crypto(f[3], "V")?;
            let r = crypto(f[4], "R")?;
            let s = crypto(f[5], "S")?;
            if parity > U256::from(255) {
                return Err(err(
                    "TYPE_4_INVALID_AUTHORITY_SIGNATURE",
                    "authorization parity exceeds u8",
                ));
            }
            let payload: Vec<u8> = f[..3].iter().flat_map(|x| x.raw.iter().copied()).collect();
            let mut signing = vec![5];
            signing.extend(encode_list(&payload));
            let hash = keccak256(signing);
            let recovery = recover(r, s, parity, hash);
            let (authority, error) = match recovery {
                Ok(a) => (Some(a), None),
                Err(e) => (
                    None,
                    Some(err("TYPE_4_INVALID_AUTHORITY_SIGNATURE", e.message)),
                ),
            };
            out.push(json!({"chainId":q(chain),"address":addr,"nonce":q(nonce),"yParity":q(parity),"v":q(parity),"r":q(r),"s":q(s),"signingHash":hx(hash.as_slice()),"signer":authority,"authority":authority,"recoveryError":error}));
        }
        Ok(json!(out))
    };
    inner().map_err(|e| {
        if e.exception == "TransactionException.TYPE_4_INVALID_AUTHORITY_SIGNATURE" {
            e
        } else {
            err("TYPE_4_INVALID_AUTHORIZATION_FORMAT", e.message)
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use k256::ecdsa::SigningKey;
    fn blob(b: &[u8]) -> Vec<u8> {
        if b.len() == 1 && b[0] < 128 {
            return b.to_vec();
        }
        if b.len() < 56 {
            let mut v = vec![128 + b.len() as u8];
            v.extend(b);
            v
        } else {
            let mut v = vec![184, b.len() as u8];
            v.extend(b);
            v
        }
    }
    fn key() -> SigningKey {
        SigningKey::from_bytes((&[1u8; 32]).into()).unwrap()
    }
    fn signed(kind: u8, mut fields: Vec<Vec<u8>>) -> Vec<u8> {
        let mut signing = if kind == 0 { vec![] } else { vec![kind] };
        let mut payload = fields.concat();
        if kind == 0 {
            payload.extend([1, 128, 128])
        }
        signing.extend(encode_list(&payload));
        let (sig, rec) = key()
            .sign_prehash_recoverable(keccak256(signing).as_slice())
            .unwrap();
        let b = sig.to_bytes();
        fields.push(encode_uint(U256::from(
            if kind == 0 { 37 } else { 0 } + rec.to_byte(),
        )));
        fields.push(encode_uint(U256::from_be_slice(&b[..32])));
        fields.push(encode_uint(U256::from_be_slice(&b[32..])));
        let mut out = if kind == 0 { vec![] } else { vec![kind] };
        out.extend(encode_list(&fields.concat()));
        out
    }
    fn auth() -> Vec<u8> {
        let f = vec![vec![1], blob(&[9; 20]), vec![128]];
        let mut msg = vec![5];
        msg.extend(encode_list(&f.concat()));
        let (sig, rec) = key()
            .sign_prehash_recoverable(keccak256(msg).as_slice())
            .unwrap();
        let b = sig.to_bytes();
        let mut p = f.concat();
        p.extend(encode_uint(U256::from(rec.to_byte())));
        p.extend(encode_uint(U256::from_be_slice(&b[..32])));
        p.extend(encode_uint(U256::from_be_slice(&b[32..])));
        encode_list(&p)
    }
    fn fields(kind: u8) -> Vec<Vec<u8>> {
        let to = blob(&[2; 20]);
        let gas = encode_uint(U256::from(21000));
        match kind {
            0 => vec![vec![128], vec![1], gas, to, vec![128], vec![128]],
            1 => vec![
                vec![1],
                vec![128],
                vec![1],
                gas,
                to,
                vec![128],
                vec![128],
                vec![192],
            ],
            _ => {
                let mut f = vec![
                    vec![1],
                    vec![128],
                    vec![1],
                    vec![2],
                    gas,
                    to,
                    vec![128],
                    vec![128],
                    vec![192],
                ];
                if kind == 3 {
                    f.extend([vec![1], encode_list(&blob(&[1; 32]))])
                }
                if kind == 4 {
                    f.push(encode_list(&auth()))
                }
                f
            }
        }
    }
    #[test]
    fn every_type_recovers_exact_key() {
        let pubkey = key().verifying_key().to_encoded_point(false);
        let h = keccak256(&pubkey.as_bytes()[1..]);
        let sender = hx(&h[12..]);
        for kind in 0..=4 {
            let raw = signed(kind, fields(kind));
            let d = decode(&raw).unwrap();
            assert_eq!(d["sender"], sender);
            assert_eq!(d["hash"], hx(keccak256(&raw).as_slice()));
            assert_eq!(d["chainId"], "0x1");
            if kind == 4 {
                assert_eq!(d["authorizationList"][0]["authority"], sender)
            }
        }
    }
    #[test]
    fn legacy_unprotected_and_chain_id_preservation() {
        let f = fields(0);
        let signing = encode_list(&f.concat());
        let (sig, rec) = key()
            .sign_prehash_recoverable(keccak256(signing).as_slice())
            .unwrap();
        let b = sig.to_bytes();
        let mut payload = f.concat();
        payload.extend(encode_uint(U256::from(27 + rec.to_byte())));
        payload.extend(encode_uint(U256::from_be_slice(&b[..32])));
        payload.extend(encode_uint(U256::from_be_slice(&b[32..])));
        let d = decode(&encode_list(&payload)).unwrap();
        assert!(d["chainId"].is_null());
        assert_eq!(d["v"], q(U256::from(27 + rec.to_byte())));
        let mut f = fields(2);
        f[0] = encode_uint(U256::from(999));
        assert_eq!(decode(&signed(2, f)).unwrap()["chainId"], "0x3e7");
    }
    #[test]
    fn root_contract_full_words_and_structural_limits() {
        for kind in 1..=4 {
            let mut f = fields(kind);
            f[0] = encode_uint(U256::MAX);
            let fee_index = if kind == 1 { 2 } else { 3 };
            f[fee_index] = encode_uint(U256::MAX);
            let gas_index = if kind == 1 { 3 } else { 4 };
            f[gas_index] = encode_uint(U256::from(u64::MAX));
            f[gas_index + 2] = encode_uint(U256::MAX);
            let d = decode(&signed(kind, f)).unwrap();
            assert_eq!(d["chainId"], q(U256::MAX));
            assert_eq!(
                d[if kind == 1 {
                    "gasPrice"
                } else {
                    "maxFeePerGas"
                }],
                q(U256::MAX)
            );
            assert_eq!(d["value"], q(U256::MAX));
            assert_eq!(d["gasLimit"], "0xffffffffffffffff");
            assert_eq!(d["type"], q(U256::from(kind)));
            assert!(d.get("chain_id").is_none());
        }
        for kind in 0..=4 {
            let mut f = fields(kind);
            f[if kind == 0 { 0 } else { 1 }] = encode_uint(U256::from(u64::MAX) + U256::from(1));
            assert_eq!(
                decode(&signed(kind, f)).unwrap_err().exception,
                "TransactionException.NONCE_OVERFLOW"
            );
            let mut f = fields(kind);
            f[if kind == 0 {
                2
            } else if kind == 1 {
                3
            } else {
                4
            }] = encode_uint(U256::from(u64::MAX) + U256::from(1));
            assert_eq!(
                decode(&signed(kind, f)).unwrap_err().exception,
                "TransactionException.GASLIMIT_OVERFLOW"
            );
        }
    }
    #[test]
    fn signature_rejections() {
        let order = U256::from_str_radix(
            "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
            16,
        )
        .unwrap();
        let hash = keccak256(b"test");
        for (r, s, v) in [
            (U256::ZERO, U256::from(1), U256::ZERO),
            (order, U256::from(1), U256::ZERO),
            (U256::from(1), order - U256::from(1), U256::ZERO),
            (U256::from(1), U256::from(1), U256::from(2)),
        ] {
            assert!(recover(r, s, v, hash).is_err())
        }
    }
    #[test]
    fn canonical_and_width_checks() {
        for raw in [
            &[0xf8, 0x00][..],
            &[0xc1, 0x81][..],
            &[0xc0, 0][..],
            &[0xff, 255, 255, 255, 255, 255, 255, 255, 255][..],
        ] {
            assert!(decode(raw).is_err())
        }
        let mut f = fields(0);
        f[0] = vec![0];
        assert!(
            decode(&signed(0, f))
                .unwrap_err()
                .exception
                .contains("LEADING_ZEROS_NONCE")
        );
        let mut f = fields(0);
        f[4] = blob(&[1; 33]);
        assert!(
            decode(&signed(0, f))
                .unwrap_err()
                .exception
                .contains("VALUE_OVERFLOW")
        );
    }
    #[test]
    fn semantic_limits_are_not_wire_errors() {
        let mut f = fields(0);
        f[0] = encode_uint(U256::from(u64::MAX));
        f[1] = blob(&[1; 40]);
        f[2] = vec![128];
        assert!(decode(&signed(0, f)).is_ok());
        let mut f = fields(4);
        f[9] = vec![192];
        assert!(decode(&signed(4, f)).is_ok());
    }
    #[test]
    fn authorization_crypto_failure_is_explicit() {
        let mut f = fields(4);
        let a = vec![
            vec![1],
            blob(&[9; 20]),
            vec![128],
            vec![128],
            vec![128],
            vec![128],
        ];
        f[9] = encode_list(&encode_list(&a.concat()));
        let d = decode(&signed(4, f)).unwrap();
        assert!(d["authorizationList"][0]["authority"].is_null());
        assert!(d["authorizationList"][0]["recoveryError"].is_object());
    }
    #[test]
    fn no_panics_for_short_arbitrary_input() {
        let mut state = 1234567u64;
        for len in 0..256 {
            for _ in 0..32 {
                let b: Vec<u8> = (0..len)
                    .map(|_| {
                        state ^= state << 13;
                        state ^= state >> 7;
                        state ^= state << 17;
                        state as u8
                    })
                    .collect();
                let _ = decode(&b);
            }
        }
    }
}
