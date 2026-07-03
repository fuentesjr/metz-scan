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
  lint, and to-do gates passed; red/green skipped; warnings 0.
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

## 2026-07-01: Calibration target manifests and DeepInheritanceTree policy pass

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep normal `metz-scan scan` behavior unchanged.
- Keep analyzer statuses and default-output eligibility unchanged unless a
  separate human-approved promotion/default-output step is requested.
- Keep target override support calibration-only; do not create a general
  product configuration system.
- Use agenticon delegation shallowly and record each result.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary in the same format as the last one"

Plan:

1. Use `planner: next two task selection` and
   `helper_worker: analyzer backlog reconnaissance` to validate the next
   implementation pair.
2. Add a calibration-only target manifest option so nested or multi-root
   fixtures such as the active Spree checkout can contribute evidence without
   reintroducing broad root fallback.
3. Run a focused `MetzProject/DeepInheritanceTree` calibration pass with the
   new manifest support and decide whether framework-style broad roots need
   additional filtering, downranking, or documentation only.
4. Update docs/notes with the manifest contract and DeepInheritanceTree
   decision, then run focused tests, calibration smoke checks, local gates,
   strategic validation, required reviews, and commit the finished slice.

Verification status:

- `planner: next two task selection` recommended adding calibration target-set
  override support first, then using it for a focused DeepInheritanceTree
  broad-root policy pass. It explicitly deferred analyzer promotion,
  default-output changes, Sorbet, and more RepeatedBranching implementation.
- `helper_worker: analyzer backlog reconnaissance` ranked
  `PackageDependencyPressure` broad-surface classification first and
  DeepInheritanceTree policy second. I chose the target-manifest slice first
  because it directly follows the previous no-root-fallback change and unlocks
  better evidence for both DeepInheritanceTree and future pressure-analyzer
  runs.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb` failed
  with `unknown keyword: :targets_file`, proving the missing manifest support.
- Green focused runner test passed after implementation: 11 runs, 46
  assertions, 0 failures, 0 errors.
- Focused RuboCop over the touched runner/bin/test files passed: 6 files
  inspected, no offenses.
- `bundle exec ruby bin/check_project_analyzer_calibration --help` passed and
  showed `--targets-file FILE`.
- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  --targets-file tmp/project-analyzer-calibration/deep_inheritance_targets.yml
  --analyzer MetzProject/DeepInheritanceTree` passed over 8 active targets:
  209 findings, 209 offenses, confidence breakdown `low=160`, `medium=49`,
  severity breakdown `broad base=160`, `manual review=49`.
- The same manifest-backed DeepInheritanceTree run wrote scratch artifacts to
  `tmp/project-analyzer-calibration/results/20260701-deep-inheritance-manifest`;
  `summary.json` and `summary.md` both recorded the absolute `targets_file`
  path.
- Full gates passed:
  - `bundle exec rake`: 388 runs, 1611 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 166 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git diff --check`: passed.
- Strategic validation after the final doc sentence passed: slice tests,
  red/green, lint, and task-comment gates passed; warnings 0; review required.
- Initial `reviewer: strategic design validation` verdict was clean with no
  findings.
- `doc_reviewer: calibration manifest docs` found no documentation drift. It
  noted one discoverability risk: docs did not explicitly say `--targets-file`
  cannot be mixed with positional `PATH` arguments. I addressed that in
  `docs/project-analyzer-calibration.md`.
- Follow-up `reviewer: strategic design validation` after the doc-risk fix was
  clean with no findings.

Implementation decisions:

- `--targets-file FILE` is calibration-only. Normal `metz-scan scan` behavior
  and default project-analyzer target discovery are unchanged.
- A target manifest lists checkout roots and explicit `scan_paths`; roots are
  resolved from the current working directory, scan paths are resolved relative
  to each root, and missing scan paths fail the run.
- `--targets-file` cannot be combined with positional `PATH` arguments. Each
  calibration run has one target source.
- Text, JSON, and Markdown calibration summaries now include the resolved
  `targets_file` path when a manifest is used.
- The DeepInheritanceTree manifest pass included nested Spree engine paths and
  found useful additional evidence, but no recurring missed framework-root
  category. Existing broad roots are already low-confidence `broad base`
  findings, and the remaining medium-confidence roots are diverse application
  or domain extension families. Keep DeepInheritanceTree validated opt-in and
  do not add a new filter or downranking rule from this pass.

## 2026-07-01: Pressure analyzer support filtering and Spree surface triage

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep normal `metz-scan scan` behavior unchanged.
- Keep `PackageDependencyPressure` and `NamespaceLeakPressure` candidate
  opt-in; do not promote analyzers or change default-output policy in this
  pass.
- Limit behavior changes to fixture-backed filtering or downranking supported
  by manifest-backed evidence.
- Use agenticon delegation shallowly and record each result.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` and
   `helper_worker: analyzer backlog reconnaissance` to validate the next
   implementation pair.
2. Tighten shared pressure-analyzer setup/support path filtering so nested
   seed or testing-support references do not inflate package/namespace
   pressure evidence.
3. Downrank manifest-exposed `PackageDependencyPressure` broad Spree domain
   surfaces `Spree::Store` and `Spree::Taxon`, while preserving
   `OpenFoodNetwork::ScopeVariantToHub` as a medium package-boundary prompt.
4. Rerun manifest-backed PackageDependencyPressure and NamespaceLeakPressure
   calibration, update docs/notes with the hold decisions, then run focused
   tests, local gates, strategic validation, required reviews, and commit the
   finished slice.

Verification status:

- `planner: next two task selection` recommended tightening shared
  setup/support path filtering first, then downranking manifest-exposed
  `PackageDependencyPressure` broad Spree domain surfaces. It explicitly
  deferred analyzer promotion, default-output policy changes, Sorbet, dogfood
  CI, and GitHub issue housekeeping.
- `helper_worker: analyzer backlog reconnaissance` ranked
  `PackageDependencyPressure` broad-surface regression lock-in as the most
  actionable implementation slice and `RepeatedBranching` report polish as
  mostly reporting/evidence-limited. I chose the planner's first task because
  manifest-backed NamespaceLeakPressure evidence showed concrete support-path
  inflation affecting both pressure analyzers.
- Baseline manifest-backed calibration before code changes:
  - `PackageDependencyPressure`: 40 findings, 40 offenses,
    `low=37`, `medium=3`; medium findings were
    `OpenFoodNetwork::ScopeVariantToHub`, `Spree::Store`, and `Spree::Taxon`.
  - `NamespaceLeakPressure`: 37 findings, 37 offenses,
    `low=32`, `medium=5`; Spree medium findings included nested seed and
    `testing_support` references.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/package_dependency_pressure_test.rb` failed with
  two expected failures: nested support references counted 14 files instead of
  12, and calibrated Spree shared domain surfaces still reported
  `confidence: medium`.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/namespace_leak_pressure_test.rb` failed with the
  expected failure: nested setup/support references counted 5 files instead of
  3.
- Green focused tests:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb`: 15 runs,
    109 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/namespace_leak_pressure_test.rb`: 15 runs,
    67 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_package_dependency_test.rb`:
    2 runs, 18 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_namespace_leak_test.rb`:
    1 run, 14 assertions, 0 failures, 0 errors.
- Focused RuboCop over touched analyzer/test files passed: 4 files inspected,
  no offenses.
- Manifest-backed calibration after implementation:
  - `PackageDependencyPressure`: 39 findings, 39 offenses,
    `low=38`, `medium=1`; the only remaining medium package-boundary finding
    is `OpenFoodNetwork::ScopeVariantToHub`.
  - `NamespaceLeakPressure`: 34 findings, 34 offenses,
    `low=31`, `medium=3`; remaining medium namespace-boundary findings are
    `Badge::Trigger::PostRevision`, `Spree::Gateway::StripeSCA`, and
    `Spree::PaymentMethod::StoreCredit`.
- Scratch calibration artifacts were written under
  `tmp/project-analyzer-calibration/results/20260701-package-pressure-support-filter`
  and
  `tmp/project-analyzer-calibration/results/20260701-namespace-leak-support-filter`.
- Full local gates passed:
  - `bundle exec rake`: 390 runs, 1625 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 166 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git diff --check`: passed.
- Strategic validation passed for change type `feature`: slice tests,
  red/green proof, lint, and task-comment gates passed; warnings 0; review
  required by diff size and touched public analyzer surface.
- Initial `reviewer: strategic design validation` verdict was clean with no
  findings.
- `doc_reviewer: pressure analyzer docs` found no documentation drift. It
  noted that README discoverability would improve by spelling out nested seed
  and `testing_support` filtering for NamespaceLeakPressure; I addressed that
  before the final validation.
- Follow-up `reviewer: strategic design validation` after the README clarity
  fix was clean with no findings.

Implementation decisions:

- `PackageMap.ignored_path?` now ignores nested `seeds` and
  `testing_support` path segments under `app/` or `lib/`. This applies to both
  pressure analyzers through their existing reference collectors.
- `Spree::Store` and `Spree::Taxon` now join the calibrated
  `PackageDependencyPressure` shared-surface list with other broad
  `Spree::*` commerce domain/API surfaces.
- `OpenFoodNetwork::ScopeVariantToHub` remains medium-confidence manual review
  because it is still the strongest package-owned adapter signal in the active
  evidence.
- Keep both pressure analyzers candidate opt-in. PackageDependencyPressure now
  has only one medium package-boundary finding in the active manifest-backed
  sample, and NamespaceLeakPressure has three medium findings but two are in
  the Spree/OpenFoodNetwork commerce family.

## 2026-07-01: Notable calibration findings and implicit context candidate

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep analyzer promotion and default-output policy unchanged.
- Keep the new analyzer candidate opt-in; do not make it default-output
  eligible.
- Prefer evidence-artifact improvements and a narrow AST-only analyzer slice
  over downranking the remaining pressure-analyzer medium findings without new
  evidence.
- Use agenticon delegation shallowly and record each result.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` and
   `helper_worker: backlog reconnaissance` to validate the next implementation
   pair.
2. Add limited, priority-sorted notable findings to calibration JSON, Markdown,
   and compact text output so sparse medium-confidence findings are named in
   artifacts instead of only counted.
3. Add a generic calibration target manifest path for future manifest-backed
   runs.
4. Implement the first narrow `MetzProject/ImplicitContextPressure` candidate:
   repeated `Current.<attribute>` access across at least three files and two
   coarse packages, excluding lifecycle calls such as `Current.reset` and
   `Current.set(...)`.
5. Update docs/notes, run focused tests, manifest-backed calibration smokes,
   full gates, strategic validation, required reviews, and commit.

Verification status:

- `planner: next two task selection` recommended upgrading calibration evidence
  artifacts with named notable findings and a generic manifest path, then
  implementing a first candidate slice of `MetzProject/ImplicitContextPressure`.
  It explicitly deferred analyzer promotion/default-output changes,
  DeepInheritanceTree filtering, and more pressure downranking without new
  evidence.
- `helper_worker: backlog reconnaissance` ranked follow-up evidence work on
  the remaining NamespaceLeakPressure and PackageDependencyPressure medium
  findings above new-analyzer work. I used that as a constraint: the remaining
  pressure findings stay medium/manual-review, and this slice improves evidence
  visibility rather than changing their classification.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb` failed
  because `notable_findings` was missing from summaries and Markdown output.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/implicit_context_pressure_test.rb` failed with
  `LoadError` because the analyzer did not exist yet.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/commands/project_analyzers_test.rb` failed because
  `MetzProject/ImplicitContextPressure` was not registered.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/commands/scan_project_analyzer_runner_test.rb` failed because
  `MetzScan::Analyzers::ImplicitContextPressure` was not defined.
- Green focused tests after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`: 13
    runs, 59 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb`: 7 runs,
    25 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/project_analyzers_test.rb`: 3 runs,
    17 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_test.rb`: 12 runs,
    34 assertions, 0 failures, 0 errors.
