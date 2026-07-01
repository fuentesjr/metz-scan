# Implementation Notes

## 2026-06-29: Post-release smoke and next analyzer plan

Task: verify the published `v0.3.0` gems from a clean consumer project, then
plan the next analyzer investment for `0.4.0`.

Scope boundaries:

- Use a clean temp consumer project outside this checkout for install smoke.
- Verify published packages rather than local path gems.
- Do not start a broad calibration loop.
- Do not change analyzer behavior in this pass.

Plan:

1. Create a temp consumer project with `metz-scan ~> 0.3.0` from GitHub
   Packages.
2. Install dependencies and confirm Bundler resolves `metz-scan` and
   `rubocop-metz` to `0.3.0`.
3. Run CLI smoke commands from the consumer bundle.
4. Scan a tiny local fixture to confirm the installed CLI can execute outside
   the repository checkout.
5. Record a narrow `0.4.0` analyzer plan with a predeclared threshold before
   any future candidate work.

Decisions:

- Treat nonzero scan exit as expected when the fixture intentionally reports
  offenses.
- Prefer a lightweight consumer smoke over another release-prep loop because
  the release is already tagged and published.
- Use `/private/tmp` for the consumer project so the install smoke runs outside
  the repository checkout and cannot inherit repo-local Bundler, RuboCop, path
  gem, or fixture-exclusion state. Repo-local `tmp/` remains the home for
  project-analyzer calibration artifacts.

Verification status:

- `bundle install` from the clean consumer project passed after invoking the
  managed Ruby 4.0.1 interpreter explicitly. The temp project otherwise fell
  back to macOS system Ruby/Bundler because it has no mise context.
- Bundler resolved and installed `metz-scan 0.3.0` and `rubocop-metz 0.3.0`
  from GitHub Packages into `vendor/bundle3`.
- `bundle exec metz-scan --version` printed `0.3.0`.
- `bundle exec ruby -e 'require "metz_scan/version"; require
  "rubocop/metz/version"; ...'` printed `0.3.0` for both gems.
- `bundle exec metz-scan rules` passed.
- `bundle exec metz-scan project-analyzers` passed and showed `ServiceSoup`
  and `RepeatedBranching` as default-output eligible, `DeepInheritanceTree` as
  validated opt-in, and both pressure analyzers as candidates.
- `bundle exec metz-scan scan app --format text` exited `1` as expected and
  reported the fixture's regular Metz finding plus the default
  `MetzProject/ServiceSoup` project-analyzer finding.

Tradeoffs and technical debt encountered:

- The clean temp project did not inherit this repository's mise-managed Ruby
  PATH, so naive `bundle install` used `/usr/bin/ruby` and old system Bundler.
  Future consumer smoke scripts should invoke the intended Ruby directly or
  create a local tool-version file in the temp project.
- `gem install` into an isolated `GEM_HOME` also passed, but Bundler is the
  stronger consumer proof because the README install path is Bundler-based.

## 0.4.0 analyzer plan

Goal: choose one analyzer investment with a narrow threshold before changing
detector behavior.

Recommended first slice:

1. Reconcile `MetzProject/NamespaceLeakPressure` calibration drift.
2. Use only `tmp/project-analyzer-calibration/apps` unless new targets are
   explicitly approved.
3. Record exact active checkout revisions before running anything.
4. Run only `NamespaceLeakPressure` over `app/` and `lib/` for the active
   checkouts.
5. Compare current medium-confidence namespace-boundary findings against the
   documented 2026-06-27 note.

Predeclared threshold:

- Pass only if the active calibration home shows at least three clear
  medium-confidence namespace-boundary true positives across at least two
  applications, with no high-volume medium-confidence output in any one
  application.
- Fail/defer if the active home still shows only the two known positives
  (`Badge::Trigger::PostRevision` and `Spree::Gateway::StripeSCA`) or if new
  medium findings are mostly shared namespace/API surface.

Decision branches:

- If the threshold passes, do a focused validation pass for
  `NamespaceLeakPressure` and update docs/tests/status accordingly.
- If the threshold fails, keep it candidate opt-in and switch the next
  `0.4.0` investment to either `PackageDependencyPressure` non-commerce
  evidence or a reporting/UX improvement for already validated analyzers.

Scope boundary:

- Do not change analyzer status, thresholds, or downranking rules until the
  evidence check is complete and the pass/fail result is written down.

## 2026-06-29: Automate consumer smoke and run analyzer evidence slice

Task: automate the post-release consumer smoke and run the `0.4.0`
`NamespaceLeakPressure` evidence slice.

Scope boundaries:

- Add a reusable release/check script for published gem smoke testing.
- Keep the script outside production Ruby; no analyzer behavior changes.
- Keep consumer smoke projects outside the repo checkout.
- Use only `tmp/project-analyzer-calibration/apps` for analyzer evidence.
- Stop after pass/fail evidence; do not start a validation loop.

Plan:

1. Add `bin/check_published_gem` to install the published gem into an isolated
   temp consumer project and run CLI smoke checks.
2. Make the script invoke the intended Ruby/Bundler explicitly and avoid
   printing GitHub Packages credentials.
3. Run the script against the published `0.3.0` package.
4. Record active calibration checkout revisions.
5. Run only `NamespaceLeakPressure` over active `app/` and `lib/` paths.
6. Compare findings to the predeclared threshold and record the decision.

Verification status:

- `bash -n bin/check_published_gem` passed.
- `bin/check_published_gem --help` passed.
- First sandboxed `bin/check_published_gem 0.3.0` run could not reach
  `rubygems.pkg.github.com`; reran with approved network access.
- `bin/check_published_gem 0.3.0` passed from an isolated temp consumer
  project under `/private/tmp`, outside this checkout.
- The script installed exact `metz-scan 0.3.0` and `rubocop-metz 0.3.0`,
  verified both runtime version constants, ran `rules` and
  `project-analyzers`, and scanned the fixture with the expected nonzero
  offense exit.
- After `reviewer: published-gem smoke diff` flagged Bundler shim portability
  and runtime credential exposure, `bin/check_published_gem 0.3.0` passed again
  with Bundler executed directly and credentials scoped to install only.
- `bundle exec rake` passed: 364 runs, 1466 assertions, 0 failures, 0 errors,
  2 skips.
- `bundle exec rubocop` passed: 154 files inspected, no offenses.
- `bin/check_dependency_direction` passed.
- `bin/check_sample_app_frozen` passed.
- `git diff --check` passed.
- `NamespaceLeakPressure` evidence slice passed mechanically and failed the
  predeclared promotion threshold.

Script decisions:

- Pin the smoke Gemfile to the exact requested version instead of a pessimistic
  version constraint so later patch releases do not satisfy an old-version
  smoke by accident.
- Run Bundler from the generated consumer project so the script cannot fall
  back to this repository's Gemfile.
- Use the chosen Ruby to invoke the adjacent Bundler executable so temp
  projects do not silently fall back to macOS system Ruby/Bundler via `PATH`,
  while executing Bundler directly so shell shims and wrapper scripts still
  work.
- Default the temp consumer project to `/private/tmp`, allow
  `PUBLISHED_GEM_SMOKE_TMPDIR` for unusual environments, and reject temp bases
  inside this repository.
- Keep GitHub Packages credentials process-local and redact the full
  credential plus token in install output.
- Do not keep GitHub Packages credentials in the runtime `bundle exec`
  environment after install.
- Validate the requested version string before embedding it in the temp path or
  generated Gemfile.

Agenticon review notes:

- `doc_reviewer: implementation notes` found no documentation drift.
- `reviewer: published-gem smoke diff` found two blocking hardening issues:
  Bundler wrapper portability and credential-bearing runtime environment. Both
  were addressed before commit.
- The reviewer also noted that a future fake-Bundler local test could lock down
  redaction, temp isolation, exact pinning, and cleanup without network access.

Active calibration checkouts:

- `chatwoot` `e86222034e39`
- `decidim` `b2001fa7c9d2` (`develop`)
- `discourse` `2115f1cac5f9` (`main`)
- `forem` `d9a393f1d502` (`main`)
- `mastodon` `34bbb4748223` (`main`)
- `openfoodnetwork` `be9d51ab32a6` (`master`)
- `solidus` `8d781ac742e3` (`main`)
- `spree` `7752652ef4ea` (`main`)

`NamespaceLeakPressure` slice over active `app/` and `lib/` paths:

| App | Paths | Total findings | Category mix | Medium namespace-boundary findings |
| --- | --- | ---: | --- | --- |
| `chatwoot` | `app`, `lib` | 9 | `shared_namespace`: 9 | 0 |
| `decidim` | `lib` | 0 | none | 0 |
| `discourse` | `app`, `lib` | 12 | `shared_namespace`: 11, `namespace_boundary`: 1 | 1: `Badge::Trigger::PostRevision` |
| `forem` | `app`, `lib` | 2 | `shared_namespace`: 2 | 0 |
| `mastodon` | `app`, `lib` | 2 | `shared_namespace`: 2 | 0 |
| `openfoodnetwork` | `app`, `lib` | 4 | `shared_namespace`: 3, `namespace_boundary`: 1 | 1: `Spree::Gateway::StripeSCA` |
| `solidus` | `lib` | 0 | none | 0 |
| `spree` | none | 0 | none | 0 |

Decision:

- Defer `NamespaceLeakPressure` promotion for `0.4.0`. The active calibration
  home still shows only the two known medium-confidence namespace-boundary
  positives across two applications, below the predeclared threshold of at
  least three clear positives across at least two applications.
- Keep the analyzer candidate opt-in and move the next `0.4.0` investment to
  either `PackageDependencyPressure` non-commerce evidence or release/reporting
  UX around already validated analyzers.

