//! Crypto-only process boundary. No EVM opcode execution occurs here.
use evm2::{interpreter::GasTracker, precompiles::*};
use std::io::{Read, Write};
fn response(status: u8, gas: u64, bytes: &[u8]) -> Vec<u8> {
    let mut out = vec![status];
    out.extend_from_slice(&gas.to_be_bytes());
    out.extend_from_slice(bytes);
    out
}
fn execute(input: &[u8]) -> Vec<u8> {
    if input.len() < 12 { return response(2, 0, &[]); }
    let address = u32::from_be_bytes(input[..4].try_into().unwrap());
    let mut gas = GasTracker::new(u64::from_be_bytes(input[4..12].try_into().unwrap()));
    let f: fn(&[u8], &mut GasTracker) -> PrecompileResult = match address {
        1 => secp256k1::run, 2 => hash::run_sha256, 3 => hash::run_ripemd160,
        4 => identity::run, 5 => modexp::run_osaka,
        6 => bn254::add::run_istanbul, 7 => bn254::mul::run_istanbul,
        8 => bn254::pair::run_istanbul, 9 => blake2::run,
        10 => kzg_point_evaluation::run,
        11 => bls12_381::g1_add::run, 12 => bls12_381::g1_msm::run,
        13 => bls12_381::g2_add::run, 14 => bls12_381::g2_msm::run,
        15 => bls12_381::pairing::run, 16 => bls12_381::map_fp_to_g1::run,
        17 => bls12_381::map_fp2_to_g2::run, 256 => secp256r1::run_osaka,
        _ => return response(2, 0, &[]),
    };
    match f(&input[12..], &mut gas) {
        Ok(out) => response(0, gas.remaining(), out.bytes()),
        Err(PrecompileError::Fatal(_)) => response(2, 0, &[]),
        Err(_) => response(1, 0, &[]),
    }
}
fn main() {
    let mut input = Vec::new();
    let output = if std::io::stdin().read_to_end(&mut input).is_err() {
        response(2, 0, &[])
    } else {
        std::panic::catch_unwind(|| execute(&input)).unwrap_or_else(|_| response(2, 0, &[]))
    };
    if std::io::stdout().write_all(&output).is_err() { std::process::exit(1); }
}