- Manifest-backed notable-finding smoke for
  `MetzProject/PackageDependencyPressure` passed with 39 findings and 39
  offenses: `low=38`, `medium=1`; compact text now names
  `OpenFoodNetwork::ScopeVariantToHub` as the notable medium
  `package_boundary` finding.
- Manifest-backed notable-finding smoke for
  `MetzProject/NamespaceLeakPressure` passed with 34 findings and 34 offenses:
  `low=31`, `medium=3`; compact text now names
  `Badge::Trigger::PostRevision`, `Spree::Gateway::StripeSCA`, and
  `Spree::PaymentMethod::StoreCredit`.
- First manifest-backed `MetzProject/ImplicitContextPressure` calibration pass
  over the active fixtures passed with 5 findings and 5 offenses, all in
  Chatwoot: `Current.account` (77 files, 8 packages),
  `Current.account_user` (6 files, 2 packages), `Current.contact` (4 files,
  3 packages), `Current.executed_by` (8 files, 3 packages), and `Current.user`
  (29 files, 8 packages).
- Focused RuboCop over touched Ruby/bin/test files passed: 10 files inspected,
  no offenses.
- Initial `reviewer: strategic design validation` returned one blocker:
  duplicated analyzer metadata category schema in notable findings and
  `ProjectAnalyzerBreakdown`. I fixed it by moving the category key list into
  `ProjectAnalyzerMetadata.category_metadata_keys` and making both reporting
  paths use that single source.
- Focused blocker-fix verification passed:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`: 13
    runs, 61 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_priority_test.rb
    test/metz_scan/commands/scan_project_analyzer_triage_test.rb
    test/metz_scan/commands/scan_text_renderer_project_analyzer_test.rb`: 8
    runs, 14 assertions, 0 failures, 0 errors.
  - Focused RuboCop over the shared metadata helper, breakdown helper, summary,
    and calibration test passed: 4 files inspected, no offenses.
- Full local gates passed:
  - `bundle exec rake` after the blocker fix: 399 runs, 1668 assertions,
    0 failures, 0 errors, 2 skips.
  - `bundle exec rubocop`: 168 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git diff --check`: passed.
- Strategic validation passed after the blocker fix for change type `feature`:
  slice tests, red/green proof, lint, and task-comment gates passed; warnings
  0; review required by diff size and new public analyzer surface.
- Follow-up `reviewer: strategic design validation` after the blocker fix was
  clean with no findings.
- `doc_reviewer: documentation drift` did not complete after repeated waits,
  so I closed it and performed the final doc sanity check locally. README,
  calibration docs, candidate backlog notes, and implementation notes cover
  the new candidate analyzer, generic manifest path, notable findings, and
  default-output status accurately.

Implementation decisions:

- Calibration summaries now include `notable_findings` at both aggregate and
  per-target levels. The list is limited to high/medium-confidence findings,
  triage-priority sorted, capped, and includes target, rule, message,
  confidence, severity, category, analyzer metadata, and first report location.
- Compact text and Markdown artifact rendering include a Notable Findings
  section when notable findings exist.
- `implicit_context_category` is a known project-analyzer breakdown metadata
  key.
- `ImplicitContextPressure` is AST-only and uses `RubyFileEnumerator`, so it
  works with explicit paths or indexed files without requiring Rubydex.
- The analyzer reports one primary offense per ambient context while keeping
  the full reference list in metadata. This avoided the first calibration
  shape of 5 Chatwoot findings expanding into hundreds of offenses.
- The first slice only detects `Current.<attribute>` reads/writes. It ignores
  Rails CurrentAttributes lifecycle calls such as `reset`, `set`, `attributes`,
  and reset callbacks. `Thread.current`, class variables, singleton-style
  globals, and broader false-positive calibration are deferred.
- Keep `ImplicitContextPressure` candidate opt-in. The initial evidence is
  useful but concentrated entirely in Chatwoot.

## 2026-07-01: Namespaced Current and repeated query criteria

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep analyzer promotion and default-output policy unchanged.
- Keep both changed analyzers candidate opt-in; do not make either
  default-output eligible.
- Broaden `ImplicitContextPressure` only to constant chains ending in
  `Current`; do not add `Thread.current`, class variables, or singleton global
  detection in this slice.
- Implement the first `RepeatedQueryCriteria` slice only for simple
  constant-receiver `where` calls with literal hash criteria.
- Use agenticon delegation shallowly and record each result.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` and
   `helper_worker: backlog reconnaissance` to validate the next implementation
   pair.
2. Broaden `MetzProject/ImplicitContextPressure` to namespaced
   CurrentAttributes constants such as `Spree::Current.store`, while
   preserving lifecycle-call ignores and local `current` rejection.
3. Add `MetzProject/RepeatedQueryCriteria` as an AST-only candidate analyzer
   for repeated multi-key `where` hash criteria across files and coarse
   packages.
4. Register the new analyzer, add metadata breakdown support, and keep it out
   of default output.
5. Update README, candidate notes, calibration docs, and implementation notes;
   run focused tests, manifest-backed calibration smokes, full gates,
   strategic validation, required reviews, and commit.

Verification status:

- `planner: next two task selection` recommended namespaced
  `CurrentAttributes` support plus the conservative `RepeatedQueryCriteria`
  candidate. It explicitly warned not to promote analyzers or change default
  output.
- `helper_worker: backlog reconnaissance` ranked pressure-analyzer follow-ups
  first but warned that downranking the remaining medium findings could overfit
  sparse evidence. I used that as a constraint and left those analyzers'
  classifications unchanged.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/implicit_context_pressure_test.rb` failed because
  `Spree::Current.store` produced no finding.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/repeated_query_criteria_test.rb` failed with
  `LoadError` because the analyzer did not exist yet.
- Green focused tests after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb`: 10 runs,
    32 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb`: 8 runs,
    25 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/project_analyzers_test.rb`: 3 runs,
    19 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_test.rb`: 12 runs,
    35 assertions, 0 failures, 0 errors.
- Manifest-backed `MetzProject/ImplicitContextPressure` calibration over the
  active fixtures passed with 10 findings and 10 offenses. It kept the 5
  Chatwoot findings and added 5 Spree namespaced contexts:
  `Spree::Current.channel`, `Spree::Current.currency`,
  `Spree::Current.locale`, `Spree::Current.market`, and
  `Spree::Current.store`.
- First manifest-backed `MetzProject/RepeatedQueryCriteria` calibration over
  the active fixtures passed with 6 findings and 6 offenses:
  `Draft.where(draft_key, user_id)`,
  `GroupUser.where(group_id, user_id)`,
  `Post.where(post_number, topic_id)`,
  `TopicUser.where(topic_id, user_id)`,
  `Comment.where(commentable_id, commentable_type)`, and
  `AccountDomainBlock.where(account_id, domain)`.
- Initial `reviewer: strategic design validation` returned one blocker:
  `LEAK-1` in
  `lib/metz_scan/calibration/project_analyzer_evidence_runner/collaborators.rb`.
  The selected-analyzer calibration path filtered only finding metadata for
  default output and skipped the analyzer-level `DEFAULT_OUTPUT_ELIGIBLE`
  policy. I fixed it by filtering selected analyzer classes through
  `ProjectAnalyzerRunner.default_output_analyzer?` before applying the
  existing finding-level default-output gate.
- Blocker-fix red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb` failed
  because a selected validated opt-in analyzer leaked a medium design-pressure
  finding under `default_output: true`.
- Blocker-fix focused green run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`: 14
  runs, 63 assertions, 0 failures, 0 errors.
- Blocker-fix focused RuboCop passed for the collaborator and calibration test
  files: 2 files inspected, no offenses.
- Full local gates after the blocker fix passed:
  - `bundle exec rake`: 411 runs, 1705 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 170 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git -c core.fsmonitor=false diff --check`: passed.
- Strategic validation after the blocker fix passed for change type `feature`:
  slice tests, red/green proof, lint, and task-comment gates passed; warnings 0;
  review required by diff size and new public analyzer surface.
- Follow-up `reviewer: strategic design validation` on the final diff returned
  one blocker: `LEAK-1` in
  `lib/metz_scan/analyzers/implicit_context_pressure.rb`. The new collectors
  duplicated namespace/method AST context traversal that already existed in
  `RepeatedBranching::ContextualNodeWalker`. I fixed it by promoting the
  walker to `MetzScan::Analyzers::ContextualNodeWalker`, keeping the old
  repeated-branching require path as a compatibility alias, and updating
  `BranchSiteCollector`, `CurrentAttributeCollector`, and
  `QuerySiteCollector` to use the shared walker.
- Shared-walker focused verification passed:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_branching_helper_test.rb`: 6 runs,
    14 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_branching_test.rb`: 11 runs,
    35 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb`: 10 runs,
    32 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb`: 8 runs,
    25 assertions, 0 failures, 0 errors.
  - Focused RuboCop over the shared walker and three collectors passed:
    5 files inspected, no offenses.
- Final `reviewer: strategic design validation` after the shared-walker fix
  was clean with no findings.
- `doc_reviewer: analyzer documentation drift` found no documentation drift.
  It confirmed README, calibration docs, candidate notes, and implementation
  notes match the analyzer behavior and active calibration counts. It noted the
  calibration tables are point-in-time snapshots tied to
  `tmp/project-analyzer-calibration/apps`.

Implementation decisions:

- `ImplicitContextPressure` now treats any constant receiver whose final
  namespace segment is `Current` as CurrentAttributes-style access, preserving
  the full ambient context in messages and metadata.
- Lifecycle ignores remain method-name based, so `Current.reset`,
  `Spree::Current.reset`, `Current.set(...)`, and
  `Spree::Current.set(...)` are all excluded.
- `RepeatedQueryCriteria` groups by constant receiver plus sorted literal hash
  keys. It requires at least two keys, three referring files, and two coarse
  packages to reduce common one-off lookup noise.
- `RepeatedQueryCriteria` emits one primary offense per repeated query
  fingerprint and keeps the full occurrence list in project-analyzer metadata.
- `ContextualNodeWalker` is now shared at the analyzer namespace, so analyzer
  collectors share namespace and method context extraction instead of
  reimplementing recursive AST traversal.
- `repeated_query_category` is now part of the shared project-analyzer metadata
  breakdown key list.
- Keep both analyzers candidate opt-in. The calibration output is sparse and
  readable, but both signals still need manual review before validated status
  or default-output eligibility.

## 2026-07-01: Method index support and subclass override candidate

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Skip RuboCop cache deletion for now, per user instruction.
- Do not downrank remaining pressure-analyzer medium findings without new
  generalized evidence.
- Keep the new analyzer candidate opt-in and not default-output eligible.
- Use agenticon delegation shallowly and record each result.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` to choose the next two substantial
   tasks from current analyzer notes.
2. Use `helper_worker: pressure-analyzer follow-up evidence` to check whether
   remaining `PackageDependencyPressure` or `NamespaceLeakPressure` medium
   findings justify another generalized behavior change.
3. Extend `ProjectIndex` with normalized method declarations from Rubydex:
   owner name, normalized method name, signature, path, line, and column.
4. Implement the first `MetzProject/SubclassOverridePressure` candidate using
   known descendants and base-declared method overrides.
5. Register the analyzer, add metadata breakdown support, update docs, run
   focused tests, active-fixture calibration smoke, full gates, strategic
   validation, reviews, and commit.

Verification status:

- `planner: next two task selection` recommended exactly this two-task slice:
  method declaration metadata in `ProjectIndex`, then the first narrow
  `MetzProject/SubclassOverridePressure` candidate. It explicitly warned not
  to reclassify pressure analyzers without new evidence.
- `helper_worker: pressure-analyzer follow-up evidence` found no generalized
  basis for downranking the remaining medium pressure findings:
  `OpenFoodNetwork::ScopeVariantToHub`,
  `Badge::Trigger::PostRevision`, `Spree::Gateway::StripeSCA`, and
  `Spree::PaymentMethod::StoreCredit` should stay medium manual-review prompts
  for now.