## 2026-06-29: PackageDependencyPressure evidence and release UX hardening

Task: run the `PackageDependencyPressure` non-commerce evidence slice and
harden release/reporting UX around already validated paths, using agenticons.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the only calibration fixture
  home.
- Do not promote or retune `PackageDependencyPressure` before evidence is
  recorded.
- Keep `NamespaceLeakPressure` candidate opt-in.
- Prefer local non-network release-smoke tests before any broader reporting UX
  changes.
- Keep agenticon delegation shallow and record review findings.

Change type: chore.

Verbatim task statement: "Ok go ahead and use agenticons for it."

Plan:

1. Spawn `helper_worker: PackageDependencyPressure evidence slice` for
   read-only calibration data.
2. Spawn `planner: release/reporting UX hardening` for the smallest valuable
   release-smoke/reporting implementation plan.
3. Add a local non-network test for `bin/check_published_gem` covering the
   credential redaction, exact version pinning, repo-external temp project, and
   runtime credential scoping noted by review.
4. Update the release checklist to include the published-gem smoke command
   after package publication.
5. Record `PackageDependencyPressure` pass/defer evidence and run the Ruby
   verification loop before committing.

Verification status:

- Red run: `ruby -Ilib -Itest test/metz_scan/check_published_gem_test.rb`
  failed before docs and harness fixes, proving the missing checklist assertion
  and exercising the fake Bundler path.
- Green run: `ruby -Ilib -Itest test/metz_scan/check_published_gem_test.rb`
  passed after the ambient Bundler credential fix: 4 runs, 36 assertions,
  0 failures, 0 errors.
- `bundle exec ruby -Ilib -Itest test/metz_scan/check_published_gem_test.rb`
  passed after style cleanup: 4 runs, 40 assertions, 0 failures, 0 errors.
- `bundle exec rake test:slow` passed after the Bundler environment harness
  fix: 68 runs, 318 assertions, 0 failures, 0 errors.
- `bundle exec rake` passed after the ambient Bundler credential fix: 368 runs,
  1506 assertions, 0 failures, 0 errors, 2 skips.
- Earlier full-suite run passed after the fixture refactor: 367 runs, 1489
  assertions, 0 failures, 0 errors, 2 skips.
- `bundle exec rubocop` passed: 155 files inspected, no offenses.
- `bin/check_dependency_direction` passed.
- `bin/check_sample_app_frozen` passed.
- `bash -n bin/check_published_gem` passed.
- `git diff --check` passed.
- `helper_worker: PackageDependencyPressure evidence slice` completed read-only
  calibration and recommended further targeted calibration rather than
  promotion.
- `planner: release/reporting UX hardening` recommended local non-network
  script coverage, slow-test grouping, checklist updates, and a narrow README
  pointer.
- `coding_worker: release smoke docs` updated only `RELEASE_CHECKLIST.md`,
  `.github/ISSUE_TEMPLATE/release_checklist.md`, and `README.md`.

Release-smoke hardening:

- Added `test/metz_scan/check_published_gem_test.rb` and
  `test/fixtures/check_published_gem/fake_bundle` with a fake shell-wrapper
  Bundler command, so the local test covers the wrapper portability issue found
  in the previous review.
- The test asserts exact Gemfile pinning, credential redaction for install
  output, no GitHub Packages credential in runtime `bundle exec` commands, temp
  project creation outside the repository, default cleanup, and rejection of a
  temp base inside the repository.
- After `reviewer: strategic design validation` raised a concern that ambient
  `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` could still leak into runtime commands,
  `bin/check_published_gem` now explicitly unsets that credential before
  runtime `bundle exec`, and the test covers both `GITHUB_PACKAGES_TOKEN` and
  `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` credential sources.
- The follow-up strategic review found that stripping only
  `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` was incomplete because
  `GITHUB_PACKAGES_TOKEN` and `GEM_CREDENTIALS` are also accepted credential
  sources. Runtime `bundle exec` now unsets all three, and the fake Bundler
  fixture fails if any supported auth source reaches runtime commands.
- Final strategic review verdict was clean. It carried one concern: the fake
  Bundler fixture strips ambient Bundler/Ruby variables itself, while the real
  script still allows broader variables such as `BUNDLE_GEMFILE` and
  `BUNDLE_BIN_PATH` through. Treat moving that broader environment scrubbing
  into `bin/check_published_gem` as the next hardening slice if the release
  smoke script continues to grow.
- Added the new subprocess test to the slow test group.
- Added a post-publish smoke step to both release checklists:
  `bin/check_published_gem X.Y.Z`.
- Added a brief README pointer that the command creates a clean temporary
  consumer project to verify packaged installs from GitHub Packages.

Active calibration checkouts:

- `chatwoot` `e86222034e39b9be4837fea0c058ad9a6a27aa72`
- `decidim` `b2001fa7c9d26fa7b43aadd2d05353d67e5da889` (`develop`)
- `discourse` `2115f1cac5f9ddc192c469acc025bb2def4f106a` (`main`)
- `forem` `d9a393f1d50209041a3aec0825b73b3ffd78760e` (`main`)
- `mastodon` `34bbb474822391445c8681ef898991e0c6e32e38` (`main`)
- `openfoodnetwork` `be9d51ab32a6fc6dc5fa25702d94ff94f93f79e6` (`master`)
- `solidus` `8d781ac742e38a83e417a4b90297b74f6266b070` (`main`)
- `spree` `7752652ef4ead1adb735d7c649614689e161b1a8` (`main`)

`PackageDependencyPressure` slice over active `app/` and `lib/` paths:

| App | Paths | Total findings | Category mix | Package-boundary findings |
| --- | --- | ---: | --- | --- |
| `chatwoot` | `app`, `lib` | 2 | `shared_dependency`: 2 | 0 |
| `decidim` | `lib` | 0 | none | 0 |
| `discourse` | `app`, `lib` | 10 | `shared_dependency`: 10 | 0 |
| `forem` | `app`, `lib` | 5 | `shared_dependency`: 5 | 0 |
| `mastodon` | `app`, `lib` | 3 | `package_boundary`: 1, `shared_dependency`: 2 | 1: `ActivityPub::TagManager` |
| `openfoodnetwork` | `app`, `lib` | 10 | `package_boundary`: 7, `shared_dependency`: 3 | 7: `OpenFoodNetwork::ScopeVariantToHub`, `Spree::LineItem`, `Spree::Money`, `Spree::Order`, `Spree::Product`, `Spree::User`, `Spree::Variant` |
| `solidus` | `lib` | 0 | none | 0 |
| `spree` | none | 0 | none | 0 |

Decision:

- Do not promote `PackageDependencyPressure` yet. The signal is real, but
  mostly concentrated in `openfoodnetwork`, with one additional `mastodon`
  boundary candidate.
- Keep the existing thresholds (`minimum_referring_files=12`,
  `minimum_referring_packages=5`) for now because the current triage separates
  broad shared APIs/infrastructure into `shared_dependency` low-confidence
  output.
- Next analyzer work should be targeted calibration for path coverage and
  boundary/noise review, especially because the active `spree` checkout has no
  top-level `app/` or `lib/` under the requested slice and was effectively
  unexercised.

## 2026-06-30: Targeted pressure calibration and smoke env isolation

Task: finish the next two big tasks: targeted `PackageDependencyPressure`
calibration and broader `bin/check_published_gem` environment isolation, using
agenticons.

Scope boundaries:

- Use only `tmp/project-analyzer-calibration/apps` for calibration evidence.
- Do not promote or retune analyzers until targeted evidence is recorded.
- Keep `NamespaceLeakPressure` and `PackageDependencyPressure` candidate
  opt-in unless evidence and review justify a later behavior change.
- Keep release-smoke changes limited to script environment isolation and the
  existing local non-network test/fixture.
- Keep `implementation-notes.md` current before and after verification.

Change type: chore.

Verbatim task statement: "Ok go ahead and do that now"

Plan:

1. Spawn `helper_worker: PackageDependencyPressure targeted calibration` for
   read-only path coverage and boundary/noise classification.
2. Spawn `coding_worker: published-gem smoke env isolation` for the script and
   fixture/test patch.
3. Integrate code-worker changes, run focused red/green proof where feasible,
   then run full local gates and the strategic design validation loop.
4. Record calibration evidence, design-review findings, and final decision.

Verification status:

- `coding_worker: published-gem smoke env isolation` moved script and fixture
  isolation to an explicit env allow-list and returned without running tests.
- Focused red check exposed that `env -i` omitted the fixture log env and that
  script-internal Ruby helpers still inherited polluted Bundler/Ruby variables.
  The script now uses `clean_ruby` for internal version, credential-file, and
  redaction Ruby calls.
- `ruby -Ilib -Itest test/metz_scan/check_published_gem_test.rb` passed:
  4 runs, 40 assertions, 0 failures, 0 errors.
- `bundle exec ruby -Ilib -Itest test/metz_scan/check_published_gem_test.rb`
  passed: 4 runs, 40 assertions, 0 failures, 0 errors.
- `bundle exec rubocop` passed: 155 files inspected, no offenses.
- `bash -n bin/check_published_gem` passed.
- `bash -n test/fixtures/check_published_gem/fake_bundle` passed.
- `bin/check_published_gem 0.3.0` passed against the published GitHub
  Packages gems with the isolated install/runtime environment.
- `ruby /Users/sal/Projects/strategic-software-design/scripts/validate.rb
  --type chore --task "Ok go ahead and do that now"` passed: slice tests,
  lint, and TODO gates passed; red/green skipped; warnings 0.
- `reviewer: strategic design validation` verdict was clean with no findings.
- `helper_worker: PackageDependencyPressure targeted calibration` completed
  read-only calibration and found no path-discovery change is indicated for
  the active `spree` fixture.

