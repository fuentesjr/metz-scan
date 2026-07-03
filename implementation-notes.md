# Implementation Notes

This file keeps recent implementation context only. Older chronological notes
were archived to
`docs/archive/implementation-notes-2026-06-29-through-2026-07-03.md` during the
2026-07-03 release-readiness housekeeping pass.

Use `PROJECT_TRACKER.md` for the current direction, next queue, parked work, and
latest checkpoint. Add new notes here only when a slice needs more durable
detail than the tracker should carry.

## 2026-07-03: Release-readiness housekeeping

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