- Red run: `bundle exec ruby -Ilib -Itest test/metz_scan/project_index_test.rb`
  failed because `ProjectIndex#method_declarations` did not exist.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/subclass_override_pressure_test.rb` failed with
  `LoadError` because the analyzer did not exist.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/commands/project_analyzers_test.rb` failed because
  `MetzProject/SubclassOverridePressure` was not registered.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/commands/scan_project_analyzer_runner_test.rb` failed because
  `MetzScan::Analyzers::SubclassOverridePressure` was not defined.
- Red follow-up: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/subclass_override_pressure_test.rb` failed because
  broad-root override findings still reported medium confidence.
- Green focused tests after implementation and broad-root triage:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/project_index_test.rb`: 8 runs, 37 assertions, 0 failures,
    0 errors, 2 skips.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/subclass_override_pressure_test.rb`: 4 runs,
    29 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/project_analyzers_test.rb`: 3 runs,
    21 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_test.rb`: 12 runs,
    36 assertions, 0 failures, 0 errors.
- First manifest-backed `MetzProject/SubclassOverridePressure` calibration over
  the active fixtures passed mechanically with 206 findings and 2040 offenses.
  I tightened the first slice to emit one primary offense per override family,
  reuse broad-root triage, and require six overriding descendants by default.
- Final manifest-backed `MetzProject/SubclassOverridePressure` calibration over
  the active fixtures passed with 104 findings and 104 offenses:
  29 medium manual-review findings and 75 low broad-base findings.
  Medium finding distribution: Discourse 12, Forem 3, Mastodon 1,
  OpenFoodNetwork 7, Spree 6; Chatwoot, Decidim, and Solidus had no medium
  findings.
- Focused RuboCop over touched Ruby files passed: 15 files inspected, no
  offenses.
- Full local gates passed:
  - `bundle exec rake`: 416 runs, 1747 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 177 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git -c core.fsmonitor=false diff --check`: passed.
- Strategic validation passed for change type `feature`: slice tests,
  red/green proof, lint, and task-comment gates passed; warnings 0; review
  required by diff size and new public interface.
- `reviewer: strategic design validation` returned a clean verdict with no
  findings.
- `doc_reviewer: documentation drift` found one docs issue: README and
  calibration docs omitted serializer bases from the SubclassOverridePressure
  broad-root list even though the analyzer reuses the `DeepInheritanceTree`
  root-kind vocabulary. I fixed both docs to include serializer bases.
- Final post-doc-fix calibration smoke for `SubclassOverridePressure` still
  passed with 104 findings and 104 offenses: `low=75`, `medium=29`.
- Final post-doc-fix strategic validation still passed with warnings 0, and
  the fresh `reviewer: strategic design validation` verdict was clean with no
  findings.

Implementation decisions:

- `ProjectIndex::MethodDeclaration` is a normalized project-index value object
  so analyzers do not consume Rubydex method objects directly.
- Rubydex method names such as `Parent#perform()` are split into owner name,
  method name, and original signature while preserving source location.
- `SubclassOverridePressure` only reports a method when it is declared on the
  base class and redefined by enough known descendants.
- The analyzer emits one primary offense per override family and keeps the full
  override list in `project_analyzer_metadata`.
- Broad roots use the same root-kind vocabulary as `DeepInheritanceTree` and
  are low-confidence `broad base` prompts.
- Keep `SubclassOverridePressure` candidate opt-in. The first pass surfaces
  concrete hook protocols, but the signal is still broad enough to require
  manual review before any validated-status or default-output discussion.

## 2026-07-01: Subclass override body facts and categories

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep `SubclassOverridePressure` candidate opt-in and not default-output
  eligible.
- Do not promote analyzers, change default-output policy, or add app-specific
  suppressions.
- Prefer source-derived metadata and conservative category classification over
  downranking medium findings from sparse evidence.
- Use agenticon delegation shallowly and record each result.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` to choose the next two tasks after
   the `SubclassOverridePressure` candidate slice.
2. Use `helper_worker: subclass override evidence` to inspect active medium
   findings and identify evidence-backed refinements.
3. Add source-derived method body facts for override families: base method body
   kind and descendant override `super` calls.
4. Classify `subclass_override_category` using those facts:
   `broad_root_override`, `abstract_hook_override`, `cooperative_override`,
   `replacement_override`, or fallback `subclass_override`.
5. Update docs/notes, run focused tests, active-fixture calibration smoke, full
   gates, strategic validation, reviews, and commit.

Verification status:

- `planner: next two task selection` recommended method-body facts followed by
  classification metadata for `SubclassOverridePressure`; it warned to keep
  status/default-output policy unchanged.
- `helper_worker: subclass override evidence` confirmed the current 29 medium
  findings are mostly hook-protocol style bases and recommended abstract/no-op
  base-method classification plus cooperative `super` metadata. It explicitly
  advised against promotion, app-specific suppressions, threshold changes, or
  relying only on existing `root_kind` triage.
- Local read-only sample over the active fixtures found 18 medium families with
  concrete base methods and 11 with abstract-raise base methods; 7 of the 29
  medium families had at least one descendant override calling `super`.
- Red run: `bundle exec ruby -Ilib -Itest
  test/metz_scan/analyzers/subclass_override_pressure_body_facts_test.rb`
  failed because metadata still reported generic `subclass_override` category
  and lacked body facts.
- Green focused tests after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/subclass_override_pressure_body_facts_test.rb`:
    3 runs, 11 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/subclass_override_pressure_test.rb`: 4 runs,
    29 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/project_analyzers_test.rb`: 3 runs,
    21 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_test.rb`: 12 runs,
    36 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/project_index_test.rb`: 8 runs, 37 assertions, 0 failures,
    0 errors, 2 skips.
- Focused RuboCop over touched subclass-override files passed: 7 files
  inspected, no offenses.
- Manifest-backed `MetzProject/SubclassOverridePressure` calibration over the
  active fixtures passed with 104 findings and 104 offenses:
  `broad_root_override=75`, `abstract_hook_override=17`,
  `cooperative_override=5`, `replacement_override=7`.
- Full local gates passed:
  - `bundle exec rake`: 419 runs, 1758 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 180 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git -c core.fsmonitor=false diff --check`: passed.
- Strategic validation passed for change type `feature`: slice tests,
  red/green proof, lint, and task-comment gates passed; warnings 0; review
  required by diff size and new public interface.
- `doc_reviewer: documentation drift` found no documentation drift. README,
  calibration docs, candidate notes, and implementation notes match the new
  body-fact metadata, category names, counts, project-index requirement, and
  candidate/default-output status.
- `reviewer: strategic design validation` returned a clean verdict with one
  non-blocking concern:
  - `rubric_id`: `DEP-1`
  - `location`:
    `lib/metz_scan/analyzers/package_dependency_pressure/shared_dependency_triage.rb:25-35`
  - `severity`: `concern`
  - `rationale`: "The generic package-pressure analyzer now hard-codes
    calibration outcomes for specific external applications and constants, so
    future fixture changes or new calibration samples require editing analyzer
    behavior rather than updating calibration data."
  - `suggested_change`: "Move calibrated shared-surface names into an
    injected/default calibration data source or express the downranking through
    generic metadata rules so the analyzer does not directly depend on
    app-specific fixture constants."

Implementation decisions:

- Kept method-body analysis internal to `SubclassOverridePressure` instead of
  widening `ProjectIndex`; body facts are source-derived triage metadata, not
  a reusable index capability yet.
- Classified base method bodies conservatively as `abstract_raise`, `empty`,
  `default_value`, `concrete`, or `unknown`.
- Treated empty, abstract-raise, and default literal base methods as
  `abstract_hook_override`; treated concrete base methods with any descendant
  `super` calls as `cooperative_override`; treated concrete families without
  `super` as `replacement_override`; preserved `broad_root_override` for
  existing broad-root triage; preserved `subclass_override` for unknown bodies.
- Did not change analyzer status, default-output eligibility, or confidence
  policy for medium findings. The new categories are for manual-review
  calibration and triage.

## 2026-07-01: Category-aware override triage and generic shared surfaces

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep analyzer rollout statuses and default-output eligibility unchanged.
- Do not delete RuboCop caches.
- Do not promote analyzers or change the default-output policy.
- Prefer generic shared-surface rules over app-specific calibrated constant
  checks in production analyzer behavior.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` and `helper_worker: next task
   evidence` to select the next pair of tasks from the current backlog.
2. Implement category-aware `SubclassOverridePressure` report language for the
   existing abstract-hook, cooperative, replacement, broad-root, and fallback
   categories.
3. Replace `PackageDependencyPressure`'s calibrated shared-surface constant
   list with generic shared-surface predicates for conventional domain models,
   value objects, and protocol-manager surfaces.
4. Update docs and notes with the unchanged calibration counts and refined
   semantics.
5. Run focused tests, calibration smokes, full gates, strategic validation,
   agenticon reviews, and commit.

Verification status:

- `planner: next two task selection` recommended category-aware
  `SubclassOverridePressure` triage plus `PackageDependencyPressure`
  shared-surface cleanup. It explicitly warned not to delete RuboCop caches,
  use `/private/tmp` calibration paths, promote analyzers, change
  default-output policy, or start a new analyzer in this slice.
- `helper_worker: next task evidence` agreed that `PackageDependencyPressure`
  cleanup was the highest-confidence task. It ranked a `NamespaceLeakPressure`
  evidence pass second and considered subclass override mechanically stable.
  I kept the planner's subclass triage task because it turns the previous
  commit's new categories into report behavior, while the namespace pass was
  mostly calibration evidence without a clear implementation change.
- Red run before production implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/subclass_override_pressure_body_facts_test.rb`
    failed with 4 runs, 16 assertions, 3 failures. The missing behavior was
    category-specific message/summary/why/next-move output; one replacement
    fixture was also corrected to avoid the existing broad-root serializer
    triage path.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb` failed with
    18 runs, 112 assertions, 3 failures because generic conventional domain
    model, value object, and protocol-manager surfaces were still
    medium-confidence package-boundary findings.
- Green focused tests after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/subclass_override_pressure_body_facts_test.rb`:
    4 runs, 38 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/subclass_override_pressure_test.rb`: 4 runs,
    29 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb`: 18 runs,
    124 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_package_dependency_test.rb`:
    2 runs, 18 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_test.rb`: 12 runs,
    36 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`:
    14 runs, 63 assertions, 0 failures, 0 errors.
- Focused RuboCop over touched Ruby files passed: 6 files inspected, no
  offenses.
- Manifest-backed `MetzProject/PackageDependencyPressure` calibration over the
  active fixtures passed with 39 findings and 39 offenses:
  `shared_dependency=38`, `package_boundary=1`; `low=38`, `medium=1`; the only
  medium finding remained `OpenFoodNetwork::ScopeVariantToHub`.
- Manifest-backed `MetzProject/SubclassOverridePressure` calibration over the
  active fixtures passed with 104 findings and 104 offenses:
  `broad_root_override=75`, `abstract_hook_override=17`,
  `cooperative_override=5`, `replacement_override=7`.

Implementation decisions:

- Kept `SubclassOverridePressure` categories and counts unchanged, but moved
  category-specific message, triage summary, why-it-matters, and suggested
  next moves into a dedicated `Triage` collaborator.
- Kept `SubclassOverridePressure` candidate opt-in and not default-output
  eligible; the category wording supports manual review rather than promotion.
- Removed the `PackageDependencyPressure` calibrated shared-surface constant
  map from `SharedDependencyTriage`.
- Replaced app-specific shared-surface checks with generic predicates for
  conventional `app/models` domain models, `lib/...` value objects such as
  money/currency/amount/price, and `app/lib` protocol manager/registry/router
  surfaces.
- Preserved the calibration shape for `PackageDependencyPressure`: the cleanup
  addresses the prior design-review concern without changing the single
  medium package-boundary finding.