Release-smoke environment isolation:

- Runtime `bundle exec` commands now run under `env -i` with only script-owned
  `HOME`, `PATH`, `BUNDLE_APP_CONFIG`, and `BUNDLE_PATH`.
- Install still runs under `env -i`, adding only the script-owned
  `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` credential.
- Script-internal Ruby calls now run through `clean_ruby`, avoiding ambient
  Bundler/Ruby variables while still preserving the user home needed to read
  `~/.gem/credentials`.
- The fake Bundler fixture no longer strips ambient variables itself. It now
  fails runtime commands if polluted variables reach `bundle exec`, and asserts
  script-controlled `BUNDLE_APP_CONFIG`/`BUNDLE_PATH` point at the generated
  consumer project.

Targeted `PackageDependencyPressure` calibration:

- Active `spree` checkout root scan and nested-engine scan both produced the
  same 10 findings: 4 `shared_dependency`, 6 `package_boundary`.
- Nested Spree paths checked: `spree/spree/core`, `spree/spree/emails`,
  `spree/spree/admin`, `spree/spree/api`, and `spree/spree/lib`.
- Result equality: no root-only or nested-only findings. No path-discovery
  change is indicated by this run.
- `openfoodnetwork` still produced 10 findings: 3 `shared_dependency`, 7
  `package_boundary`.
- `mastodon` still produced 3 findings: 2 `shared_dependency`, 1
  `package_boundary`.

Classification decision:

- Promote/review candidate: `OpenFoodNetwork::ScopeVariantToHub` looks like a
  package-owned adapter participating in shared scoping behavior.
- Defer/downrank candidates: OpenFoodNetwork `Spree::*` core model findings
  (`Spree::Order`, `Spree::Variant`, `Spree::Product`, `Spree::Money`,
  `Spree::User`, `Spree::LineItem`) look more like broad shared domain/API
  surface than package-boundary pressure.
- Defer/downrank candidate: `ActivityPub::TagManager` in Mastodon reads as a
  broad shared URI/routing API surface rather than a package-boundary smell.
- Keep `PackageDependencyPressure` candidate opt-in. The targeted calibration
  found one strong candidate but not enough clean cross-app package-boundary
  signal to promote the analyzer.

## 2026-06-30: Package pressure downranking and calibration runner

Task: start on the next two big tasks and keep using agenticons.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep `PackageDependencyPressure` candidate opt-in.
- Limit analyzer behavior changes to downranking broad shared API/domain
  surfaces identified by current calibration evidence.
- Add a repeatable calibration/evidence runner without creating a broad
  framework or changing normal scan output.
- Keep agenticon delegation shallow and record findings.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and keep using agenticons"

Plan:

1. Spawn `planner: package pressure and calibration runner plan` for sequencing,
   test strategy, and scope checks.
2. Spawn `helper_worker: package pressure calibration reconnaissance` for
   read-only file/symbol evidence.
3. Add focused tests for calibrated `PackageDependencyPressure`
   shared-surface downranking cases.
4. Implement the narrow downranking classifier change.
5. Add a small calibration/evidence runner using existing project-analyzer
   APIs and repo-local fixture defaults.
6. Run focused red/green checks, local gates, strategic validation, and design
   review if required.

Verification status:

- `planner: package pressure and calibration runner plan` recommended two
  incremental slices: narrow analyzer downranking and an internal evidence
  runner, with focused tests and no analyzer promotion.
- `helper_worker: package pressure calibration reconnaissance` confirmed
  `SharedDependencyTriage` as the right downranking point, existing
  `ProjectAnalyzerRunner` APIs as the runner base, and
  `tmp/project-analyzer-calibration/apps` as the active fixture source.
- `coding_worker: project analyzer calibration runner` added the first runner
  implementation, bin wrapper, and tests. Parent integration split it into
  target discovery, summary, artifact writer, and Markdown renderer
  collaborators to satisfy local design/lint constraints.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/package_dependency_pressure_test.rb` failed before
  the classifier change for `Spree::*` shared domain surfaces and
  `ActivityPub::TagManager`, proving the missing downranking behavior.
- Green focused tests:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb` passed: 14
    runs, 97 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_package_dependency_test.rb`
    passed: 2 runs, 18 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`
    passed after the review-driven integration test addition: 5 runs, 19
    assertions, 0 failures, 0 errors.
- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  test/fixtures/sample_app` passed and printed a compact summary without
  writing artifacts.
- Focused `bundle exec rubocop` over touched Ruby/bin/test files passed: 10
  files inspected, no offenses.
- Full local gates:
  - `bundle exec rake` passed: 377 runs, 1567 assertions, 0 failures, 0
    errors, 2 skips.
  - `bundle exec rubocop` passed: 162 files inspected, no offenses.
  - `bin/check_dependency_direction` passed.
  - `bin/check_sample_app_frozen` passed.
  - `git diff --check` passed.
- Strategic validation before the review-driven integration test addition
  passed: slice tests, red/green, lint, and todo gates passed; warnings 0;
  review required.
- `reviewer: strategic design validation` returned a clean verdict with one
  concern: the new runner tests stubbed both the project index and analyzer
  runner and should include one fixture-backed real summarize path.
- Added a fixture-backed runner test against `test/fixtures/sample_app` without
  stubbing `ProjectIndex.build` or `ProjectAnalyzerRunner.project_findings_for`.
- Strategic validation after the review-driven test addition passed: slice
  tests, red/green, lint, and todo gates passed; warnings 0; review required.
- Follow-up `reviewer: strategic design validation` found one blocker: unused
  public `ProjectAnalyzerEvidenceRunner.markdown_for` widened the runner API
  without a caller. It also raised one concern that `TargetRun` still reaches
  concrete collaborators internally.
- Removed the unused `markdown_for` public method. Artifact writing now remains
  the only MarkdownRenderer caller.
- Final verification after blocker fix:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`
    passed: 5 runs, 19 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb` passed: 14
    runs, 97 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_package_dependency_test.rb`
    passed: 2 runs, 18 assertions, 0 failures, 0 errors.
  - `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
    test/fixtures/sample_app` passed.
  - `bundle exec rake` passed: 377 runs, 1567 assertions, 0 failures, 0
    errors, 2 skips.
  - `bundle exec rubocop` passed: 162 files inspected, no offenses.
  - `bin/check_dependency_direction` passed.
  - `bin/check_sample_app_frozen` passed.
  - `git diff --check` passed.
  - `ruby /Users/sal/Projects/strategic-software-design/scripts/validate.rb
    --type feature --task "Ok go ahead and start on the next 2 big tasks and
    keep using agenticons"` passed: slice tests, red/green, lint, and todo
    gates passed; warnings 0; review required.
- Final strategic review after blocker fix pending.
- Final `reviewer: strategic design validation` found one more blocker:
  `ProjectAnalyzerEvidenceRunner.summarize(index:)` exposed an unused public
  option with no CLI caller. It repeated the non-blocking concern about
  concrete collaborator lookup inside `TargetRun`.
- Removed the public `index:` keyword and simplified `Summary`/`TargetRun` to
  build indexes internally through the existing project-analyzer API.
- Verification after public `index:` removal:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`
    passed: 5 runs, 19 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb` passed: 14
    runs, 97 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_package_dependency_test.rb`
    passed: 2 runs, 18 assertions, 0 failures, 0 errors.
  - `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
    test/fixtures/sample_app` passed.
  - `bundle exec rake` passed: 377 runs, 1567 assertions, 0 failures, 0
    errors, 2 skips.
  - `bundle exec rubocop` passed: 162 files inspected, no offenses.
  - `bin/check_dependency_direction` passed.
  - `bin/check_sample_app_frozen` passed.
  - `git diff --check` passed.
- Strategic validation after public `index:` removal passed: slice tests,
  red/green, lint, and todo gates passed; warnings 0; review required.
- The final clean-context review subagent stalled and was closed without a
  verdict. User explicitly directed committing the current work and moving on.

## 2026-06-30: Calibration breakdowns and repeated-branching triage

Task: start on the next 2 big tasks and keep using agenticons.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep project analyzers at their current opt-in/default-output eligibility;
  do not promote or graduate any analyzer in this pass.
- Improve the calibration runner as an internal evidence tool only; do not
  change normal scan output formats.
- Limit `RepeatedBranching` behavior changes to confidence/severity wording for
  generic decision subjects. Do not add ignore lists, stricter thresholds, or
  target-specific suppressions.
- Keep agenticon delegation shallow and record findings.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and keep using agenticons"

Plan:

1. Use `planner: next two task plan` to check sequencing and scope.
2. Use `helper_worker: issue 27/28 reconnaissance` for read-only analyzer
   surface review while implementing non-overlapping local changes.
3. Add runner summary breakdowns for aggregate and per-target findings by rule,
   confidence, triage severity, and analyzer-specific metadata category/kind.
4. Add focused `RepeatedBranching` tests for generic-subject downranking while
   keeping state/expression subjects at current design-pressure triage.
5. Update calibration docs/notes with the decision, then run focused tests,
   local gates, strategic validation, and review if required.

Verification status:

- `planner: next two task plan` recommended improving the calibration runner
  first, then clarifying `RepeatedBranching` generic-subject triage. I kept
  DeepInheritanceTree filtering out of scope because local docs already show
  root-kind labeling and broad-base downranking completed.
- `helper_worker: issue 27/28 reconnaissance` confirmed that the remaining
  `RepeatedBranching` implementation surface is subject-aware triage, and that
  DeepInheritanceTree's unresolved question is future filtering/downranking
  rather than another semantic-labeling slice.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb` failed
  with missing `breakdowns` metadata.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/repeated_branching_triage_test.rb` failed because
  generic `action` branching still reported `confidence: medium`.
- Green focused tests:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`
    passed: 6 runs, 25 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_branching_triage_test.rb` passed: 2
    runs, 8 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_branching_subject_test.rb` passed: 2
    runs, 6 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_priority_test.rb` passed: 7
    runs, 12 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_test.rb` passed: 12
    runs, 33 assertions, 0 failures, 0 errors.
- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  test/fixtures/sample_app` passed and showed the new confidence, severity,
  and `root_kind` breakdown lines.
- Full repo-local calibration summary over
  `tmp/project-analyzer-calibration/apps` passed with `--no-write`: 8 targets,
  325 findings, 396 offenses. Aggregate breakdowns included
  `context required=11`, `decision_subject_kind`: `generic=11`, `state=11`,
  `expression=6`.
- After cleanup for local size/style rules, `bundle exec rake` passed: 381
  runs, 1583 assertions, 0 failures, 0 errors, 2 skips.
- `bundle exec rubocop` passed: 163 files inspected, no offenses.
- `bin/check_dependency_direction` passed.
- `bin/check_sample_app_frozen` passed.
- `git diff --check` passed.
- `ruby /Users/sal/Projects/strategic-software-design/scripts/validate.rb
  --type feature --task "Ok go ahead and start on the next 2 big tasks and
  keep using agenticons"` passed: slice tests, red/green, lint, and todo gates
  passed; warnings 0; review required.
- `reviewer: strategic design validation` verdict was clean with no blockers.
  Concern: `DEP-1` at
  `lib/metz_scan/calibration/project_analyzer_evidence_runner/summary.rb:32-69`;
  rationale: "TargetRun builds the project index and calls ProjectAnalyzerRunner
  directly, which leaves the evidence runner coupled to volatile scan/index
  plumbing and forces tests to replace singleton methods to observe
  orchestration behavior."; suggested_change: "Thread internal index-builder
  and finding-runner collaborators through Summary/TargetRun with production
  defaults, while keeping ProjectAnalyzerEvidenceRunner.summarize's public API
  narrow."
- `doc_reviewer: documentation drift` stalled after the required design review
  completed and was closed. Local documentation sanity check found and fixed one
  misplaced RepeatedBranching result sentence under the ServiceSoup section.

Implementation decisions:

- The calibration runner now records aggregate and per-target breakdowns by
  rule, confidence, severity, and selected analyzer metadata categories:
  `decision_subject_kind`, `dependency_pressure_category`,
  `namespace_leak_category`, and `root_kind`.
- The compact text and Markdown calibration outputs render the breakdowns, but
  normal scan output is unchanged.
- `RepeatedBranching` generic subjects now report `confidence: low` and
  `triage_severity: context required`. State-like and expression subjects keep
  the existing medium-confidence design-pressure triage.
- Default scan output still includes only medium-confidence design-pressure
  findings, so generic repeated-branching findings remain available through
  `--project-analyzers`.

## 2026-06-30: Calibration runner internals and analyzer filter

Task: start on the next 2 big tasks and keep using agenticons, then provide a
detailed comprehensive summary.

Scope boundaries:

- Build on the current uncommitted calibration-breakdowns and RepeatedBranching
  generic-subject triage slice without reverting it.
- Keep normal `metz-scan scan` behavior unchanged.
- Keep `ProjectAnalyzerEvidenceRunner.summarize` narrow for callers; prefer
  internal collaborator injection over public test-only options.
- Add calibration-runner filtering only for evidence runs, not for scan output.
- Do not promote, graduate, or suppress project analyzers in this pass.
- Keep `tmp/project-analyzer-calibration/apps` as the active calibration home.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and keep using agenticons and at the end give me a detail and comprehensive summary"

Plan:

1. Use `planner: next two task selection` to validate the next pair of tasks.
2. Use `helper_worker: calibration filter design` for read-only implementation
   shape review.
3. Address the strategic reviewer `DEP-1` concern by threading internal
   index-builder and finding-runner collaborators through `Summary` and
   `TargetRun` without widening the public runner API.
4. Add a calibration-only `--analyzer COP_NAME` filter so focused evidence
   runs can target one or more project analyzers while normal scan behavior
   remains unchanged.
5. Update docs/notes and rerun focused tests, calibration smoke, local gates,
   strategic validation, and required reviews.

Verification status:

- `planner: next two task selection` recommended stabilizing calibration target
  discovery/orchestration first, then improving mixed-triage project-analyzer
  report summaries. It explicitly deferred Sorbet, dogfood CI, analyzer
  promotion, and DeepInheritanceTree filtering.
