# Implementation Notes

This file keeps recent implementation context only. Older chronological notes
were archived to
`docs/archive/implementation-notes-2026-06-29-through-2026-07-03.md` during the
2026-07-03 release-readiness housekeeping pass.

Use `PROJECT_TRACKER.md` for the current direction, next queue, parked work, and
latest checkpoint. Add new notes here only when a slice needs more durable
detail than the tracker should carry.

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
