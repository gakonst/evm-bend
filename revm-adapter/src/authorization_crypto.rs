//! Crypto-only EIP-7702 recovery. No nonce, chain, account or gas execution.
use revm::context_interface::transaction::SignedAuthorization;
use serde_json::{Value,json};
pub fn recover(v:&Value)->Value {
 let Some(xs)=v.get("authorizations").and_then(Value::as_array) else {return json!({"status":"error","reason":"authorizations must be an array"})};
 let authorities:Vec<Value>=xs.iter().map(|a| {
  let mut a=a.clone();
  let Some(o)=a.as_object_mut() else {return Value::Null};
  o.remove("signer");o.remove("authority");
  if o.contains_key("yParity") {o.remove("v");} else if let Some(p)=o.remove("v") {o.insert("yParity".into(),p);}
  serde_json::from_value::<SignedAuthorization>(a).ok().and_then(|s|s.recover_authority().ok()).map(|a|json!(format!("{a:#x}"))).unwrap_or(Value::Null)
 }).collect();
 json!({"mode":"recover_authorizations","authorities":authorities})
}
