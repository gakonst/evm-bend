use std::io::{self, BufRead, Write};
fn main() {
    let stdin = io::stdin();
    let mut out = io::BufWriter::new(io::stdout().lock());
    for line in stdin.lock().lines() {
        let result = (|| {
            let line = line.map_err(|e| e.to_string())?;
            let v: serde_json::Value = serde_json::from_str(&line).map_err(|e| e.to_string())?;
            if v.get("mode").and_then(|x| x.as_str()).unwrap_or("decode") != "decode" {
                return Err("mode must be decode".into());
            }
            let s = v
                .get("txbytes")
                .and_then(|x| x.as_str())
                .ok_or("txbytes must be a hex string")?;
            let raw = hex::decode(s.strip_prefix("0x").unwrap_or(s)).map_err(|e| e.to_string())?;
            Ok(match evm_bend_envelope::decode(&raw) {
                Ok(d) => {
                    serde_json::json!({"decoded":d,"pendingReason":"requiresBend: account state, nonce validity, chain context, gas, fees and execution are not checked"})
                }
                Err(e) => serde_json::json!({"error":e}),
            })
        })();
        let value=result.unwrap_or_else(|message:String|serde_json::json!({"error":{"category":"input","exception":null,"message":message}}));
        if writeln!(out, "{value}").and_then(|_| out.flush()).is_err() {
            break;
        }
    }
}