- Full local gates before strategic review passed:
  - `bundle exec rake`: 423 runs, 1800 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 181 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git -c core.fsmonitor=false diff --check`: passed.
- Strategic validation passed for change type `feature`: slice tests,
  red/green proof, lint, and task-comment gates passed; warnings 0; review
  required by diff size and public-interface surface in the unpushed branch
  stack.
- `doc_reviewer: documentation drift` found no documentation drift.
- Initial `reviewer: strategic design validation` returned two blockers:
  - `rubric_id`: `DEP-1`
  - `location`:
    `lib/metz_scan/calibration/project_analyzer_evidence_runner.rb:35-39`
  - `severity`: `blocker`
  - `rationale`: "`summary_options` hard-codes the project-index builder and
    finding runner, so tests and callers that need a controlled calibration
    run have to replace global singleton methods instead of injecting
    collaborators."
  - `suggested_change`: "Make the public runner path accept injectable
    collaborators with production defaults, or introduce an instance runner
    initialized with `index_builder:` and `finding_runner:` and have
    `summarize` delegate to it."
  - `rubric_id`: `LEAK-1`
  - `location`: `lib/metz_scan/commands/scan/project_analyzer_metadata.rb:10-18`
  - `severity`: `blocker`
  - `rationale`: "The command layer now enumerates analyzer-specific category
    keys that are also authored inside each analyzer's metadata hash, so adding
    or renaming an analyzer category requires coordinated edits across producer
    and renderer/summary code or the category silently disappears from
    breakdowns."
  - `suggested_change`: "Move the category contract onto the finding/analyzer
    itself, for example by emitting a common `category` metadata field or
    exposing `project_analyzer_category`, and have breakdown/notable summaries
    read that common interface instead of listing every analyzer's key."
- Blocker fixes:
  - `ProjectAnalyzerEvidenceRunner.summarize` now accepts `index_builder:` and
    `finding_runner:` collaborators with production defaults.
  - Project analyzer metadata producers now emit a common
    `project_analyzer_category` field alongside their existing analyzer-specific
    category keys.
  - Summary breakdowns and notable-finding categories now read
    `project_analyzer_category`; analyzer-specific keys remain in full metadata
    for compatibility.
- Focused blocker-fix tests after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`:
    15 runs, 64 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_triage_test.rb`: 2 runs,
    8 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb`: 8 runs,
    25 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb`: 10 runs,
    32 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/namespace_leak_pressure_test.rb`: 15 runs,
    67 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/inheritance_descendants_test.rb`: 12 runs,
    133 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_branching_subject_test.rb`: 2 runs,
    6 assertions, 0 failures, 0 errors.
- Post-blocker-fix calibration smoke kept the same counts, but summary
  breakdowns now use `project_analyzer_category`:
  - `MetzProject/PackageDependencyPressure`: 39 findings and 39 offenses;
    `project_analyzer_category`: `package_boundary=1`, `shared_dependency=38`.
  - `MetzProject/SubclassOverridePressure`: 104 findings and 104 offenses;
    `project_analyzer_category`: `abstract_hook_override=17`,
    `broad_root_override=75`, `cooperative_override=5`,
    `replacement_override=7`.
- Post-blocker full local gates passed:
  - `bundle exec rake`: 424 runs, 1801 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 181 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git -c core.fsmonitor=false diff --check`: passed.
- Final post-blocker strategic validation passed with warnings 0. Review was
  still required by diff size and public-interface surface in the unpushed
  branch stack.
- Final `doc_reviewer: documentation drift` was clean.
- Final `reviewer: strategic design validation` verdict was clean with no
  findings.
- Final post-note strategic validation rerun passed with warnings 0. The final
  `reviewer: strategic design validation` verdict was clean with no findings:
  "No blockers found. The change keeps project-analyzer rollout policy
  explicit, consolidates shared AST context and category metadata instead of
  leaking those decisions across consumers, and the load-red tests assert
  concrete analyzer behavior rather than mere constant existence."

## 2026-07-02: Pressure reference shape and AST candidate categories

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep analyzer rollout statuses and default-output eligibility unchanged.
- Do not promote analyzers or downrank the remaining medium pressure findings
  without new generalized evidence.
- Keep `ImplicitContextPressure` and `RepeatedQueryCriteria` detector scope
  unchanged; improve category metadata and report language only.
- Use agenticon delegation shallowly and record each result.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` and
   `helper_worker: analyzer backlog reconnaissance` to select the next task
   pair after the category-contract cleanup.
2. Share safe cross-package reference-set and reference-metadata behavior
   between `PackageDependencyPressure` and `NamespaceLeakPressure`, adding
   source-derived `reference_shape` metadata without changing findings.
3. Add category-aware manual-review metadata and language for
   `ImplicitContextPressure` root/namespaced Current access and
   `RepeatedQueryCriteria` query-key shapes.
4. Update README, candidate notes, calibration docs, and implementation notes;
   run focused tests, manifest-backed calibration smokes, full gates,
   strategic validation, reviews, and commit.

Verification status:

- `planner: next two task selection` recommended a shared cross-package
  reference-pressure foundation plus category-aware triage for the newest
  AST-only candidates. It explicitly deferred analyzer promotion,
  default-output changes, pressure-analyzer downranking, `DeadCodeCandidates`,
  and broader detector expansion.
- `helper_worker: analyzer backlog reconnaissance` ranked calibration evidence
  expansion above code surgery, especially for `NamespaceLeakPressure`,
  `ImplicitContextPressure`, and `RepeatedQueryCriteria`. It warned not to use
  `/private/tmp` calibration paths or downrank remaining pressure findings
  without generalized evidence.
- Red runs before implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb` failed
    because package-pressure metadata lacked `reference_shape`.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/namespace_leak_pressure_test.rb` failed because
    namespace-leak metadata lacked `reference_shape`.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb` failed because
    Current access still used generic "accessed" wording and generic
    `current_attributes` category metadata.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb` failed because
    scoped and polymorphic query examples still reported generic
    `where_hash_criteria`.
- Green focused tests after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/package_dependency_pressure_test.rb`: 18 runs,
    128 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/namespace_leak_pressure_test.rb`: 15 runs,
    69 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb`: 10 runs,
    42 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb`: 9 runs,
    33 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_package_dependency_test.rb`:
    2 runs, 18 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_runner_namespace_leak_test.rb`:
    1 run, 14 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/commands/scan_project_analyzer_triage_test.rb`: 2 runs,
    8 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`:
    15 runs, 64 assertions, 0 failures, 0 errors.
- Manifest-backed calibration smokes over
  `tmp/project-analyzer-calibration/project_analyzer_targets.yml` with
  `--no-write`:
  - `MetzProject/PackageDependencyPressure`: 39 findings and 39 offenses;
    `project_analyzer_category`: `package_boundary=1`,
    `shared_dependency=38`.
  - `MetzProject/NamespaceLeakPressure`: 34 findings and 34 offenses;
    `project_analyzer_category`: `namespace_boundary=3`,
    `shared_namespace=31`.
  - `MetzProject/ImplicitContextPressure`: 10 findings and 10 offenses;
    `project_analyzer_category`: `root_current_write=5`,
    `namespaced_current_write=5`.
  - `MetzProject/RepeatedQueryCriteria`: 6 findings and 6 offenses;
    `project_analyzer_category`: `scoped_association_where_criteria=3`,
    `compound_association_where_criteria=2`,
    `polymorphic_where_criteria=1`.

Implementation decisions:

- Shared only the safe pressure-reference value and metadata layer:
  `CrossPackageReferenceSet` and `CrossPackageReferenceMetadata`. Package and
  namespace collectors still own their analyzer-specific filtering rules.
- Added `reference_shape` metadata with referring file count, referring package
  count, referring package roots, and referring package leafs.
- Classified implicit context by Current receiver scope (`root` or
  `namespaced`) and whether any access is a write. This changes category
  metadata and message wording, not detection thresholds.
- Classified repeated query criteria by literal key shape:
  polymorphic type/id pairs, compound association key pairs, single association
  scoped criteria, or generic hash criteria. This changes category metadata
  and report language, not detector scope.
- The first strategic design review returned a blocker in the existing
  `SubclassOverridePressure` stack: `ProjectIndex::MethodDeclaration` dropped
  receiver kind while normalizing Rubydex method names, so singleton and
  instance override families could be mixed. The fix preserves
  `receiver_kind` and `method_identity`, normalizes Rubydex singleton owners
  such as `Parent::<Parent>` back to `Parent`, and has
  `SubclassOverridePressure` group and match methods by `method_identity`.
- The method-identity fix changed manifest-backed `SubclassOverridePressure`
  calibration to 106 findings and 106 offenses: `low=76`, `medium=30`;
  `project_analyzer_category`: `abstract_hook_override=18`,
  `broad_root_override=76`, `cooperative_override=5`,
  `replacement_override=7`.
- The second strategic design review returned a blocker in
  `SubclassOverridePressure::MethodBodyFacts`: singleton method body extraction
  used the wrong `defs` child index, so body kind and `super` metadata could be
  wrong for singleton override families. The fix uses `node.body` for both
  `def` and `defs` nodes and adds singleton-method body-fact coverage.

## 2026-07-02: Thread-local context and scope-chain query criteria

Task: start on the next 2 big tasks and keep using agenticons, commit the
changes, then provide a detailed comprehensive summary as described in
AGENTS.md.

Additional user request: add `.claude/settings.local.json` to `~/.gitignore`.
The file was already present in `/Users/sal/.gitignore`, and
`git check-ignore -v .claude/settings.local.json` confirmed the repo-local file
is ignored.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep `ImplicitContextPressure` and `RepeatedQueryCriteria` candidate opt-in
  and not default-output eligible.
- Do not promote, validate, or downrank analyzers in this pass.
- Extend only narrow AST slices: literal `Thread.current[...]` keys for
  implicit context, and constant-root no-argument scope chains for repeated
  query criteria.
- Keep dynamic thread-local keys, class variables, singleton globals, dynamic
  SQL, dynamic scope chains, and non-constant query receivers out of scope.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Plan:

1. Use `planner: next two task selection` and
   `helper_worker: analyzer backlog reconnaissance` to select the next task
   pair after commit `59ed606`.
2. Implement literal `Thread.current[...]` read/write detection in
   `MetzProject/ImplicitContextPressure`, with category-specific triage and
   metadata.
3. Implement conservative constant-root scope-chain receiver support in
   `MetzProject/RepeatedQueryCriteria`, with receiver-shape metadata.
4. Update README, candidate notes, calibration docs, and implementation notes;
   run focused tests, manifest-backed calibration smokes, full gates,
   strategic validation, reviews, and commit.

Verification status:

- `planner: next two task selection` recommended two documented future-scope
  expansions: literal `Thread.current[...]` ambient context access and
  conservative constant-root scope-chain query criteria. It warned to keep
  analyzers candidate opt-in and to record calibration counts before any
  promotion discussion.
- `helper_worker: analyzer backlog reconnaissance` warned that current evidence
  still does not justify promotion or threshold changes, especially for
  pressure analyzers. It recommended calibration-first caution and explicitly
  warned against accidental reclassification of broad shared surfaces as real
  boundary pressure.
- A brief calibration-reporting spike was started locally, then removed after
  the agenticon results pointed to the documented analyzer backlog instead.
- Red runs before implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb` failed because
    repeated `Thread.current[:account]` returned no finding.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb` failed because
    repeated `Order.active.where(...)` returned no finding.
- Green focused tests after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/implicit_context_pressure_test.rb`: 13 runs,
    56 assertions, 0 failures, 0 errors.
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb`: 14 runs,
    43 assertions, 0 failures, 0 errors.
- Manifest-backed calibration smokes over
  `tmp/project-analyzer-calibration/project_analyzer_targets.yml` with
  `--no-write`:
  - `MetzProject/ImplicitContextPressure`: 11 findings and 11 offenses;
    `project_analyzer_category`: `root_current_write=5`,
    `namespaced_current_write=5`, `thread_current_write=1`. The new finding is
    Mastodon `Thread.current[:redis]`, read and written from 4 files across
    2 packages.
  - `MetzProject/RepeatedQueryCriteria`: 6 findings and 6 offenses;
    `project_analyzer_category`: `scoped_association_where_criteria=3`,
    `compound_association_where_criteria=2`,
    `polymorphic_where_criteria=1`. The active manifest did not add new
    repeated scope-chain findings at the current threshold.
