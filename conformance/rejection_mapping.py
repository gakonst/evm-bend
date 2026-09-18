"""Serialization only: Bend validation reason -> pinned EEST exception.

Names: evm-bend-envelope/reference-snapshots/eest-exceptions.py and the
pinned corpus inventory. No transaction inspection or validation occurs here.
Unknown codes (including malformed decoded input 1 and host bound 100) must
remain unsupported/host errors, never be reported as a consensus rejection.
"""
REJECTION_EXCEPTIONS = {
    2: 'TransactionException.INVALID_CHAINID',
    3: 'TransactionException.NONCE_IS_MAX',
    4: 'TransactionException.INITCODE_SIZE_EXCEEDED',
    5: 'TransactionException.PRIORITY_GREATER_THAN_MAX_FEE_PER_GAS',
    6: 'TransactionException.TYPE_3_TX_CONTRACT_CREATION',
    7: 'TransactionException.TYPE_4_TX_CONTRACT_CREATION',
    8: 'TransactionException.INTRINSIC_GAS_TOO_LOW',
    9: 'TransactionException.GAS_ALLOWANCE_EXCEEDED',
    10: 'TransactionException.INSUFFICIENT_MAX_FEE_PER_GAS',
    11: 'TransactionException.INSUFFICIENT_MAX_FEE_PER_BLOB_GAS',
    12: 'TransactionException.NONCE_MISMATCH_TOO_LOW',
    13: 'TransactionException.GASLIMIT_PRICE_PRODUCT_OVERFLOW',
    14: 'TransactionException.INSUFFICIENT_ACCOUNT_FUNDS',
    15: 'TransactionException.SENDER_NOT_EOA',
    16: 'TransactionException.TYPE_3_TX_ZERO_BLOBS',
    17: 'TransactionException.TYPE_3_TX_BLOB_COUNT_EXCEEDED',
    18: 'TransactionException.TYPE_3_TX_INVALID_BLOB_VERSIONED_HASH',
    19: 'TransactionException.TYPE_4_EMPTY_AUTHORIZATION_LIST',
    20: 'TransactionException.INTRINSIC_GAS_BELOW_FLOOR_GAS_COST',
    21: 'TransactionException.NONCE_MISMATCH_TOO_HIGH',
    22: 'TransactionException.NONCE_OVERFLOW',
    24: 'TransactionException.INSUFFICIENT_ACCOUNT_FUNDS',
}


def rejection_exception(reason: int) -> str:
    """Return the exact exception; raise KeyError for an unmapped reason."""
    return REJECTION_EXCEPTIONS[reason]
