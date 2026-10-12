# oixCloud managed configuration regression checks

Run these commands from the repository root:

```sh
lua5.1 tests/oix_managed_test.lua
lua5.1 tests/oix_controller_test.lua
node tests/oix_login_stream_test.js
python3 tests/oix_provider_sanitize_test.py
LUA=lua5.1 python3 tests/oix_managed_ui_test.py
python3 tests/oix_job_counter_test.py
```

Use Lua 5.1 for the LuCI controller checks. The YAML check also requires Ruby with its standard `yaml` and `json` libraries. The job-counter check requires Bash. Set `LUA` and `NODE` to select alternate runtimes for the UI check

The Lua suites load production code with isolated UCI, filesystem, HTTP, and subprocess fixtures. They verify observable state and responses without contacting accounts, restarting services, or writing router files. The JavaScript suite executes the production login transport function with an in-memory XMLHttpRequest. The Python suites run the production Ruby YAML transform against temporary synthetic configurations, execute extracted UI helpers and methods with Lua/DOM fixtures, and exercise the actual shell job-counter functions with isolated files and a fake service executable. The job-counter fixture stubs `flock`, so it does not test lock contention

These checks cover local request handling, account configuration transactions, hidden managed identifiers, login stream parsing, and removal of ordinary subscription credentials. Account settings checks cover shared operation locking, integer/flag validation, commit failures, empty responses, UI recovery, and text-only status messages. They do not establish actual OpenWrt process behavior, installation success, signed provider delivery, or node connectivity. Confirm those separately on a disposable OpenWrt device using an authorized test account

Managed configurations use an opaque UI identity. Source and provider caches are excluded from ordinary file/subscription actions, while deliberate full backups retain their original behavior. Login commits token, selection, and marker together, then verifies a nonempty managed provider and its use by a strategy group. Updating an inactive managed configuration only refreshes its local source; it does not switch or enable the current configuration. A failed activation restores the prior account/configuration state; restoration failures are reported explicitly. The downloaded core binary is not downgraded during configuration recovery
