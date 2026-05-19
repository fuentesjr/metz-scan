# Rubydex Project Index Spike

This spike evaluates Rubydex as an optional backend for future `metz-scan`
project-level analyzers. It does not affect normal `metz-scan scan` behavior.

Source context:

- Rubydex repo: https://github.com/Shopify/rubydex
- Rubydex announcement: https://railsatscale.com/2026-05-12-one-engine-many-tools/

## Setup

Rubydex is kept in an optional Bundler group.

```bash
bundle config set --local with rubydex
bundle install
```

Run the spike against the current workspace:

```bash
bundle exec ruby script/rubydex_spike.rb
```

Run it against a specific fixture path:

```bash
bundle exec ruby script/rubydex_spike.rb spec/fixtures/sample_app
```

Without the optional group, the spike exits with a clear message and normal
checks continue to run without Rubydex.

## Current Results

On this repo with Rubydex `0.2.3`:

```text
backend: rubydex
workspace: true
indexed_files: 95
declarations: 47808
ruby_documents: 2132
references_to RuboCop::Cop::Metz::Base: 12
diagnostics: 183
index_errors: 0
```

The workspace run finds `Minitest::Test` descendants from this repo and from
indexed dependencies, including `MetzScan::ProjectIndexTest`,
`MetzScan::Commands::ScanTest`, and the RuboCop cop tests.

The fixture-only run against `spec/fixtures/sample_app` is smaller and clean:

```text
backend: rubydex
workspace: false
indexed_files: 15
declarations: 53
ruby_documents: 16
diagnostics: 0
index_errors: 0
```

## TDD Evidence

- Red: forcing the old `Dir.pwd` workspace behavior makes
  `ProjectIndexWorkspaceTest#test_workspace_index_uses_requested_path_instead_of_current_directory`
  fail because `WorkspaceRootMarker` is missing.
- Green: `env BUNDLE_WITH=rubydex bundle exec ruby -Itest
  test/metz_scan/project_index_test.rb` passes with
  `ProjectIndex.build([workspace], backend: :rubydex, workspace: true)`.
- Guard: `bundle exec ruby script/rubydex_spike.rb` exits clearly when Rubydex
  is not enabled, preserving the optional dependency boundary.

## Feasibility Notes

- Rubydex can index this repo and the sample Rails fixture reliably.
- `index_workspace` is useful when dependency-aware questions matter, such as
  finding descendants of `Minitest::Test`.
- `index_all` is useful for bounded fixture/path analysis where dependency
  declarations are unnecessary.
- The adapter can query declarations, descendants, search results, diagnostics,
  and resolved constant references.
- Workspace indexing uses the requested project path rather than the process
  current directory.
- The first project analyzer should stay optional and explicit until runtime
  cost, diagnostics volume, and native-gem install behavior are better known.

## Experiment 2: Inheritance Descendants

`MetzScan::Analyzers::InheritanceDescendants` is an optional prototype analyzer
that consumes a `ProjectIndex` and reports descendants of configured base
classes or modules. It is not wired into `metz-scan scan`.

Run the spike against the current workspace:

```bash
bundle exec ruby script/inheritance_descendants_spike.rb RuboCop::Cop::Metz::Base
```

Current output with Rubydex `0.2.3`:

```text
backend: rubydex
workspace: true
base_name: RuboCop::Cop::Metz::Base
rule_id: MetzProject/DeepInheritanceTree
descendants: 9
  - MetzBaseTestCopDefaults
  - MetzBaseTestCopMetadata
  - MetzBaseTestCopOnSend
  - RuboCop::Cop::Metz::ClassesTooLong
  - RuboCop::Cop::Metz::ControllersTooManyDirectCollaborators
  - RuboCop::Cop::Metz::DemeterTrainWreck
  - RuboCop::Cop::Metz::MethodsTooLong
  - RuboCop::Cop::Metz::MethodsTooManyParameters
  - RuboCop::Cop::Metz::ViewsDeepNavigation
```

TDD evidence:

- Red: `bundle exec ruby -Itest
  test/metz_scan/analyzers/inheritance_descendants_test.rb` initially failed
  because the analyzer did not exist.
- Green: fake-index analyzer tests pass without Rubydex, and the Rubydex-backed
  fixture test passes with `env BUNDLE_WITH=rubydex`.
- Guard: `bundle exec ruby script/inheritance_descendants_spike.rb
  RuboCop::Cop::Metz::Base` exits clearly when Rubydex is not enabled.

Limitations:

- Locations currently use declaration paths only; line and column data are not
  exposed by the adapter yet.
- Bounded path analysis only reports descendants when the base declaration is
  indexed too. For example, `spec/fixtures/sample_app` has controllers that
  inherit from `ApplicationController`, but the fixture does not define
  `ApplicationController`.