- Full local gates passed:
  - `bundle exec rake`: 435 runs, 1868 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 190 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git -c core.fsmonitor=false diff --check`: passed.
- `doc_reviewer: analyzer documentation drift` found README table drift after
  the first doc update because the analyzer inventory rows did not mention
  literal `Thread.current[...]` or constant-root scope-chain query criteria.
  The README table was updated.
- Final `doc_reviewer: documentation drift re-review` was clean and confirmed
  the README table drift was fixed, with no remaining doc fixes needed.
- Strategic validation passed for change type `feature`: slice tests,
  red/green proof, lint, and task-comment gates passed; warnings 0; review
  required by diff size and public-interface surface in the branch stack.
- Final `reviewer: strategic design validation` verdict was clean with no
  findings:
  "The change holds together as candidate project-analyzer work plus
  calibration support. The new analyzer surfaces stay opt-in/default-gated,
  shared metadata is centralized where it matters, and the load-red tests
  assert concrete grouping, filtering, metadata, and rendering behavior rather
  than merely referencing new constants."

Implementation decisions:

- Replaced the Current-only collector path with an ambient context collector
  that shares one AST walk per file for both `Current` and `Thread.current`
  references.
- Accepted only literal symbol or string bracket access on `Thread.current`.
  Dynamic keys and named thread APIs remain ignored.
- Added `thread_current_read` and `thread_current_write` categories with
  Thread.current-specific triage language, and metadata fields
  `ambient_context_kind` and `thread_current_key`.
- Kept existing `current_receiver_scope` and `current_attribute` metadata for
  Rails CurrentAttributes-style findings.
- Added constant-root, no-argument scope-chain fingerprints for repeated query
  receivers, such as `Order.active`, while keeping dynamic scopes and local
  relation receivers ignored.
- Added `receiver_shape` metadata so calibration artifacts can distinguish
  constant receivers from scope-chain receivers without changing category
  semantics.

## 2026-07-02: Finder and negative repeated query criteria

Task: start on the next 2 big tasks, keep using agenticons, commit the
changes, and provide a detailed comprehensive summary as described in
AGENTS.md.

Additional user requests: add `.claude/settings.local.json` to
`~/.gitignore`, then push upstream. The global ignore entry was already present
at `/Users/sal/.gitignore` line 4, so no home-directory edit was needed.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` as the active calibration fixture
  home. Treat `/private/tmp` calibration paths as historical only.
- Keep `MetzProject/RepeatedQueryCriteria` candidate opt-in and not
  default-output eligible.
- Do not promote, validate, downrank, or retune thresholds in this pass.
- Add only multi-key hash criteria for `find_by`,
  `find_or_initialize_by`, `find_or_create_by`, and simple
  `where.not(...)` calls whose receiver is a constant or conservative
  constant-root no-argument scope chain.
- Keep dynamic SQL strings, single-key lookups, dynamic hashes, bang finders,
  `exists?`, `take`, association/local receivers, dynamic scope chains,
  positive/negative query normalization, and broader relation APIs out of
  scope.

Change type: feature.

Verbatim task statement: "Ok go ahead and start on the next 2 big tasks and
keep using agenticons and at the end commit the changes. Then give me a detail
and comprehensive summary as described in AGENTS.md"

Agenticons:

- `planner: next two task selection` recommended repeated multi-key finder
  hash criteria and negative `where.not` hash criteria as the next bounded
  analyzer tasks.
- `helper_worker: analyzer backlog reconnaissance` recommended
  evidence-first caution on broader analyzer backlog items and warned against
  promotion/default-output changes without more calibration.

Verification status:

- Red focused test before implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb` failed with
    23 runs, 55 assertions, 0 failures, 2 errors because repeated finder and
    negative `where.not` examples returned no finding.
- Green focused test after implementation:
  - `bundle exec ruby -Ilib -Itest
    test/metz_scan/analyzers/repeated_query_criteria_test.rb`: 23 runs,
    76 assertions, 0 failures, 0 errors.
- Manifest-backed calibration smoke over
  `tmp/project-analyzer-calibration/project_analyzer_targets.yml` with
  `--no-write`:
  - `MetzProject/RepeatedQueryCriteria`: 15 findings and 15 offenses;
    `project_analyzer_category`:
    `scoped_association_where_criteria=8`,
    `compound_association_where_criteria=2`,
    `polymorphic_where_criteria=1`, `where_hash_criteria=4`.
  - Operation metadata in the current sample splits as `filter=6` and
    `finder=9`; query method metadata splits as `where=6` and `find_by=9`.
    The active fixture set did not add a repeated `where.not` finding at the
    current threshold.
- Full local gates passed:
  - `bundle exec rake`: 444 runs, 1891 assertions, 0 failures, 0 errors,
    2 skips.
  - `bundle exec rubocop`: 190 files inspected, no offenses.
  - `bin/check_dependency_direction`: passed.
  - `bin/check_sample_app_frozen`: passed.
  - `bin/check_dogfood`: passed with accepted project-analyzer baseline of
    0 findings.
  - `git -c core.fsmonitor=false diff --check`: passed.

Implementation decisions:

- Added query method and query operation metadata to repeated query findings.
  Current operations are `filter`, `negative_filter`, and `finder`; current
  methods are `where`, `where.not`, `find_by`, `find_or_initialize_by`, and
  `find_or_create_by`.
- Included query method in the repeated-query fingerprint so positive filters,
  negative filters, and finder lookups with the same receiver and criteria keys
  do not group together.
- Kept key-shape categories unchanged and used operation-aware message
  language for finder and negative-filter findings.
- Added tests for finder reporting, finder/where separation, ignored
  single-key and dynamic finder queries, negative `where.not` reporting,
  positive/negative where separation, and ignored single-key and dynamic
  negative queries. Finder reporting is covered for `find_by`,
  `find_or_initialize_by`, and `find_or_create_by`.

## 2026-07-02: Repeated query criteria calibration-quality checkpoint

Task: proceed with the recommendation to review the 15
`MetzProject/RepeatedQueryCriteria` calibration findings before expanding the
analyzer again, while keeping loops and agenticons in use.

Scope boundaries:

- Use `tmp/project-analyzer-calibration/apps` and the local calibration
  artifact from the finder/negative-filter slice as active evidence.
- Leave `docs/repeated-query-criteria-strategy-review.md` untracked and
  unstaged per user request.
- Do not add an ignore rule for the untracked strategy report.
- Make no analyzer behavior, threshold, status, or default-output changes in
  this checkpoint.

Agenticons:

- `helper_worker: repeated query calibration quality review` independently
  classified the 15 current findings for usefulness/noise and recommended
  readiness boundaries.

Evidence summary:

- The helper classified 12 of 15 findings as useful manual-review design
  prompts and 3 as mostly mechanical or expected.
- Mechanical/expected findings were `Badge.find_by(enabled, id)`,
  `GroupUser.where(group_id, user_id)`, and
  `TopicUser.where(topic_id, user_id)`.
- Useful prompt families included post-within-topic lookups, locale-scoped
  localization lookups, polymorphic comment lookups, domain-block lookups,
  custom emoji domain/shortcode lookups, and follow-graph lookups.
- The evidence does not justify validated status, default-output eligibility,
  more query-form expansion, or threshold changes.

Decision:

- Keep `MetzProject/RepeatedQueryCriteria` candidate-only.
- Do not expand to dynamic receivers, association receivers, SQL strings,
  joins, merges, Arel, single-key finders, `exists?`, `take`, or bang finders.
- Before changing analyzer mechanics, run a follow-up calibration slice that
  separates pure association-table membership lookups from business-named
  lookup concepts.

## 2026-07-02: Package and subclass pressure evidence loops

Task: review `logs/repeated-query-criteria-strategy-review.md` and start on
the next two big tasks while continuing to use agenticons.

Scope boundaries:

- Treat the repeated-query strategy review as local log context only; `logs/`
  remains ignored.
- Use `tmp/project-analyzer-calibration/apps` as the active fixture home.
- Do not expand `RepeatedQueryCriteria` further in this pass.
- Make no analyzer behavior, threshold, status, or default-output changes.
- Treat `/private/tmp` calibration paths as historical only.

Agenticons:

- `planner: next two task selection after repeated-query strategy` recommended
  `SubclassOverridePressure` medium-finding calibration quality first, then
  `PackageDependencyPressure` evidence-gap review.
- `helper_worker: package and subclass pressure evidence` confirmed both
  analyzers look behavior-stable and that the next useful work is calibration
  documentation, not detector logic.

Evidence:

- `MetzProject/SubclassOverridePressure` active-manifest calibration:
  106 findings and 106 offenses; `low=76`, `medium=30`;
  `project_analyzer_category`: `broad_root_override=76`,
  `abstract_hook_override=18`, `cooperative_override=5`,
  `replacement_override=7`.
- The 30 medium subclass findings are concrete but mixed:
  - useful hook-protocol prompts include Discourse auth/provider hooks,
    Discourse `ProblemCheck`, Mastodon `ActivityPub::Activity`,
    OpenFoodNetwork reporting templates, and some Spree calculator/export
    hooks;
  - likely mechanical or context-heavy families include
    `DiscourseDev::Record`, settings/theme extension APIs, constructor
    cooperation, and commerce extension-point APIs.
- `MetzProject/PackageDependencyPressure` active-manifest calibration:
  39 findings and 39 offenses; `low=38`, `medium=1`;
  `project_analyzer_category`: `shared_dependency=38`,
  `package_boundary=1`.
- The only medium package-boundary finding remains
  `OpenFoodNetwork::ScopeVariantToHub`; the rest of the sample is broad shared
  dependency pressure already downranked.

Decisions:

- Keep both analyzers candidate-only and opt-in.
- Do not promote either analyzer or make either default-output eligible.
- Do not change thresholds or add classifier rules from this evidence alone.
- For `SubclassOverridePressure`, the next evidence task is to separate
  deliberate extension-point families from design-pressure hook protocols
  across more targets while preserving broad-root downranking.
- For `PackageDependencyPressure`, the next evidence task is to find broader
  independent medium package-boundary examples or park the analyzer until such
  evidence appears.

## 2026-07-02: Pressure evidence disposition follow-up

Task: review `logs/repeated-query-criteria-strategy-review.md` and start on
the next two big tasks while continuing to use agenticons.

Prerequisite completed:

- Pushed the existing local baseline commits before starting new work:
  `24dcc46` (`Ignore local logs directory`) and `9e26da0`
  (`Record pressure analyzer evidence loops`).

Scope boundaries:

- Keep `RepeatedQueryCriteria` parked; do not expand query forms.
- Use only active fixtures under `tmp/project-analyzer-calibration/apps`.
- Treat `/private/tmp` calibration paths as historical only.
- Make no analyzer behavior, threshold, status, classifier, or default-output
  changes.

Agenticons:

- `planner: next task selection after pressure evidence loops` recommended
  `SubclassOverridePressure` extension-point calibration and
  `PackageDependencyPressure` evidence-gap disposition.
- `helper_worker: next evidence candidates` agreed that existing commits should
  be pushed first and that readiness reporting is already adequate; the next
  value is evidence expansion/refinement.
- `helper_worker: subclass extension-point calibration` split the 30 medium
  subclass findings into 18 design-pressure hook protocols, 5 deliberate
  extension APIs, 5 setup/mechanical families, and 2 needs-context
  replacements.
- `helper_worker: package evidence-gap disposition` found no unused active
  fixture scan paths likely to produce another independent medium
  package-boundary example.

Evidence and decisions:

- `MetzProject/SubclassOverridePressure` remains candidate-only. The 18
  abstract-hook findings are useful design-pressure prompts, while provider,
  rule, setup, settings, and constructor families show that the medium bucket
  still mixes intentional extension APIs and mechanical bookkeeping. No
  behavior change is justified from this pass alone.
- `MetzProject/PackageDependencyPressure` remains candidate-only and should be
  parked pending new approved targets. The active manifest already covers the
  meaningful repo-local Ruby roots; remaining omitted paths are setup/test
  noise already excluded by analyzer design. The only medium finding remains
  `OpenFoodNetwork::ScopeVariantToHub`.
- Neither analyzer should be promoted, made default-output eligible, retuned,
  or given app-specific suppressions from this evidence.

## 2026-07-02: Repeated query readiness and backlog boundary

Task: review `logs/repeated-query-criteria-strategy-review.md` again and start
the next two substantial tasks while continuing to use agenticons.

Scope boundaries:

- Keep `MetzProject/RepeatedQueryCriteria` candidate opt-in and not
  default-output eligible.
- Do not expand repeated-query detector scope.
- Make no analyzer behavior, threshold, status, classifier, or default-output
  changes.
- Use active calibration fixtures under `tmp/project-analyzer-calibration/apps`;
  treat `/private/tmp` calibration paths as historical only.

Agenticons:

- `planner: next two tasks after pressure disposition` recommended
  membership-vs-domain calibration for `RepeatedQueryCriteria` as the highest
  priority. It also identified another subclass extension-point pass, but that
  had already been completed and committed in `4976e46`.
- `helper_worker: repeated query readiness evidence` confirmed the active
  repeated-query evidence shape: 15 candidate medium manual-review findings,
  with 12 useful prompts and 3 mechanical or expected lookups. It also flagged
  that README/user-facing docs blurred supported `where.not` behavior with
  active-fixture evidence.

Tasks completed:

- Updated user-facing repeated-query documentation to distinguish detector
  support from active-fixture evidence: `where.not` remains supported and
  test-covered, but no active fixture currently produces a repeated
  `where.not` finding at the current threshold.
- Added an explicit readiness/backlog boundary for the current candidate
  analyzer set so future work does not keep reopening already-parked analyzers
  without new evidence.
- Recorded the repeated-query membership-vs-domain split as a calibration
  boundary: business-named lookup concepts currently form the stronger signal,
  while `Badge.find_by(enabled, id)` and join-table membership lookups remain
  mechanical examples to watch rather than suppress.

Evidence and decisions:

- `MetzProject/RepeatedQueryCriteria` remains candidate-only. The current
  evidence does not justify validated status, default-output eligibility, query
  form expansion, membership-table suppression, or threshold changes.
- `MetzProject/PackageDependencyPressure` remains parked until new approved
  targets can produce independent medium package-boundary evidence.
- `MetzProject/SubclassOverridePressure` remains candidate-only; the previous
  disposition pass already documented the current medium-family split.

## 2026-07-02: Calibration readiness output and evidence-led backlog

Task: update `logs/repeated-query-criteria-strategy-review.md` and then start
the next two substantial tasks while continuing to use agenticons.

Change type: feature.

Scope boundaries:

- Keep analyzer behavior, status, thresholds, classifiers, and default-output
  policy unchanged.
- Do not expand `MetzProject/RepeatedQueryCriteria`.
- Use active calibration fixtures under `tmp/project-analyzer-calibration/apps`.
- Treat `/private/tmp` calibration paths as historical only.

Agenticons:

- `planner: readiness/backlog task selection` recommended making
  project-analyzer readiness visible and then running an evidence-led backlog
  selection pass.
- `helper_worker: readiness reporting surface` recommended putting readiness
  in the calibration artifact pipeline rather than `scan` output or analyzer
  logic, so the surface stays tied to evidence.

Tasks completed:

- Updated the ignored local strategy report to record that the repeated-query
  quality checkpoint is complete and that the next work should be readiness
  visibility plus evidence-led backlog selection.
- Added a structured readiness catalog to the calibration evidence runner.
  `summary.json`, generated `summary.md`, and compact `--text` output now carry
  analyzer disposition, evidence boundary, next useful task, and explicit
  not-next boundary.
- Ran the evidence-led backlog pass over unresolved candidates. The next
  evidence target is `MetzProject/ImplicitContextPressure`, not another
  repeated-query expansion.

Evidence and decisions:

- `MetzProject/ImplicitContextPressure`: 11 findings and 11 offenses, all
  medium manual-review findings; category split is `root_current_write=5`,
  `namespaced_current_write=5`, and `thread_current_write=1`. This should get
  the next focused useful-vs-mechanical quality review.
- `MetzProject/NamespaceLeakPressure`: 34 findings and 34 offenses, with
  `low=31`, `medium=3`, `shared_namespace=31`, and `namespace_boundary=3`.
  Keep candidate-only; do not promote or add app-specific suppressions.
- `MetzProject/RepeatedQueryCriteria`: 15 findings and 15 offenses, still
  candidate-only; no further query-form expansion.

## 2026-07-02: Implicit context quality pass and readiness catalog

Task: update `logs/repeated-query-criteria-strategy-review.md` and then start
on the next two substantial tasks while continuing to use agenticons.

Change type: feature.

Verbatim task statement: "Update logs/repeated-query-criteria-strategy-review.md
and then start on the next 2 big tasks. Keep using agenticons"

Scope boundaries:

- Keep `MetzProject/ImplicitContextPressure` candidate opt-in and not
  default-output eligible.
- Do not change analyzer detection, thresholds, status, categories, triage
  severity, suppressions, or default-output policy.
- Use active calibration fixtures under `tmp/project-analyzer-calibration/apps`;
  treat `/private/tmp` calibration paths as historical only.
- Keep `logs/repeated-query-criteria-strategy-review.md` local-only and
  uncommitted because `logs/` is locally ignored.

Agenticons:

- `planner: ImplicitContextPressure next-task selection` recommended two tasks:
  run the focused ImplicitContextPressure quality pass, then refresh generated
  readiness inputs from that review. It explicitly kept thresholds, status,
  default-output eligibility, and detector scope unchanged.
- `helper_worker: ImplicitContextPressure finding classification` classified the
  11 active findings as mostly framework-state plumbing, with one useful
  execution-identity prompt and one borderline `Current.user` fallback.

Tasks completed:

- Updated the ignored local strategy report to record that readiness output is
  complete and that the next evidence work is ImplicitContextPressure quality
  review plus generated-catalog refresh.
- Ran the focused active-manifest quality pass for
  `MetzProject/ImplicitContextPressure` and classified the current 11 findings:
  9 mechanical framework-state signals, 1 useful design-pressure prompt, and
  1 needs-context fallback.
- Updated the generated readiness catalog so compact text, Markdown, and JSON
  no longer say the current signal still needs its first quality pass.
- Updated calibration notes with the quality split and explicit not-next
  boundary.

Evidence and decisions:

- `MetzProject/ImplicitContextPressure` remains candidate-only. The current
  sample is dominated by mechanical request-boundary, import-job, and
  infrastructure state.
- The only clear useful prompt is Chatwoot `Current.executed_by`, because
  ambient execution identity crosses services, model concerns, and dispatch
  metadata while changing activity-message content.
- Chatwoot `Current.user` remains needs-context because the notable
  `NotificationBuilder` sample is a `secondary_actor` fallback that may be
  intentional builder API shape.
- No analyzer behavior change, suppression, promotion, default-output
  eligibility, or new global-access form is justified by this sample.

## 2026-07-02: Namespace leak quality pass and next evidence boundary

Task: update `logs/repeated-query-criteria-strategy-review.md` and then start
on the next two substantial tasks while continuing to use agenticons.

Change type: feature.

Verbatim task statement: "Update logs/repeated-query-criteria-strategy-review.md
and then start on the next 2 big tasks. Keep using agenticons"

Scope boundaries:

- Keep `MetzProject/NamespaceLeakPressure` candidate opt-in and not
  default-output eligible.
- Do not change analyzer detection, thresholds, status, shared-namespace
  classifier rules, suppressions, or default-output policy.
- Use active calibration fixtures under `tmp/project-analyzer-calibration/apps`;
  treat `/private/tmp` calibration paths as historical only.
- Keep `logs/repeated-query-criteria-strategy-review.md` local-only and
  uncommitted because `logs/` is locally ignored.

Agenticons:

- `planner: next task selection after ImplicitContextPressure boundary`
  recommended a focused `NamespaceLeakPressure` quality pass as the next
  project-direction task, followed by broader approved calibration evidence
  before reopening parked analyzers.
- `helper_worker: calibration artifact renderer reconnaissance` confirmed the
  full-RuboCop `MarkdownRenderer` class-length issue is isolated maintenance
  debt, not a project-direction task. It recommended preserving artifact output
  with exact tests if that cleanup is handled later.

Tasks completed:

- Updated the ignored local strategy report to mark `9cce511` as completed and
  stop pointing back at the already-finished ImplicitContextPressure work.
- Ran the active-manifest `MetzProject/NamespaceLeakPressure` quality pass:
  34 findings and 34 offenses, with `namespace_boundary=3` medium findings and
  `shared_namespace=31` low findings.
- Classified the three medium findings: 1 useful design-pressure prompt
  (`Badge::Trigger::PostRevision`) and 2 needs-context payment extension/provider
  prompts (`Spree::Gateway::StripeSCA` and
  `Spree::PaymentMethod::StoreCredit`).
- Updated the generated readiness catalog and calibration notes so the next
  step is broader calibration targets, not promotion, suppressions, payment
  downranking, threshold changes, or detector expansion.

Evidence and decisions:

- `MetzProject/NamespaceLeakPressure` remains candidate-only. The current
  medium evidence is plausible but too narrow because two of three examples are
  commerce/payment extension types.
- `Badge::Trigger::PostRevision` is useful because post creation and revision
  flows pass a nested badge trigger constant into `BadgeGranter`, making caller
  code know the trigger namespace.
- The Spree/OpenFoodNetwork payment findings need more context because concrete
  provider/payment-method class selection may be intentional framework extension
  wiring.
- Broader approved calibration targets are the next evidence task before any
  status/default-output discussion for namespace leaks.

## 2026-07-02: Redmine calibration target intake and expanded evidence

Task: start on the next two substantial tasks while continuing to use
agenticons.

Change type: feature.

Verbatim task statement: "Start on the next 2 big tasks. Keep using agenticons"

Scope boundaries:

- Add evidence, not analyzer behavior. Do not change detector logic, thresholds,
  statuses, default-output policy, or classifier rules.
- Add exactly one new active calibration target so evidence deltas stay
  attributable.
- Use active calibration fixtures under `tmp/project-analyzer-calibration/apps`;
  treat `/private/tmp` calibration paths as historical only.
- Keep generated fixture checkouts and result artifacts ignored; commit only the
  tracked manifest, readiness/catalog tests, and docs.

Agenticons:

- `planner: next evidence target selection` recommended adding one
  domain-distinct calibration fixture first, then updating readiness/backlog
  guidance from the new evidence. It suggested Redmine as a good first candidate
  because project/issue tracking differs from the current support, social/forum,
  and commerce-heavy targets.
- `helper_worker: calibration target gap analysis` confirmed the current active
  manifest is mostly support, forum/social, and commerce, and identified package
  dependency, namespace leak, implicit context, and repeated query criteria as
  evidence-bound rather than detector-bound.

Tasks completed:

- Added `redmine/redmine` at revision `3386d9595767` to the tracked active target
  manifest with `app` and `lib` scan paths.
- Restored the previously documented initial target checkouts under ignored
  local scratch space for future use, but did not add them to the manifest in
  this slice.
- Ran the five parked candidate analyzers over the expanded manifest. The run
  produced 220 findings and 220 offenses across PackageDependencyPressure,
  NamespaceLeakPressure, ImplicitContextPressure, RepeatedQueryCriteria, and
  SubclassOverridePressure.
- Updated the generated readiness catalog, readiness tests, and calibration docs
  from the Redmine evidence.

Evidence and decisions:

- `MetzProject/PackageDependencyPressure`: 40 findings, with 39 low shared
  dependencies and the same single medium package-boundary prompt. Redmine added
  no independent medium package-boundary finding, so this analyzer remains
  parked pending another domain-distinct target.
- `MetzProject/NamespaceLeakPressure`: 39 findings, with 33 low shared
  namespaces and 6 medium namespace-boundary findings. Redmine added one useful
  `Redmine::Activity::Fetcher` prompt and two needs-context SCM extension
  prompts, `Redmine::Scm::Adapters` and `Redmine::Scm::Base`.
- `MetzProject/ImplicitContextPressure`: unchanged at 11 findings. Redmine did
  not add ambient-context evidence at the current threshold.
- `MetzProject/RepeatedQueryCriteria`: 16 findings. Redmine added
  `Token.where(action, user_id)`, classified as a useful token-lifecycle lookup
  prompt, moving the quality split to 13 useful prompts and 3 mechanical lookups.
- `MetzProject/SubclassOverridePressure`: 114 findings, with 80 low broad-root
  and 34 medium manual-review findings. Redmine added a useful
  `CustomField#type_name` abstract hook plus three SCM adapter replacement
  families that are plausible but likely intentional extension APIs.
