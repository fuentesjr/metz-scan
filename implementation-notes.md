# Implementation Notes

This file keeps recent implementation context only. Older chronological notes
were archived to
`docs/archive/implementation-notes-2026-06-29-through-2026-07-03.md` during the
2026-07-03 release-readiness housekeeping pass.

Use `PROJECT_TRACKER.md` for the current direction, next queue, parked work, and
latest checkpoint. Add new notes here only when a slice needs more durable
detail than the tracker should carry.

## 2026-07-06: #33 default scan excludes

Task: GitHub issue #33 / tracker Next Queue task 1 — default Metz-only scans
must honor target project `AllCops: Exclude` while keeping Metz cop defaults.

Decision:

- Split file selection from cop configuration. Default scan now asks RuboCop for
  target files using the project config first, then invokes RuboCop on that
  explicit file list with `--force-default-config --enable-all-cops --only
  Metz`. This keeps project-level excludes without letting project cop
  thresholds/disables override stock Metz defaults.
- Project analyzers use the same project-config target-file helper in default
  mode so wrapper-level findings do not reintroduce files RuboCop excluded.
- Invalid project config still falls back to forced-default target discovery,
  preserving the previous default-mode behavior of not failing on unreadable
  project config.

## 2026-07-05: Dogfooding round on released 0.5.0

Task: tracker Next Queue task 1 — qualitative dogfooding round, rubygems.org
exit criterion 2.

Scope boundaries: judge output only; no fixes to what the round found (that
became queue tasks 1-2). Target checkouts under
`tmp/project-analyzer-calibration/apps/` were read, never modified.

Decisions:

- Installed the released GitHub Packages gems into a clean Bundler consumer
  (README install path) and ran scans via `BUNDLE_GEMFILE` from each target
  root, rather than editing target Gemfiles — same gems a user gets, without
  mutating the checkouts.
- Targets: lobsters + huginn (no `.rubocop.yml`, satisfying the small-project
  slot), maybe, redmine, rubygems.org.
- Both headline defects were verified against target source before filing;
  #33 also got a minimal released-gem repro (default vs `--all-cops`
  exclude disagreement, rooted at `--force-default-config` in
  `lib/metz_scan/commands/scan/runner.rb:38`).

Verification status: notes and repro are in
`docs/dogfooding/2026-07-05-round-0.5.0.md`; #33 filed. The second issue
(`ControllersTooManyDirectCollaborators` miscounting) is drafted but unfiled —
issue creation was permission-blocked mid-session; the draft needs user
approval to file.

## 2026-07-05: v0.5.0 release target prep

Task: tracker Next Queue task 1 — release the #31/#32 fixes to GitHub
Packages.

Scope boundaries:

- Prepare the `0.5.0` release target only; tagging and publishing wait for
  explicit release authorization.
- No behavior changes beyond version surfaces.

Decisions:

- Chose `0.5.0` (not `0.4.1`) because #31 is a default-behavior change: scans
  now default to Metz-only output and `--all-cops` is required for the old
  full-suite behavior.
- Bumped both gem version constants, the lockfile, the README install
  example, and the release issue dry-run expectations to `0.5.0`.
- Drafted `docs/releases/v0.5.0.md` centered on the #31/#32 fixes and the
  `--all-cops` migration note.

## 2026-07-05: Direction review and course correction

Task: review whether the project was proceeding in the right direction.

