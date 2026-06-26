# Rubydex Project Index Spike

This spike evaluates Rubydex as an optional backend for future `metz-scan`
project-level analyzers. It does not affect normal `metz-scan scan` behavior.

Source context:

- Rubydex repo: <https://github.com/Shopify/rubydex>
- Rubydex announcement: <https://railsatscale.com/2026-05-12-one-engine-many-tools/>

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
bundle exec ruby script/rubydex_spike.rb test/fixtures/sample_app
```

Without the optional group, the spike exits with a clear message and normal
checks continue to run without Rubydex.

## Current Results

On this repo with Rubydex `0.2.5`:

```text
backend: rubydex
workspace: true
indexed_files: 5433
declarations: 49187
ruby_documents: 2192
minitest_test_descendants:
  - CopHelperTest
  - CopMetzControllersTooManyDirectCollaboratorsTest
  - ...
  - MetzScan::Commands::ScanProjectAnalyzerRunnerDeepInheritanceTest
  - MetzScan::ProjectIndexWorkspaceTest
  - RuboCopCopMetzMethodsTooManyParametersTest
metz_cop_declarations:
  - RuboCop::Cop::Metz::Base
  - RuboCop::Cop::Metz::ClassesTooLong
  - RuboCop::Cop::Metz::ControllersTooManyDirectCollaborators
  - RuboCop::Cop::Metz::DemeterTrainWreck
  - RuboCop::Cop::Metz::MetadataBoomProbe
  - RuboCop::Cop::Metz::MetadataLessProbe
  - RuboCop::Cop::Metz::MethodsTooLong
  - RuboCop::Cop::Metz::MethodsTooManyParameters
  - RuboCop::Cop::Metz::OnSendCsendBridge
  - RuboCop::Cop::Metz::ViewsDeepNavigation
references_to RuboCop::Cop::Metz::Base: 3
diagnostics: 187
index_errors: 0
```

The workspace run finds `Minitest::Test` descendants from this repo and from
indexed dependencies, including the `MetzScan::Commands::*` tests and the
RuboCop cop tests. The large `indexed_files` count is expected for workspace
indexing because Rubydex includes dependencies.

The fixture-only run against `test/fixtures/sample_app` is smaller and clean:

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
- Rubydex-backed project analyzers should stay opt-in until runtime cost,
  diagnostics volume, and native-gem install behavior are better known.

## Experiment 2: Inheritance Descendants

`MetzScan::Analyzers::InheritanceDescendants` is an optional project analyzer
that consumes a `ProjectIndex` and reports descendants of configured or
auto-discovered base classes or modules. It is wired into
`metz-scan scan --project-analyzers` as `MetzProject/DeepInheritanceTree`, but
only produces findings when the optional Rubydex-backed project index is
available.

Run the spike against the current workspace:

```bash
bundle exec ruby script/inheritance_descendants_spike.rb RuboCop::Cop::Metz::Base
```

Current output with Rubydex `0.2.5`:

```text
backend: rubydex
workspace: true
base_name: RuboCop::Cop::Metz::Base
rule_id: MetzProject/DeepInheritanceTree
descendants: 0
  (none)
