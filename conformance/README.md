# Amsterdam conformance work in progress

The pinned release, archive digest and counts are in `corpus-manifest.json` and `../versions.json`. `corpus.py` verifies and extracts the official archive; `profile.py` summarizes input bounds. Large fixture archives, extracted fixtures and generated inventories are not committed.

`runner.py` retains the full denominator and distinguishes pass, fail, blocked, error and not_run. No full-corpus pass is currently claimed. `bend_adapter.py` integrates the Bend transaction entrypoint; signed transaction envelopes are currently blocked pending integration. Blockchain and standalone transaction adapters remain unfinished. Host limits must not be reported as consensus rejection. Resume currently checks fixture identity only: use fresh output files after implementation changes.

`test_transaction_integration.py` compares 22 decoded-envelope synthetic transactions against revm, including complete state and logs commitments, output and gas. The committed native/JS reports each show 22 cases with zero failures. These are not official signed-transaction fixture results.

Rust supplies crypto, authorization recovery and trie commitments, and serves as a differential oracle. EVM execution and transaction gas/accounting run in Bend. The current transaction wire format bounds total gas to 48 bits and inputs to 16 MiB; resolving applicable larger inputs is part of the 100% goal.

Run `python3 conformance/runner.py --help` for corpus runner options. Source checks and the prepared-frame build instructions are in the root README.
