# Sorbet Adoption Spike for Issue #26

Date: 2026-07-03

Issue: https://github.com/fuentesjr/metz-scan/issues/26

Disposable workspace: `/private/tmp/metz-scan-sorbet-spike-20260703-1643`

## Recommendation

Do not adopt Sorbet now.

The spike showed that a narrow, product-code-only static setup is possible, but
it did not demonstrate enough value to justify checking in the dependency,
generated RBI volume, cache/workflow knobs, and ongoing maintenance policy.

The best future path, if a concrete type-safety pain appears, is still narrow:

- Dev/test-only `sorbet` and `tapioca`.
- Generated RBIs checked in.
- `SRB_SKIP_GEM_RBIS=1` for typecheck commands, relying on Tapioca-generated
  gem RBIs instead of Sorbet wrapper auto-discovery.
- Product code only at first; ignore test fixtures and RuboCop test helpers.
- `# typed: true` only for simple value/helper files.
- No `sorbet-runtime` dependency in published runtime surfaces unless a
  specific runtime contract is worth the dependency and call overhead.

That path should wait until the project has a real type-related defect,
contract drift, or contributor/editor need that existing tests, RuboCop,
dogfood checks, and design review do not already cover.

## Baseline

Baseline commit:

- `60a7386 Record post-release feedback sweep`
- `main` was in sync with `origin/main` after push.
- CI run `28688031787` passed for
  `60a7386729f1d5d64c887efaa6f0401aedb2053e`.

Local baseline:

- Ruby: `ruby 4.0.1 (2026-01-13 revision e04267a14b) +PRISM [x86_64-darwin25]`
- Bundler: `4.0.8`
- Ruby files: 108 total.
- `lib/**/*.rb`: 89 files.
- `rubocop-metz/lib/**/*.rb`: 19 files.
- No `sorbet`, `tapioca`, or `sorbet-runtime` references in `Gemfile`,
  `*.gemspec`, or `rubocop-metz/*.gemspec`.
- Current bundle before the spike contained 21 gems, including `rubocop`,
  `rubocop-metz`, `metz-scan`, `minitest`, `rake`, `prism`, and optional
  `rubydex`.

Quality gates recorded:

- `bin/check_ci_parity` passed before pushing `60a7386`: 465 runs, 2026
  assertions, 0 failures, 0 errors, 6 skips; RuboCop inspected 196 files with
  no offenses; calibration smoke and guard scripts passed.
- `bin/check_dogfood` passed with the accepted project-analyzer baseline:
  0 findings.
- `bin/check_published_gem 0.4.0` passed again from a clean temporary consumer
  project.

## Current Sorbet Facts Used

Official docs checked during the spike:

- https://sorbet.org/docs/overview
- https://sorbet.org/docs/adopting
- https://sorbet.org/docs/static
- https://sorbet.org/docs/runtime
- https://sorbet.org/docs/rbi
- https://sorbet.org/docs/faq

Relevant facts:

- Sorbet has a static checker, `srb`, and runtime checking through
  `sorbet-runtime`.
- Current adoption docs recommend `sorbet`, `sorbet-runtime`, and `tapioca`
  for new setup, while warning that `sorbet-static-and-runtime` is not
  recommended for gems because it adds a runtime dependency.
- `# typed:` sigils are gradual. `typed: false` still catches syntax,
  unresolved constant, and signature errors; `typed: true` enables normal
  type errors.
- RBI files affect static typechecking and do not affect runtime directly.
- Tapioca is the current documented tool for gem and DSL RBI generation.
- `todo.rbi` is an escape hatch for unresolved constants, but leaving entries
  there can hide real errors.
- Runtime `sig`s add runtime checks and overhead.
- Official Sorbet FAQ still says Windows is not supported.

## Setup Results

The spike used a local clone under `/private/tmp`, not the working tree.

Added to the disposable `Gemfile` only:

```ruby
group :development, :test do
  gem "sorbet", require: false
  gem "tapioca", require: false
end
```

Dependency resolution:

- `bundle install` succeeded after network escalation.
- Installed `sorbet 0.6.13323`.
- Installed `tapioca 0.19.2`.
- Tapioca/Sorbet pulled `sorbet-runtime 0.6.13323`,
  `sorbet-static 0.6.13323`, and `sorbet-static-and-runtime 0.6.13323`
  into the dev/test bundle.