```

The first-party cops now inherit directly from `RuboCop::Cop::Base` and compose
Metz helpers explicitly, so `RuboCop::Cop::Metz::Base` remains only as a
compatibility shim and no longer produces the dogfood inheritance finding.

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
- Auto-discovered candidates now filter Ruby core declarations and Rubydex
  synthetic declarations such as `Object` or `ApplicationRecord::<ApplicationRecord>`.
  When Rubydex exposes declaration kind, auto-discovery also limits roots to
  known class declarations. Auto-discovered roots must have a declaration path.
  Grouped output emits one offense at the base declaration and preserves
  descendant paths in project-analyzer metadata.
- Post-class-filter calibration still shows some framework-style roots that need
  triage before this analyzer can move closer to default output.
- Bounded path analysis only reports descendants when the base declaration is
  indexed too. For example, `test/fixtures/sample_app` has controllers that
  inherit from `ApplicationController`, but the fixture does not define
  `ApplicationController`.
- The scan integration uses auto-discovered indexed declarations as candidate
  roots with a conservative descendant threshold; the spike script still accepts
  an explicit base name for focused experiments.

## Experiment 3: Repeated Branching

`MetzScan::Analyzers::RepeatedBranching` is an optional prototype analyzer that
parses indexed or explicit Ruby files and groups repeated `case` expressions
with the same lexical decision and branch-value set, or repeated `if`/`elsif`
predicate chains with the same receiver and predicate set, across distinct Ruby
files. It is wired into
`metz-scan scan --project-analyzers` and remains experimental.

Run the spike against the library code:

```bash
bundle exec ruby script/repeated_branching_spike.rb lib
```

Current output without Rubydex enabled:

```text
backend: null
workspace: false
rule_id: MetzProject/RepeatedBranching
findings: 1
- format repeated across 2 files: json, sarif
  lib/metz_scan/commands/report.rb:72
  lib/metz_scan/commands/scan.rb:95
```

TDD evidence:

- Red: `bundle exec ruby -Itest
  test/metz_scan/analyzers/repeated_branching_test.rb` initially failed because
  the analyzer did not exist.
- Red: real-file script execution exposed ternary `if` nodes without
  `loc.keyword`; `test_ignores_ternary_if_nodes` reproduced that crash.
- Red: mixed `if`/`elsif` chains with unsupported conditions were initially
  reported after dropping the unsupported branch; a regression test now rejects
  the whole chain.
- Green: repeated `case`, unrelated-receiver, predicate-chain, explicit-path,
  ternary, and Rubydex-backed tests pass.
- Guard: `bundle exec ruby script/repeated_branching_spike.rb lib` runs with
  `backend: null`, so Rubydex remains optional for this AST-first prototype.

Limitations:

- Receiver grouping is lexical, not type-aware: `order.status`,
  `@order.status`, and `current_order.status` are treated as separate decisions.
- Literal branch values keep their literal type in the grouping signature, so
  `"paid"` and `:paid` are not treated as the same branch value.
- The prototype only parses Ruby files, not ERB/HAML/SLIM templates.
- Rubydex context is advisory here; it supplies backend/index metadata when
  available but is not required for findings.

## Experiment 4: Service-Object Soup

`MetzScan::Analyzers::ServiceSoup` is an optional prototype analyzer that
parses indexed or explicit Ruby files and reports workflow methods that
coordinate several service-style calls. It is wired into
`metz-scan scan --project-analyzers` as the first candidate for graduation.

The prototype recognizes constant-backed service calls:

```ruby
ValidateOrder.call(order)
CapturePayment.new(order).call
```

Run the spike against the library code:

```bash
bundle exec ruby script/service_soup_spike.rb lib
```

Run it against the tiny service-heavy Rails fixture:

```bash
bundle exec ruby script/service_soup_spike.rb test/fixtures/service_soup_app
```

Current output without Rubydex enabled:

```text
backend: null
workspace: false
rule_id: MetzProject/ServiceSoup
findings: 0
```

Current output against the service-heavy fixture:

```text
backend: null
workspace: false
rule_id: MetzProject/ServiceSoup
findings: 1
- OrdersController#create coordinates 4 services: CapturePayment, ReserveInventory, SendReceipt, ValidateOrder
  test/fixtures/service_soup_app/app/controllers/orders_controller.rb:5 ValidateOrder.call(order)
  test/fixtures/service_soup_app/app/controllers/orders_controller.rb:6 ReserveInventory.call(order)
  test/fixtures/service_soup_app/app/controllers/orders_controller.rb:7 CapturePayment.new(order).call
  test/fixtures/service_soup_app/app/controllers/orders_controller.rb:8 SendReceipt.call(order)
