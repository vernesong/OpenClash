# Configuration management regression tests

Run from the checkout root with Lua 5.1 and the LuCI runtime installed:

```sh
lua tests/config_profiles_test.lua .
lua tests/config_editor_test.lua .
lua tests/config_syntax_test.lua .
lua tests/resource_upload_test.lua .
```

The editor tests use isolated UCI fixtures under `/tmp/oc-profile-editor-test`,
mock configuration file writes, and intercept all service commands. They do
not update router configuration, download subscriptions, or restart services.

The profile tests cover local and subscription-only entries, inherited update
schedules, native automatic-update flags, duplicate records, exact updater destinations, and
write-policy decisions. Editor tests cover streamed and buffered writes,
validation-gated saving, enabling updates, save/apply boundaries, and legacy
editor/server-management bypasses. Provider tests cover the shared action
dispatcher and server-side MRS edit protection. Upload tests redirect every
filesystem operation to fixtures and cover binary providers, target allowlists,
protected configurations, and preservation of existing files on failure.

Optionally pass a language as the second editor-test argument to render native
CBI preview HTML and translated JavaScript into the fixture directory. A
matching compiled translation catalog can be placed there before rendering.