Findings: effort had drifted inward — since 2026-06-25, docs/tracker churn
(18.2k lines) ran 2.6x product-code churn (6.8k), the test suite (10.3k lines)
outgrew both gems' product code (8.8k), and the extensive internal
verification surface still missed the headline UX defect (#31) that one
afternoon of ctxpack dogfooding found immediately.

Decisions:

- Direction is now a quality-gated path to rubygems.org with four concrete
  exit criteria (see `PROJECT_TRACKER.md` Current Direction). The gate is
  deliberately concrete so "not good enough yet" cannot become indefinite.
- Test hardening is declared done; fixture/coverage sweeps are parked as a
  class with a defect-based reopen trigger.
- Dogfooding on real codebases is the direction engine going forward;
  qualitative "was this finding worth reading?" evidence outranks drift
  counts.
- Added standing rules capping checkpoint prose and requiring queue work a
  tool user would notice over work only this repo's tests would notice.
- Both gem names verified unclaimed on rubygems.org (API 404) on 2026-07-05.

## 2026-07-05: Codex-delegated queue tasks 1-4 (test-hardening fixtures)

Task: delegate tracker Next Queue tasks 1-4 to Codex (session
`019f3434-3ed8-7ec3-8fb1-bf23ae145220`) with agenticons, then review and
update the tracker.

Scope boundaries: test files and fixtures only; no production script changes,
no live lookups, no credential precedence changes, no clone cleanup changes.

Decisions:

- `RENDER_ISSUE_COMMENT_TRACKER_PATH` fixture decoupling removes the recurring
  breakage risk where every tracker edit could invalidate the #25 exact-output
  test.
- The default gem-credentials test reuses the existing fake-HOME subprocess
  pattern rather than adding a new harness.

Verification: Codex ran focused tests, fast/slow suites, full rubocop, diff
check, strategic validation, and design review, all clean. The orchestrating
session independently reran the three focused test files (18 runs, 136
assertions, 0 failures) and reviewed the full diff.

Follow-up: dogfooding issues #31/#32 were triaged into queue positions 1-2;
see `PROJECT_TRACKER.md`.



Task: start the next four large tracker tasks, keep using agenticons, track
elapsed time, update `PROJECT_TRACKER.md`, and commit.

Scope boundaries:

- Keep release readiness conservative.
- Do not publish gems, create tags, or create GitHub releases.
- Do not change analyzer behavior, thresholds, statuses, default-output
  policy, suppressions, or calibration targets.
- Preserve historical implementation context in an archive instead of deleting
  it.

Decisions:

- Deferred a new release tracking issue because both gems still report version
  `0.3.0`, and GitHub already has a `v0.3.0` release. The next release issue
  should wait for an explicit next version target.
- Moved the tracked calibration target manifest out of the ignored `tmp/` tree
  so future tracked edits are visible without special Git handling.
- Removed stale ignored local gem artifacts for release hygiene.

## 2026-07-03: v0.4.0 release target prep

Task: start the next four large tracker tasks, keep using agenticons, track
elapsed time, update `PROJECT_TRACKER.md`, and commit.

Scope boundaries:

- Prepare the next release target only.
- Do not publish gems, create tags, create GitHub releases, or push.
- Do not change analyzer behavior, thresholds, statuses, default-output
  policy, suppressions, or calibration targets.

Decisions:

- Chose `0.4.0` as the next release target because `v0.3.0..HEAD` includes
  new opt-in candidate analyzers and calibration/reporting surfaces, not only
  release-maintenance changes.
- Bumped both gem version constants and the lockfile to `0.4.0`.
- Updated the README install example and release issue dry-run expectations to
  match `0.4.0`.
- Drafted `docs/releases/v0.4.0.md` as the release-note source for the next
  release checklist.

## 2026-07-03: v0.4.0 local release verification

Task: start the next four large tracker tasks, keep using agenticons, track
elapsed time, update `PROJECT_TRACKER.md`, and commit.

Scope boundaries:

- Verify the committed `0.4.0` release-prep head locally.
- Do not push, publish gems, create tags, create GitHub releases, or open the
  release checklist issue in this slice.
- Do not change analyzer behavior, thresholds, statuses, default-output
  policy, suppressions, or calibration targets.

Verification:

- `bundle exec rake` passed: 465 runs, 2055 assertions, 0 failures, 0 errors,
  2 skips.
- `bundle exec rubocop` passed: 196 files inspected, no offenses.
- `bin/check_dependency_direction` passed.
- `bin/check_sample_app_frozen` passed.
- `bundle exec ruby -Ilib -Itest test/metz_scan/release_metadata_test.rb`
  passed: 4 runs, 16 assertions, 0 failures, 0 errors.
- `bundle exec ruby -Ilib -Itest test/metz_scan/create_release_issue_test.rb`
  passed: 2 runs, 18 assertions, 0 failures, 0 errors.
- `bin/create_release_issue --dry-run` rendered `Release v0.4.0`.
- `bin/check_ci_parity` passed against a clean clone, including full suite,
  RuboCop, calibration smoke, dependency-direction guard, and sample-app
  freeze guard.

Decision:

- Local release readiness is green. The next step is to push the local commits,
  watch CI, then open or update the `Release v0.4.0` checklist issue only after
  remote CI is green.
