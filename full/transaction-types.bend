import Base
import ../evmword.bend as W

# Decoded transaction envelope. kind is the EIP transaction type 0..4.
# sender is supplied by trusted signature recovery over the signed envelope.
# Authorization.authority is the trusted recovery result (None = invalid).
# Scalar/parity, chain-id, nonce and state checks remain Bend responsibilities.
# Addresses must be canonical 160-bit words; data elements must be bytes.
# Legacy/type1 fee_cap and tip both carry gas_price; type2..4 carry the
# max_fee_per_gas and max_priority_fee_per_gas respectively.
# Canonical absent fields: legacy access_list empty; types0..2/4 blob fields
# empty/zero; types0..3 authorizations empty. Typed chainid is Some.
# Nat gas is a host-bounded representation (2^48-1), not an EELS consensus cap.

type Access is Data:
  Access{address: W.Word, keys: +List<W.Word>}

def Access.address(x: Access) -> W.Word:
  match x:
    case Access{address, keys}:
      address

def Access.keys(x: Access) -> +List<W.Word>:
  match x:
    case Access{address, keys}:
      keys

type Authorization is Data:
  Auth{chainid: W.Word, address: W.Word, nonce: W.Word, parity: U32, r: W.Word, s: W.Word, authority: +Maybe<W.Word>}

def Authorization.chainid(x: Authorization) -> W.Word:
  match x:
    case Auth{chainid, address, nonce, parity, r, s, authority}:
      chainid

def Authorization.address(x: Authorization) -> W.Word:
  match x:
    case Auth{chainid, address, nonce, parity, r, s, authority}:
      address

def Authorization.nonce(x: Authorization) -> W.Word:
  match x:
    case Auth{chainid, address, nonce, parity, r, s, authority}:
      nonce

def Authorization.parity(x: Authorization) -> U32:
  match x:
    case Auth{chainid, address, nonce, parity, r, s, authority}:
      parity

def Authorization.r(x: Authorization) -> W.Word:
  match x:
    case Auth{chainid, address, nonce, parity, r, s, authority}:
      r

def Authorization.s(x: Authorization) -> W.Word:
  match x:
    case Auth{chainid, address, nonce, parity, r, s, authority}:
      s

def Authorization.authority(x: Authorization) -> +Maybe<W.Word>:
  match x:
    case Auth{chainid, address, nonce, parity, r, s, authority}:
      authority

type Transaction is Data:
  Tx{kind: U32, sender: W.Word, nonce: W.Word, gas: Nat, to: +Maybe<W.Word>, value: W.Word, data: +List<U32>, chainid: +Maybe<W.Word>, fee_cap: W.Word, tip: W.Word, blob_fee_cap: W.Word, blobhashes: +List<W.Word>, access_list: +List<Access>, authorizations: +List<Authorization>}

def Transaction.kind(x: Transaction) -> U32:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      kind

def Transaction.sender(x: Transaction) -> W.Word:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      sender

def Transaction.nonce(x: Transaction) -> W.Word:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      nonce

def Transaction.gas(x: Transaction) -> Nat:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      gas

def Transaction.to(x: Transaction) -> +Maybe<W.Word>:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      to

def Transaction.value(x: Transaction) -> W.Word:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      value

def Transaction.data(x: Transaction) -> +List<U32>:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      data

def Transaction.chainid(x: Transaction) -> +Maybe<W.Word>:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      chainid

def Transaction.fee_cap(x: Transaction) -> W.Word:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      fee_cap

def Transaction.tip(x: Transaction) -> W.Word:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      tip

def Transaction.blob_fee_cap(x: Transaction) -> W.Word:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      blob_fee_cap

def Transaction.blobhashes(x: Transaction) -> +List<W.Word>:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      blobhashes

def Transaction.access_list(x: Transaction) -> +List<Access>:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      access_list

def Transaction.authorizations(x: Transaction) -> +List<Authorization>:
  match x:
    case Tx{kind, sender, nonce, gas, to, value, data, chainid, fee_cap, tip, blob_fee_cap, blobhashes, access_list, authorizations}:
      authorizations

