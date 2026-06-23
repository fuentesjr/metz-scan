# Rubydex MCP Dev-Tooling Spike

Issue: https://github.com/fuentesjr/metz-scan/issues/12

This spike evaluates the experimental Rubydex MCP server as agent-facing
maintenance tooling for `metz-scan`. It is separate from shipping Rubydex inside
`metz-scan`.

## Setup Tried

The Rubydex gem was already present through the optional Bundler group, but the
MCP server binary was not installed. The installed gem includes MCP server source
under:

```text
/Users/sal/.local/share/mise/installs/ruby/4.0.1/lib/ruby/gems/4.0.0/gems/rubydex-0.2.3-x86_64-darwin/rust/rubydex-mcp
```

Rust/Cargo was missing, so the spike installed Rust with `mise`:

```bash
mise install rust@latest
```

Then it built the MCP server into `/private/tmp` for a disposable trial:

```bash
mise exec rust@1.96.0 -- cargo install \
  --path /Users/sal/.local/share/mise/installs/ruby/4.0.1/lib/ruby/gems/4.0.0/gems/rubydex-0.2.3-x86_64-darwin/rust/rubydex-mcp \
  --root /private/tmp/rubydex-mcp-install \
  --target-dir /private/tmp/rubydex-mcp-target
```

Build result:

```text
Finished release profile [optimized] target(s) in 1m 57s
Installed executable /private/tmp/rubydex-mcp-install/bin/rubydex_mcp
```

The repo-local probe can be run after installing or building `rubydex_mcp`:

```bash
RUBYDEX_MCP_BIN=/private/tmp/rubydex-mcp-install/bin/rubydex_mcp \
  ruby script/rubydex_mcp_probe.rb
```

## MCP Tools Observed

The server registered six tools:

```text
get_declaration
search_declarations
get_descendants
find_constant_references
get_file_declarations
codebase_stats
```

The server instructions explicitly say to use these tools for Ruby structure and
use `grep`/`rg` for literal strings, comments, non-Ruby files, and content
search.

Probe stats for this repo:

```text
files: 110
declarations: 1329
definitions: 1365
constant_references: 2030
method_references: 3987
```

The MCP API tracks method references internally, but does not currently expose a
method-reference lookup tool.

## Representative Queries

### Where is `Metz::FileClassifier.view?` referenced?

Baseline `rg` answered this directly:

```bash
rg -n "FileClassifier\.view\?"
```

Production call sites:

- `rubocop-metz/lib/metz/erb_ruby_extractor.rb`
- `rubocop-metz/lib/metz/haml_ruby_extractor.rb`
- `rubocop-metz/lib/metz/slim_ruby_extractor.rb`
- `rubocop-metz/lib/rubocop/cop/metz/views_deep_navigation.rb`

MCP results:

- `search_declarations` found `Metz::FileClassifier#view?()`.
- `get_declaration` returned the method definition at
  `rubocop-metz/lib/metz/file_classifier.rb:31`.
- `find_constant_references` for `Metz::FileClassifier` returned 33 broader
  constant references.
- `find_constant_references` for `Metz::FileClassifier#view?()` returned zero
  references.

Verdict: `rg` wins for this exact method-call-reference query.

### Which cops inherit from `RuboCop::Cop::Metz::Base`?

Baseline `rg` found direct subclass syntax quickly, but indirect descendants
require manual interpretation:

```bash
rg -n "class \w+ <" rubocop-metz/lib/rubocop/cop/metz
```

MCP `get_descendants` found the transitive hierarchy and included
`RuboCop::Cop::Metz::ViewsDeepNavigation`, which inherits through
`DemeterTrainWreck`.

Observed MCP result also included `RuboCop::Cop::Metz::Base` itself in the
descendant list, so callers need to filter self out.

Verdict: MCP wins for transitive descendant discovery, with a small result
cleanup caveat.

### What tests cover `Metz/ViewsDeepNavigation`?

Baseline `rg` found unit tests, integration tests, config, and string references:

```bash
rg -n "ViewsDeepNavigation|views_deep_navigation|Metz/ViewsDeepNavigation" \
  rubocop-metz/test rubocop-metz/config rubocop-metz/lib test/fixtures
```

Important hits:

- `rubocop-metz/test/cop/metz/views_deep_navigation_test.rb`
- `rubocop-metz/test/integration/rails_aware_cops_fixture_integration_test.rb`
- `rubocop-metz/config/default.yml`
- `rubocop-metz/test/fixtures/views/*`

MCP results:

- `search_declarations` found `CopMetzViewsDeepNavigationTest` and its test
  methods.
- `find_constant_references` for
  `RuboCop::Cop::Metz::ViewsDeepNavigation` returned three constant references
  in the unit test file.
- `get_file_declarations` gave a useful structural list of test methods in
  `rubocop-metz/test/cop/metz/views_deep_navigation_test.rb`.
- MCP did not find string/config references like `Metz/ViewsDeepNavigation` in
  YAML or integration tests.

Verdict: `rg` wins for coverage discovery in this repo because RuboCop cop
identity flows through strings and config files, not only Ruby constants.

## Recommendation

Defer adopting Rubydex MCP as the default maintenance workflow, but keep it as a
promising optional spike tool.

Rubydex MCP is worth keeping in the toolbox for Ruby structural questions,
especially declaration discovery, file-level declaration summaries, and
transitive inheritance. It is not a replacement for `rg` in this repo because
method-call references and string/config references are central to RuboCop
plugin maintenance.

Recommended workflow for now:

- Use `rg` first for literal calls, cop names, config, test coverage, and public
  string identifiers.
- Use Rubydex MCP or the existing Rubydex Ruby scripts when the question is
  semantic Ruby structure, especially inheritance/descendants.
- Do not add Rubydex MCP as a required project dependency or default Codex MCP
  server yet.

Next useful trial:

- Install `rubydex_mcp` persistently.
- Wire it into Codex or Claude as an actual MCP server instead of using the
  protocol probe.
- Re-run a refactor-style task where transitive descendants or declaration
  details are on the critical path.