- `helper_worker: calibration filter design` confirmed the internal
  `index_builder`/`finding_runner` collaborator seam and exact `RULE_ID`
  analyzer filtering. It recommended rejecting unknown analyzer names rather
  than silently returning empty output.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb` failed
  because `analyzer_names:` was unsupported and `Summary` ignored injected
  collaborators.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/commands/scan_project_analyzer_priority_test.rb` failed
  because rule summaries did not include `breakdowns`.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/commands/scan_text_renderer_project_analyzer_test.rb` failed
  because text output did not render a mixed-triage `mix:` hint.
- Green focused tests:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`
    passed: 9 runs, 39 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_priority_test.rb` passed: 8
    runs, 14 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_text_renderer_project_analyzer_test.rb`
    passed: 5 runs, 16 assertions, 0 failures, 0 errors.
- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  --analyzer MetzProject/RepeatedBranching` passed over active fixtures: 25
  findings, 55 offenses, `decision_subject_kind`: `generic=11`, `state=8`,
  `expression=6`.
- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  test/fixtures/sample_app` passed.
- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  --analyzer MetzProject/MissingAnalyzer test/fixtures/sample_app` exited 1
  with `unknown project analyzer: MetzProject/MissingAnalyzer`.
- Full repo-local calibration summary over
  `tmp/project-analyzer-calibration/apps` passed with `--no-write`: 8 targets,
  267 findings, 319 offenses. The drop from the earlier 325/396 run is the
  intentional result of skipping nested-only default targets such as `spree`
  instead of silently scanning their whole root.
- Additional focused regression checks passed:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_test.rb`: 12 runs, 33
    assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_branching_triage_test.rb`: 2 runs, 8
    assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/project_analyzers_test.rb`: 3 runs, 15 assertions,
    0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_triage_test.rb`: 2 runs, 8
    assertions, 0 failures, 0 errors.
- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  --analyzer MetzProject/RepeatedBranching test/fixtures/sample_app` passed
  with zero findings and `rules: none`, proving empty filtered output stays
  readable.
- `bundle exec rake` passed after the additive summary-test update: 386 runs,
  1604 assertions, 0 failures, 0 errors, 2 skips.
- `bundle exec rubocop` passed: 166 files inspected, no offenses.
- `bin/check_dependency_direction` passed.
- `bin/check_sample_app_frozen` passed.
- `git diff --check` passed.
- `ruby /Users/sal/Projects/strategic-software-design/scripts/validate.rb
  --type feature --task "Ok go ahead and start on the next 2 big tasks and
  keep using agenticons and at the end give me a detail and comprehensive
  summary"` passed: slice tests, red/green, lint, and todo gates passed;
  warnings 0; review required.
- Initial `reviewer: strategic design validation` returned one blocker:
  `DEPTH-1` at
  `lib/metz_scan/calibration/project_analyzer_evidence_runner/collaborators.rb:36-40`;
  rationale: "IndexBuilder is a new public class whose only behavior is
  forwarding to ProjectIndex.build, so it adds a collaborator name without
  hiding any complexity or policy."; suggested_change: "Remove IndexBuilder and
  pass ProjectIndex.method(:build) or call ProjectIndex.build directly from the
  runner boundary."
- Removed the pass-through `IndexBuilder` and now pass
  `ProjectIndex.method(:build)` as the internal index-builder collaborator.
- After the blocker fix, `bundle exec ruby -Ilib -Itest
  test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb` passed:
  9 runs, 39 assertions, 0 failures, 0 errors.
- `bundle exec rubocop` passed after the blocker fix: 166 files inspected, no
  offenses.
- `git diff --check` passed after the blocker fix.
- Strategic validation after the blocker fix passed again: slice tests,
  red/green, lint, and todo gates passed; warnings 0; review required.
- `doc_reviewer: documentation drift` found no documentation drift. Residual
  risk: calibration notes include historical target counts and sample revisions
  that can age as fixtures evolve.
- Follow-up `reviewer: strategic design validation` verdict was clean with no
  findings. Summary: "No blockers found. The change keeps the new calibration
  runner separate from normal scan flow, and the provided tests cover target
  discovery, analyzer filtering, breakdowns, artifact writing, and the
  default-output triage behavior."

Implementation decisions:

- `Summary` and `TargetRun` now depend on internal `IndexBuilder` and
  `FindingRunner` collaborators rather than reaching directly for
  `ProjectIndex.build` and `ProjectAnalyzerRunner.project_findings_for`.
- `--analyzer COP_NAME` is calibration-only, repeatable, exact by `RULE_ID`,
  and rejects unknown analyzer names.
- Discovered default calibration targets without top-level `app/` or `lib/`
  now remain in the summary with `backend: none`, empty scan paths, and a
  no-scan reason instead of falling back to a broad root scan. Explicit paths
  still scan the provided path.
- `ProjectAnalyzerMetadata.summary` now includes per-rule breakdowns using the
  same shared breakdown helper as the calibration runner.
- Text reports append a compact `mix:` hint when a rule has multiple severity
  or metadata-category values, making mixed DeepInheritanceTree output easier
  to interpret without filtering.