- None of the new evidence justifies promotion, default-output eligibility,
  threshold changes, app-specific suppressions, or detector expansion.

## 2026-07-02: Rubygems.org calibration target intake and expanded evidence

Task: start on the next three substantial tasks while continuing to use
agenticons.

Change type: feature.

Verbatim task statement: "Start on the next 3 big tasks. Keep using agenticons"

Scope boundaries:

- Add evidence, not analyzer behavior. Do not change detector logic, thresholds,
  statuses, default-output policy, or classifier rules.
- Add exactly one active calibration target so evidence deltas stay attributable.
- Keep ignored fixture checkouts and result artifacts out of the commit.
- Use the generated readiness catalog as the source for readiness/backlog output.

Agenticons:

- `planner: post-Redmine evidence plan` recommended another one-target evidence
  intake, source-review of only the new or changed medium findings, and a
  readiness/docs refresh. It recommended the already-restored
  `rubygems/rubygems.org` fixture because a package registry broadens the
  domain mix without another issue-tracking target.
- `helper_worker: next target feasibility` recommended `ManageIQ/manageiq` as
  the stronger fresh infrastructure/operations target and `opf/openproject` as
  a larger backup. The slice kept Rubygems.org because it was already restored
  locally and produced useful namespace, implicit-context, and subclass evidence;
  ManageIQ remains the next fresh-target candidate.

Tasks completed:

- Added `rubygems/rubygems.org` at revision `757047af5070` to the tracked active
  target manifest with `app` and `lib` scan paths.
- Ran a discarded signal check with Huginn before the final target decision. It
  added only subclass evidence, so it was not kept in the manifest.
- Ran the five parked candidate analyzers over the expanded Rubygems.org
  manifest. The run produced 231 findings and 231 offenses across
  PackageDependencyPressure, NamespaceLeakPressure, ImplicitContextPressure,
  RepeatedQueryCriteria, and SubclassOverridePressure.
- Source-reviewed the Rubygems.org deltas and updated the generated readiness
  catalog, readiness tests, calibration docs, and local strategy notes.

Evidence and decisions:

- `MetzProject/PackageDependencyPressure`: unchanged at 40 findings, with 39 low
  shared dependencies and the same single medium package-boundary prompt.
  Rubygems.org added no package-pressure evidence at the current threshold, so
  this analyzer remains parked pending a broader infrastructure or operations
  target.
- `MetzProject/NamespaceLeakPressure`: increased to 42 findings, with 33 low
  shared namespaces and 9 medium namespace-boundary findings. Rubygems.org added
  three useful OIDC/security-policy prompts:
  `OIDC::AccessPolicy::Statement`,
  `OIDC::AccessPolicy::Statement::Condition`, and
  `OIDC::TrustedPublisher::GitHubAction`.
- `MetzProject/ImplicitContextPressure`: increased to 12 findings. Rubygems.org
  added `Current.user` from API authentication and ownership/transfer flows,
  classified as a needs-context identity prompt. The quality split is now 9
  mechanical framework-state signals, 1 useful execution-identity prompt, and
  2 needs-context identity prompts.
- `MetzProject/RepeatedQueryCriteria`: unchanged at 16 findings. Rubygems.org
  added no repeated-query findings at the current threshold.
- `MetzProject/SubclassOverridePressure`: increased to 121 findings, with 83 low
  broad-root and 38 medium manual-review findings. Rubygems.org added policy and
  Avo action hook evidence that is useful for calibration but likely includes
  intentional extension APIs.
- None of the new evidence justifies promotion, default-output eligibility,
  threshold changes, app-specific suppressions, or detector expansion.

## 2026-07-02: ManageIQ calibration target intake and expanded evidence

Task: start on the next four substantial tasks while continuing to use
agenticons.

Change type: feature.

Verbatim task statement: "Start on the next 4 big tasks. Keep using agenticons"

Scope boundaries:

- Add evidence, not analyzer behavior. Do not change detector logic, thresholds,
  statuses, default-output policy, or classifier rules.
- Add exactly one active calibration target so evidence deltas stay attributable.
- Keep ignored fixture checkouts and result artifacts out of the commit.
- Treat ManageIQ as an infrastructure/operations sample, not a reason to
  app-special-case findings.

Agenticons:

- `planner: ManageIQ four-task slice review` confirmed the four-task plan:
  materialize ManageIQ `app` and `lib`, add one manifest entry, run the five
  parked candidate analyzers, classify only the ManageIQ deltas, and refresh
  readiness/docs/tests from evidence.

Tasks completed:

- Added `ManageIQ/manageiq` at revision `67749d3468ce` to the tracked active
  target manifest with `app` and `lib` scan paths.
- Hydrated the sparse checkout for `app` and `lib`; the checkout is ignored
  local calibration scratch space.
- Ran the five parked candidate analyzers over the expanded ManageIQ manifest.
  The run produced 248 findings and 248 offenses across
  PackageDependencyPressure, NamespaceLeakPressure, ImplicitContextPressure,
  RepeatedQueryCriteria, and SubclassOverridePressure.
- Source-reviewed the ManageIQ deltas and updated the generated readiness
  catalog, readiness tests, calibration docs, and local strategy notes.

Evidence and decisions:

- `MetzProject/PackageDependencyPressure`: increased to 43 findings, with 40 low
  shared dependencies and 3 medium package-boundary findings. ManageIQ added
  `ActiveRecord::Base`, classified as needs-context framework-root evidence,
  and `Vmdb::Logging`, classified as useful cross-cutting logging dependency
  pressure.
- `MetzProject/NamespaceLeakPressure`: increased to 44 findings, with 33 low
  shared namespaces and 11 medium namespace-boundary findings. ManageIQ added
  `ManageIQ::Reporting::Charting` and `ManageIQ::Reporting::Formatter`, both
  classified as needs-context reporting facade or legacy compatibility surfaces.
- `MetzProject/ImplicitContextPressure`: unchanged at 12 findings. ManageIQ
  added no implicit-context findings at the current threshold.
- `MetzProject/RepeatedQueryCriteria`: unchanged at 16 findings. ManageIQ added
  no repeated-query findings at the current threshold.
- `MetzProject/SubclassOverridePressure`: increased to 133 findings, with 86 low
  broad-root and 47 medium manual-review findings. ManageIQ added credential,
  request, request-task, and request-workflow hook evidence that is useful for
  calibration but likely includes intentional extension points.
- None of the new evidence justifies promotion, default-output eligibility,
  threshold changes, app-specific suppressions, or detector expansion.

## 2026-07-02: Foreman calibration target intake and expanded evidence

Task: start on the next four substantial tasks while continuing to use
agenticons and track elapsed time.

Change type: feature.

Verbatim task statement: "Start on the next 4 big tasks. Keep using agenticons
and track the total time spent/taken to complete the 4 tasks"

Time tracking:

- Started at `2026-07-02 18:24:19 -0700`.
- Evidence tasks, validation, and agenticon reviews completed at
  `2026-07-02 20:51:28 -0700`.
- Elapsed time for the four-task Foreman slice: `02:27:09` (8,829 seconds).

Scope boundaries:

- Add evidence, not analyzer behavior. Do not change detector logic, thresholds,
  statuses, default-output policy, or classifier rules.
- Add exactly one active calibration target so evidence deltas stay attributable.
- Keep ignored fixture checkouts and result artifacts out of the commit.
- Treat Foreman as an infrastructure/provisioning/operations sample, not a
  reason to app-special-case findings.

Agenticons:

- `planner: post-ManageIQ evidence target review` recommended one more
  infrastructure/operations Rails target, then running the five parked candidate
  analyzers, classifying only new deltas, and refreshing readiness/docs/tests.
  It recommended `theforeman/foreman` over larger or less infrastructure-focused
  alternatives.
- `helper_worker: target feasibility` also recommended `theforeman/foreman` as
  the best next target, with `app` and `lib` scan paths, because it should test
  whether ManageIQ's framework-root/logging and subclass-hook prompts
  generalize.

Tasks completed:

- Added `theforeman/foreman` at revision `2eccf03ea835` to the tracked active
  target manifest with `app` and `lib` scan paths.
- Hydrated the sparse checkout for `app` and `lib`; the checkout is ignored
  local calibration scratch space.
- Ran the five parked candidate analyzers over the expanded Foreman manifest.
  The run produced 272 findings and 272 offenses across
  PackageDependencyPressure, NamespaceLeakPressure, ImplicitContextPressure,
  RepeatedQueryCriteria, and SubclassOverridePressure.
- Source-reviewed the Foreman deltas and updated the generated readiness
  catalog, readiness tests, calibration docs, and local strategy notes.

Evidence and decisions:

- `MetzProject/PackageDependencyPressure`: increased to 47 findings, with 42 low
  shared dependencies and 5 medium package-boundary findings. Foreman added
  `Foreman::Logging`, classified as useful cross-cutting logging pressure, and
  `Foreman::Plugin`, classified as needs-context plugin registry or public
  extension-surface evidence.
- `MetzProject/NamespaceLeakPressure`: increased to 49 findings, with 37 low
  shared namespaces and 12 medium namespace-boundary findings. Foreman added
  `Foreman::Renderer::Scope`, classified as needs-context renderer API evidence.
- `MetzProject/ImplicitContextPressure`: unchanged at 12 findings. Foreman added
  no implicit-context findings at the current threshold.
- `MetzProject/RepeatedQueryCriteria`: unchanged at 16 findings. Foreman added
  no repeated-query findings at the current threshold.
- `MetzProject/SubclassOverridePressure`: increased to 148 findings, with 93 low
  broad-root and 55 medium manual-review findings. Foreman added operating
  system, DHCP record, and proxy API hook evidence that is useful for
  calibration but likely includes intentional extension protocols.
- None of the new evidence justifies promotion, default-output eligibility,
  threshold changes, app-specific suppressions, or detector expansion.

## 2026-07-02: Expanded evidence-quality consolidation

Task: start on the next four substantial tasks while continuing to use
agenticons and track elapsed time.

Change type: feature.

Verbatim task statement: "Start on the next 4 big tasks. Keep using agenticons
and track the total time spent/taken to complete the 4 tasks"

Time tracking:

- Started at `2026-07-02 21:06:33 -0700`.
- Evidence tasks, edits, and full local test run completed at
  `2026-07-02 21:15:10 -0700`.
- Elapsed time for the four-task consolidation slice through local tests:
  `00:08:37` (517 seconds).

Scope boundaries:

- Consolidate evidence quality, not analyzer behavior.
- Do not add another calibration target.
- Do not change detector logic, thresholds, statuses, default-output policy, or
  classifier rules.
- Keep generated calibration artifacts and ignored local logs out of the commit.

Agenticons:

- `planner: post-Foreman consolidation plan` recommended four tasks:
  consolidate PackageDependencyPressure evidence, consolidate
  NamespaceLeakPressure evidence, consolidate SubclassOverridePressure evidence,
  and sync readiness/docs/tests around the post-Foreman boundary.