- Disposable `Gemfile.lock` grew to 151 lines.

Tapioca initialization:

- First sandboxed `bundle exec tapioca init` created the config files, then
  failed to fetch RBI annotations from GitHub because sandbox DNS was blocked.
- Retried with network escalation and it succeeded.
- Generated 34 RBI files under `sorbet/rbi`.
- Generated RBI line count: 165,751.
- Generated gem RBIs: 31 files.
- Generated central annotation RBIs: 2 files, for `minitest` and `rainbow`.
- Generated `todo.rbi`: 25 lines.
- Total generated setup files, excluding vendored bundle contents: 38 files
  including `bin/tapioca`, `sorbet/config`, Tapioca config, RBIs, and
  `.gitattributes` files.

`todo.rbi` unresolved constants were almost entirely fixture/sample app names:

- `ActiveRecord::Base`
- `ApplicationController`
- `Rails`
- sample controller service constants
- sample Spree seed constants

That matters because these entries are not product-layer types. They would need
policy and review if committed, otherwise the TODO RBI can mask fixture typos or
load-order mistakes.

## Typecheck Results

Default `bundle exec srb tc` was not immediately usable in the temp workspace:

- Sorbet tried to write cache data under `/Users/sal/.cache/sorbet`, which was
  not writable from the sandbox.
- Sorbet wrapper gem-RBI discovery then failed while evaluating Bundler with
  `undefined method 'filter_map'`.

The useful typecheck command was:

```sh
HOME=/private/tmp/metz-scan-sorbet-home-20260703-1643 \
SRB_SKIP_GEM_RBIS=1 \
bundle exec srb tc
```

`SRB_SKIP_GEM_RBIS=1` avoids the wrapper's automatic gem-RBI discovery and uses
the RBIs generated by Tapioca instead.

Initial static results:

- With the generated default `sorbet/config`, `srb tc` reported 15 errors.
- All 15 errors came from Rails-like sample fixtures in `test/fixtures`,
  mostly classes inheriting from unresolved fixture superclass TODO constants
  declared as modules.
- After ignoring `test/fixtures/`, 2 errors remained in `rubocop-metz/test`
  for `HelperFixtureCop`.
- After ignoring `test/` and `rubocop-metz/test/`, product-code-only typecheck
  passed.

Disposable product-code-only config:

```text
--dir
.
--ignore=tmp/
--ignore=test/
--ignore=test/fixtures/
--ignore=rubocop-metz/test/
--ignore=vendor/
--parser=prism
```

Steady-state typecheck time for the green product-code-only setup:

- `real 0.45`
- `user 0.58`
- `sys 0.14`

This suggests the checker itself is not the runtime problem. The maintenance
cost is in setup, generated RBIs, command environment, and scope policy.

## Tapioca Command Results

After initialization:

```sh
bundle exec tapioca gems
```

Result:

- Passed.
- Reported no gem RBI changes.

```sh
bundle exec tapioca dsl
```

Result:

- Exited nonzero.
- Loaded DSL extension classes, Rails application, and DSL compiler classes.
- Reported that no classes/modules could be matched for RBI generation.

For the current repo shape, DSL generation did not produce useful product-layer
output.

## Candidate File Evaluation

Five product-layer candidates were raised in the disposable clone:

- `lib/metz_scan/analyzers/occurrence.rb`
- `lib/metz_scan/analyzers/ruby_file_enumerator.rb`
- `lib/metz_scan/analyzers/project_analyzer_triage.rb`
- `lib/metz_scan/commands/scan/offense_extractor.rb`
- `lib/metz_scan/commands/scan/sarif_severity.rb`

Raising all five to `# typed: true` produced 13 errors:

- `ProjectAnalyzerTriage`: 10 errors.
  - Sorbet did not understand the mixin receiver shape.
  - It reported `self.class` and `index` as missing methods on the module.
  - It rejected dynamic constant reads such as
    `self.class::PROJECT_ANALYZER_STATUS`.
- `OffenseExtractor`: 3 errors.
  - Sorbet required explicit `Kernel.Array` and `Kernel.raise` style calls
    inside the module.

The clean `# typed: true` subset:

- `Occurrence`
- `RubyFileEnumerator`
- `SarifSeverity`

With only those three files at `# typed: true`, typecheck passed with no
`T.cast`, `T.must`, `T.unsafe`, or `T.untyped` escapes.

Interpretation:

- Sorbet works best here on already-small, mostly pure helpers.
- Those helpers are also already well covered by tests and have little dynamic
  surface area, so the incremental bug-catching value is low.
- The more interesting reusable mixin and JSON shape code starts needing code
  or RBI accommodation before Sorbet provides useful signal.

## Runtime Signature Probe

One real `sig` probe was applied to `SarifSeverity` in the disposable clone.

Required code surface:

- `require "sorbet-runtime"`
- `extend T::Sig`
- `sig` blocks for `level_for` and `highest_level`
- `T.untyped` for permissive severity input, because the current helper
  intentionally accepts anything coercible with `to_s`

Result:

- `srb tc` passed.
- Runtime smoke passed:
  - `level_for(:fatal)` returned `error`.
  - `highest_level(["info", "warning"])` returned `warning`.

Interpretation:

- Runtime signatures work technically.
- They do not clarify this helper enough to justify adding a runtime dependency
  to published code today.
- If signatures are wanted later without runtime dependency, prefer RBI-only
  signatures or keep signatures out of shipped files until there is an explicit
  `sorbet-runtime` policy.

## Value Assessment

Sorbet did not find a real issue in this spike.

It did find scope/setup facts:

- Test fixtures need to be excluded or typed intentionally.
- `todo.rbi` would include sample app constants that need review.
- Dynamic mixins and dynamic constants are likely friction points.
- Some module helper idioms need Sorbet-specific explicit Kernel calls.

Those are useful findings, but they mostly describe adoption cost rather than
new product correctness signal.

The existing gates already cover the main current risks:

- Minitest catches behavior.
- RuboCop and custom cops catch style/design rule drift.
- `bin/check_dependency_direction` catches architecture dependency drift.
- `bin/check_dogfood` catches project-analyzer self-application drift.
- `bin/check_ci_parity` catches CI/local drift before push.
- The design review workflow catches abstraction and coupling regressions.

## Cost Assessment

Concrete costs observed:

- At least 38 new non-vendor setup/generated files.
- 165,751 generated RBI lines.
- Dev/test bundle growth from 21 baseline gems to 37 installed gems.
- `sorbet-runtime` appears in the dev/test bundle even without adding it to a
  gemspec runtime dependency.
- Typecheck command needs environment policy:
  - writable cache/HOME or cache config
  - `SRB_SKIP_GEM_RBIS=1`
  - test fixture ignore policy
- `todo.rbi` needs active review because it can hide real constant errors.
- `tapioca dsl` currently adds no value and exits nonzero.
- Runtime `sig`s require a deliberate `sorbet-runtime` policy if placed in
  shipped code.

## Acceptance Criteria

- Baseline current checks recorded: complete.
- Sorbet/Tapioca setup attempted on a disposable local diff: complete.
- Initial `srb tc` output summarized: complete.
- At least 3 candidate product-layer files evaluated for `# typed: true`:
  complete, 5 attempted and 3 passed cleanly.
- Required RBIs and generated file churn summarized: complete.
- Runtime dependency implications documented: complete.
- CI/runtime cost estimated: complete, green product-code-only typecheck was
  about 0.45 seconds after setup.
- Clear recommendation written: complete, do not adopt now.
- Follow-up implementation issues: not created because adoption is not
  recommended.

## Follow-Up Policy

Do not add Sorbet to the repo from this spike.

Revisit only when one of these appears:

- A real type-related defect in analyzer/reporting contracts.
- A contributor/editor ergonomics problem that current tooling cannot solve.
- A desire to type a stable public API boundary before broader external
  contribution.
- A future analyzer refactor creates larger value objects where `typed: true`
  can guard meaningful contracts without dynamic RuboCop/Rails fixture noise.

If revisited, start with:

- `Occurrence`
- `RubyFileEnumerator`
- `SarifSeverity`

Avoid starting with:

- RuboCop cops.
- Test fixtures.
- `ProjectAnalyzerTriage` before defining a mixin/interface policy.
- `OffenseExtractor` before deciding whether Sorbet-specific Kernel call style
  is acceptable.
