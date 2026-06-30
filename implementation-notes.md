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