- `helper_worker: package/subclass evidence check` confirmed the current
  package and subclass source-of-truth counts and flagged older ignored
  calibration artifacts as stale relative to the expanded manifest.

Tasks completed:

- Regenerated a focused ignored calibration artifact for package, namespace, and
  subclass evidence:
  `tmp/project-analyzer-calibration/results/20260702-package-namespace-subclass-consolidation`.
- Consolidated `MetzProject/PackageDependencyPressure` around 47 findings:
  42 low shared dependencies and 5 medium package boundaries.
- Consolidated `MetzProject/NamespaceLeakPressure` around 49 findings:
  37 low shared namespaces and 12 medium namespace boundaries.
- Consolidated `MetzProject/SubclassOverridePressure` around 148 findings:
  93 low broad-root findings and 55 medium manual-review findings.
- Updated the generated readiness catalog, readiness assertions, calibration
  docs, and local strategy notes to point away from default target intake and
  toward only generic, non-app-specific classifier design if future evidence
  justifies it.

Evidence and decisions:

- `MetzProject/PackageDependencyPressure`: the medium sample splits into
  3 useful prompts (`OpenFoodNetwork::ScopeVariantToHub`, `Vmdb::Logging`,
  `Foreman::Logging`) and 2 needs-context surfaces (`ActiveRecord::Base`,
  `Foreman::Plugin`). Keep candidate-only and opt-in.
- `MetzProject/NamespaceLeakPressure`: the medium sample splits into
  5 useful domain/security prompts and 7 needs-context public extension,
  facade, payment, reporting, or renderer surfaces. Keep candidate-only and
  opt-in.
- `MetzProject/SubclassOverridePressure`: the medium sample is
  33 `abstract_hook_override`, 9 `cooperative_override`, and
  13 `replacement_override` findings. The categories are useful for future
  classifier design but still mix design-pressure hook contracts with deliberate
  extension protocols and setup conventions.
- None of the consolidated evidence justifies promotion, default-output
  eligibility, threshold changes, app-specific suppressions, detector expansion,
  or another target by default.

## 2026-07-02: Generic classifier supportability checkpoint

Task: start on the next six substantial tasks while continuing to use
agenticons and track elapsed time.

Change type: feature.

Verbatim task statement: "Start on the next 6 big tasks. Keep using agenticons
and track the total time spent/taken to complete the tasks"

Time tracking:

- Started at `2026-07-02 21:31:05 -0700`.
- Evidence review, decision, and edits completed at `2026-07-02 21:34:20 -0700`.
- Final validation/review elapsed time is recorded in the final summary for
  this slice.

Scope boundaries:

- Decide whether generic classifier behavior is supportable from the expanded
  evidence, not whether another target should be added.
- Do not change detector behavior, thresholds, statuses, default-output policy,
  target manifest, or suppressions.
- Keep generated calibration artifacts and ignored local logs out of the commit.

Agenticons:

- `planner: generic classifier checkpoint` recommended pausing detector work.
  It found the current evidence useful for a supportability bar but too mixed
  for a generic, non-app-specific classifier implementation.
- `helper_worker: classifier feasibility check` independently recommended a
  design-only note rather than implementation. It found plausible future
  criteria but concluded the current criteria would rely on brittle lexical or
  domain assumptions.

Tasks completed:

- Built an evidence matrix from the current package, namespace, and subclass
  consolidation artifact.
- Defined the supportability bar for future classifier behavior: generic code or
  index facts, no app/product-name knowledge, positive and negative examples
  across apps, no suppression of useful prompts, and testability without
  fixture-specific allowlists.
- Applied that bar to framework roots, plugin registries, payment/SCM/reporting
  and renderer surfaces, and hook protocols.
- Recorded the decision to pause detector behavior work.
- Updated generated readiness catalog wording and readiness assertions so
  generated output says not to implement classifier behavior yet.
- Updated calibration docs and the local strategy report with the pause
  decision and next-project direction.

Evidence and decisions:

- `ActiveRecord::Base` is generically identifiable, but one framework-root
  package-boundary prompt is too narrow for a generic downranking rule.
- `Foreman::Plugin`, SCM adapters, payment providers, reporting facades, and
  renderer scopes may be public extension surfaces, but classifying them from
  terms such as `Plugin`, `Adapter`, `Gateway`, `Formatter`, `Renderer`, or
  `Scope` would be brittle.
- Subclass hook evidence has strong design-pressure signals, but the same
  medium categories still mix hook contracts with deliberate extension APIs and
  setup conventions.
- Do not implement classifier behavior, promote analyzers, retune thresholds,
  change default-output eligibility, add app-specific suppressions, or add
  another target from this evidence.

## 2026-07-03: Markdown renderer maintenance recovery

Task: start on the next six substantial tasks while continuing to use
agenticons and track elapsed time.

Change type: refactor.

Verbatim task statement: "Start on the next 6 big tasks. Keep using agenticons
and track the total time spent/taken to complete the tasks"

Time tracking:

- Started at `2026-07-03 08:27:49 -0700`.
- Planning, focused implementation, and focused test/RuboCop checks completed
  at `2026-07-03 08:33:17 -0700`.
- Final validation/review elapsed time is recorded in the final summary for
  this slice.

Scope boundaries:

- Restore repo-health by decomposing
  `ProjectAnalyzerEvidenceRunner::MarkdownRenderer`.
- Preserve `MarkdownRenderer.new(summary).call` as the public rendering
  interface used by artifact writing.
- Preserve generated Markdown output exactly for the representative section
  mix; no analyzer behavior, readiness semantics, target manifest, threshold,
  promotion, or suppression changes.

Agenticons:

- `planner: six-task slice selection` recommended MarkdownRenderer
  decomposition and full RuboCop recovery as the next coherent non-detector
  maintenance slice.
- `helper_worker: maintenance surface check` independently confirmed the known
  guardrail gap was RuboCop class length on `MarkdownRenderer`; focused tests
  and full tests were otherwise healthy before this slice.

Tasks completed:

- Confirmed the current failing guardrail was `MarkdownRenderer` class length
  (`116/100`) under both `Metrics/ClassLength` and `Metz/ClassesTooLong`.
- Added an exact representative Markdown fixture covering header metadata,
  target rows, rule rows, readiness, notable findings, pipe escaping, and
  breakdowns.
- Split Markdown rendering by section boundary into small internal renderers:
  header, targets, rules, readiness, notable findings, and breakdowns.
- Centralized table-cell escaping narrowly for the sections that need it.
- Kept artifact writer and runner APIs unchanged.
- Ran focused renderer and evidence-runner tests plus targeted RuboCop after
  the split.

Evidence and decisions:

- The exact-output fixture intentionally preserves the existing double blank
  line between readiness/notable and notable/breakdown sections, because this
  slice is maintenance and should not churn generated artifacts.
- The renderer remains a private calibration artifact implementation detail;
  no new public API was introduced.

## 2026-07-03: Calibration artifact release smoke

Task: commit the completed renderer slice, then start on the next six
substantial tasks while continuing to use agenticons and track elapsed time.

Change type: chore.

Verbatim task statement: "Commit everything into logical commits. Then start on
the next 6 big tasks. After you are done, commit again. Keep using agenticons
and track the total time spent/taken to complete the tasks"

Time tracking:

- Combined request started at `2026-07-03 08:48:12 -0700`.
- First commit completed as `8753614 Decompose project analyzer markdown renderer`.
- Planning, focused implementation, and focused checks for this second slice
  completed at `2026-07-03 08:56:19 -0700`.
- Final validation/review elapsed time is recorded in the final summary for
  this request.

Scope boundaries:

- Improve calibration artifact/release confidence only.
- Do not change analyzer behavior, readiness wording, thresholds, statuses,
  default-output policy, target manifest, suppressions, or calibration targets.
- Keep `logs/repeated-query-criteria-strategy-review.md` local/ignored and out
  of commits unless explicitly requested.

Agenticons:

- `planner: next six-task slice selection` recommended artifact writer
  round-trip coverage, calibration CLI write-path smoke, checklist drift
  protection, release checklist calibration smoke, CI calibration smoke, and
  notes.
- `helper_worker: next maintenance evidence` recommended a high-volume
  report-language pass, but that conflicted with the latest strategy report's
  "do not add another target by default" boundary. I chose the planner's
  artifact/release-maintenance path.

Tasks completed:

- Added artifact writer round-trip coverage proving persisted JSON records the
  returned artifact paths and persisted Markdown equals the renderer output for
  that persisted summary.
- Added command-level write-path smoke for
  `bin/check_project_analyzer_calibration --text` with deterministic
  `--output-dir` and `--run-id`.
- Added release checklist drift coverage comparing the issue template body from
  `## Verification` onward with `RELEASE_CHECKLIST.md`.
- Added a release checklist calibration artifact smoke command for
  `test/fixtures/sample_app`.
- Added the same calibration smoke command to CI.
- Ran focused release checklist, calibration evidence runner, and calibration
  smoke checks after implementation.

Evidence and decisions:

- `bundle exec ruby bin/check_project_analyzer_calibration --text --no-write
  test/fixtures/sample_app` passes locally and reports one low-confidence
  validated opt-in `MetzProject/DeepInheritanceTree` finding, plus generated
  readiness and breakdown sections.
- The calibration smoke uses only the checked-in sample fixture and
  `--no-write`, so CI does not depend on ignored real-app calibration checkouts
  or generated artifact directories.

## 2026-07-03: Release issue and package metadata hardening

Task: commit any existing work, then start on the next six substantial tasks
while continuing to use agenticons and track elapsed time.

Change type: chore.

Verbatim task statement: "Commit everything into logical commits. Then start on
the next 6 big tasks. After you are done, commit again. Keep using agenticons
and track the total time spent/taken to complete the tasks"

Time tracking:

- Combined request started at `2026-07-03 09:07:17 -0700`.
- The initial working tree was clean and already ahead by the prior two
  release-maintenance commits, so there was no pre-existing work to commit.
- Planning, focused implementation, and focused checks completed at
  `2026-07-03 09:13:27 -0700`.
- Final validation/review elapsed time is recorded in the final summary for
  this request.

Scope boundaries:

- Harden release issue preview and package metadata/file-list smoke coverage.
- Do not change analyzer behavior, readiness wording, thresholds, statuses,
  default-output policy, target manifest, suppressions, or calibration targets.
- Keep `logs/repeated-query-criteria-strategy-review.md` local/ignored and out
  of commits unless explicitly requested.

Agenticons:

- `planner: release-hardening slice` recommended dry-run coverage for
  `bin/create_release_issue`, making dry-run independent of `gh`, release
  metadata/version checks, gem file-list smoke checks, checklist/template
  updates, and notes.
- `helper_worker: release-readiness evidence` found the published-gem smoke
  path already well covered and recommended a docs-only discoverability pass.
  I chose the planner's release-hardening path because it exposed an untested
  script behavior and package metadata surface.

Tasks completed:

- Added subprocess coverage for `bin/create_release_issue --dry-run`.
- Changed `bin/create_release_issue` so dry-run no longer requires `gh`; real
  issue creation still does.
- Added release metadata checks for version alignment, `metz-scan`'s
  `rubocop-metz` dependency family, Ruby/package metadata, and runtime-only gem
  file lists.
- Added release checklist assertions for the new metadata and release issue
  smoke commands.
- Updated `RELEASE_CHECKLIST.md` and the GitHub issue template with the new
  smoke commands.
- Ran focused release issue, release metadata, release checklist, and script
  syntax checks after implementation.

Evidence and decisions:

- The red run proved `bin/create_release_issue --dry-run` previously failed
  without `gh`, even though previewing a release issue should not need GitHub
  CLI availability.
- The real issue-create path still checks for `gh` immediately before calling
  `gh issue create`.
- Gem file-list assertions are intentionally essential-inclusion/exclusion
  checks rather than an exact complete file list, to avoid brittle packaging
  tests.