```

Current output with Rubydex enabled:

```text
backend: rubydex
workspace: false
rule_id: MetzProject/ServiceSoup
findings: 0
```

TDD evidence:

- Red: `bundle exec ruby -Itest -Ilib
  test/metz_scan/analyzers/service_soup_test.rb` initially failed because the
  analyzer did not exist.
- Green: service-style calls, ordinary callable-object rejection,
  below-threshold filtering, explicit-path fallback, and Rubydex-backed tests
  pass.
- Guard: `bundle exec ruby script/service_soup_spike.rb lib` runs with
  `backend: null`, so Rubydex remains optional for this AST-first prototype.

Limitations:

- Workflow grouping is method-level only; top-level scripts and multi-method
  workflows are not modeled.
- Service detection is lexical: only `Constant.call(...)` and
  `Constant.new(...).call` count. It does not resolve whether the constants are
  true service objects.
- The default threshold is three distinct services in one method.
- Repeated calls to the same service do not satisfy the threshold by themselves.
- Service calls in nested class, module, or method scopes do not count toward
  the outer workflow.
- The prototype only parses Ruby files, not ERB/HAML/SLIM templates.
- Rubydex context is advisory here; it supplies backend/index metadata when
  available but is not required for findings.

Recommendation:

- Keep `MetzScan::Analyzers::ServiceSoup` behind the explicit
  `--project-analyzers` opt-in flag.
- Treat it as the first graduation candidate because the finding maps cleanly
  to method-level workflow orchestration and has a concrete Rails-shaped
  fixture.
- Keep using real Rails calibration before making it part of default scan
  output; see [project-analyzer-calibration.md](project-analyzer-calibration.md).

Reasons not to enable it by default yet:

- False-positive risk is still unknown. The analyzer recognizes lexical shapes
  such as `Constant.call(...)` and `Constant.new(...).call`; it does not prove
  those constants are true service objects.
- Fixture coverage is synthetic. The tiny Rails fixture proves the intended
  signal, but not behavior across jobs, mailers, interactors, query objects,
  policies, form objects, or application-specific command patterns.
- Default scan behavior should stay stable. Today `metz-scan scan` is a
  predictable RuboCop-backed wrapper; project analyzers change scope, runtime,
  output shape, and possibly exit behavior.
- Analyzer semantics still need tuning, including ignored namespaces and whether
  controllers and jobs should be weighted differently.
- Rubydex's role is unresolved. It may remain an advisory source of file/index
  metadata, or it may later help classify constants semantically.

## Project analyzer status

`metz-scan scan --project-analyzers` currently runs:

- `MetzProject/ServiceSoup` — candidate. Reports methods with at least three
  distinct service constants. This is the first analyzer to
  graduate from pure prototype status, while remaining opt-in.
- `MetzProject/RepeatedBranching` — experimental. Reports repeated lexical
  `case` decisions with the same branch-value set, or repeated `if`/`elsif`
  predicate chains with the same receiver and predicate set, across distinct
  Ruby files.
- `MetzProject/DeepInheritanceTree` — experimental. Reports indexed base
  classes or modules with at least three known descendants. It depends on the
  optional Rubydex-backed project index, so it contributes no findings when
  Rubydex is not enabled. Ruby core and Rubydex synthetic declarations are
  filtered from auto-discovered candidates. When declaration kind is available,
  auto-discovered roots are limited to classes and must have declaration paths;
  explicit configured roots can still inspect modules. Findings emit one primary offense at the base
  declaration while preserving descendant paths in metadata; the remaining
  calibration concern is framework-style root-selection quality.
- `MetzProject/PackageDependencyPressure` — experimental. Reports indexed
  namespaced classes or modules referenced from several files across multiple
  coarse packages outside their declaration package. It depends on the optional
  project index and emits one primary offense at the declaration path while
  preserving referring files and packages in metadata. The first slice only
  counts declarations under `app/` and `lib/`, ignores `spec/` and `test/`
  references, and skips broad top-level declarations when measuring pressure.
