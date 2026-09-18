# Strict exception matching

Pinned EEST permits several exception names to match one actual client error. It does not require choosing a name using the fixture expectation.

All references below use execution-specs commit `7341820b5b394b1934dfe7bb6f621fcdab7baf7f`:

- [Exception mapper](https://github.com/ethereum/execution-specs/blob/7341820b5b394b1934dfe7bb6f621fcdab7baf7f/packages/testing/src/execution_testing/exceptions/exception_mapper.py#L63): collects every matching substring/regex result; membership accepts an expected alternative in that actual list.
- [Strict verification](https://github.com/ethereum/execution-specs/blob/7341820b5b394b1934dfe7bb6f621fcdab7baf7f/packages/testing/src/execution_testing/specs/helpers.py#L193): uses that membership while enforcing success/rejection agreement.
- [Geth mapping](https://github.com/ethereum/execution-specs/blob/7341820b5b394b1934dfe7bb6f621fcdab7baf7f/packages/testing/src/execution_testing/client_clis/clis/geth.py#L40): floor errors match the specific floor entry and the generic intrinsic regex at line 185.
- [Reth mapping](https://github.com/ethereum/execution-specs/blob/7341820b5b394b1934dfe7bb6f621fcdab7baf7f/packages/testing/src/execution_testing/client_clis/clis/reth.py#L66): also maps the floor error to both names.

Bend reason 20 remains the precise floor-gas failure. Its fixed serialization is the set `{INTRINSIC_GAS_BELOW_FLOOR_GAS_COST, INTRINSIC_GAS_TOO_LOW}`. Reason 8 has only the generic name. All names have the `TransactionException.` prefix. Unknown reasons and host errors never receive a consensus rejection label.

The runner compares this actual set with expected alternatives, separately preserving success/rejection agreement, state root, logs hash, and optional output checks. Neither fixture identifiers nor expected values reach Bend validation or influence the actual alias set.

The native rejection run verifies all 933 expected-rejection fixtures with these rules and exact state/log commitments. Before applying the pinned mapper contract, 55 correctly rejected fixtures failed only because their expectation used the generic intrinsic name.
