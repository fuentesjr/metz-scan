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
