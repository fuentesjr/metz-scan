# Project Tracker

This is the short, curated project-state file. Keep recent implementation notes
in `implementation-notes.md`, archived chronological notes under
`docs/archive/`, and local scratch strategy under `logs/`.

This file is the primary local coordination surface instead of GitHub Projects
or individual issues because recent work has been a fast-moving sequence of
agent-driven calibration and release-hardening slices. A tracked repo file gives
every future agent immediate offline context, updates atomically with the code
commit that changed direction, and preserves the "why now / not next" boundary
next to the source. Use GitHub issues and projects for external/public
coordination, releases, and user-facing work; use this tracker to orient local
agents before deciding whether GitHub work should be opened or updated.

Update this file at the end of each committed slice when the current direction,
next queue, parked work, or recent-completion table changes.

Standing rules:

- Do not start a new slice while `origin/main` CI is red; triage and fix the
  failure first so red runs cannot accumulate behind local work.
- Run `bin/check_ci_parity` before pushing. It reruns the single-command CI
  steps against the committed HEAD in a clean clone, so local-only environment
  assumptions (bundler config such as the optional rubydex group, untracked
  files) fail locally instead of in CI.

## Current Direction

`metz-scan` is currently optimizing for conservative release readiness and
calibration confidence, not detector expansion.

The project analyzer detector set has enough current evidence to stay
candidate-heavy and opt-in. Recent work has therefore moved to release smoke,
artifact-pipeline reliability, and package/release metadata hardening.

## Current Snapshot

- Date: 2026-07-03.
- Latest pushed baseline: `2759102 Record CI recovery and parity guard checkpoint`.
- CI state: run `28680896907` for `2759102` succeeded. Earlier runs for
  `c0a01f5` (`28672899400`) and `64bceea` (`28680427556`) failed on
  calibration evidence runner environment assumptions, both since fixed.
- Local branch state: `main` has local release-readiness housekeeping and
  `v0.4.0` release-target prep commits ahead of `origin/main`.
- Latest checkpoint window: 13:15:51-13:23:44 -0700, 7m 53s elapsed.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Active | Next target is `0.4.0`; both gems and the lockfile report `0.4.0`; release issue dry-run now renders `Release v0.4.0`; draft release notes live under `docs/releases/`. | Run final release checks, push, watch CI, then open/update the release checklist issue. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, and current notes are short. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Run final release checks for the local `0.4.0` prep head.
   - Why now: version constants, lockfile, README install guidance, release
     issue dry-run expectations, and draft release notes now point at `0.4.0`.
   - Definition of done: full suite, RuboCop, guard scripts, release metadata
     tests, release issue dry-run, and CI-parity check pass on committed HEAD.
   - Files likely touched: none unless a check exposes a concrete issue.
   - Not in scope: publishing gems unless explicitly requested.

2. Push and verify CI for `0.4.0` release prep.
   - Why now: release prep should not proceed to a checklist issue until the
     remote branch has seen the version bump and release notes.
   - Definition of done: branch is synced with `origin/main`, the latest CI run
     is green, and any failure is triaged before more release work.
   - Files likely touched: none unless parity exposes a bug.
   - Not in scope: publishing gems or creating a GitHub release.

3. Open or update the `Release v0.4.0` checklist issue after CI is green.
   - Why now: `bin/create_release_issue --dry-run` now renders the correct
     `0.4.0` versions and the release notes have a draft source.
   - Definition of done: GitHub issue exists with the checklist for `v0.4.0`
     or the tracker records the exact blocker.
   - Files likely touched: GitHub issue text, possibly `PROJECT_TRACKER.md`.
   - Not in scope: publishing gems unless explicitly requested.

4. Keep analyzer behavior parked during release prep.
   - Why now: `0.4.0` is packaging already-landed candidate analyzer and
     reporting work; it is not a signal to expand or promote analyzers.
   - Definition of done: release work changes packaging, docs, checks, or issue
     tracking only.
   - Files likely touched: release/checklist docs only.
   - Not in scope: analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or target intake.

## Latest Slice Checkpoint

Slice: 2026-07-03 v0.4.0 release target prep.

Window: 13:15:51-13:23:44 -0700, 7m 53s elapsed.

1. Chose `0.4.0` as the next release target.
   - `v0.3.0..HEAD` includes new opt-in candidate analyzers plus calibration
     and reporting infrastructure, so the next release is a minor release
     rather than a patch-only maintenance release.
2. Bumped release version surfaces.
   - `MetzScan::VERSION`, `RuboCop::Metz::VERSION`, `Gemfile.lock`, README
     install guidance, and release issue dry-run tests now target `0.4.0`.
3. Drafted release notes.
   - `docs/releases/v0.4.0.md` summarizes analyzer, calibration/reporting, and
     release-hardening highlights for the upcoming checklist.
4. Verified the focused release path.
   - Release metadata tests and create-release-issue tests pass; both version
     constants print `0.4.0`; `bin/create_release_issue --dry-run` renders
     `Release v0.4.0`.

Agenticons used: `planner: release target plan`,
`helper_worker: release target evidence`, and
`reviewer: strategic design review`.

## Parked / Not Next

- Do not promote candidate analyzers to default output.
- Do not change analyzer thresholds from the current evidence.
- Do not add app-specific suppressions.
- Do not add another calibration target by default.
- Do not expand `RepeatedQueryCriteria` query forms.
- Do not implement generic classifier behavior until a design-only proposal
  proves generic, non-app-specific facts can separate useful design pressure
  from public extension surfaces.

## Recently Completed

| Date | Commit | Summary |
| --- | --- | --- |
| 2026-07-03 | `c2e2c00` | Archived implementation notes, moved the tracked calibration manifest out of ignored `tmp/`, and removed stale local gem artifacts. |
| 2026-07-03 | `2759102` | Recorded CI recovery and parity guard checkpoint. |
| 2026-07-03 | `27c79a3` | Added the `bin/check_ci_parity` guard, checklist steps, and CI drift tests; first green CI run since 2026-06-30. |
| 2026-07-03 | `35e33e6` | Made the sample-app calibration smoke assert exact behavior per index backend, fixing the last CI environment assumption. |
| 2026-07-03 | `5b285c4` | Replaced the placeholder gemspec contact email in both gems and pinned it in the release metadata tests. |
| 2026-07-03 | `64bceea` | Recorded the prior release-readiness checkpoint in this tracker and README. |
| 2026-07-03 | `a8428e9` | Fixed CI-only calibration evidence runner assumptions for missing default fixtures and optional project index backends. |
| 2026-07-03 | `c0a01f5` | Explained why this tracker is the local coordination surface instead of only GitHub Projects/issues. |
| 2026-07-03 | `f444313` | Added the project tracker and current release-readiness queue. |
| 2026-07-03 | `fc97947` | Hardened release issue dry-run, release metadata, and gem file-list smoke coverage. |
| 2026-07-03 | `92770d0` | Added calibration artifact release smoke, checklist drift coverage, and CI calibration smoke. |
| 2026-07-03 | `8753614` | Decomposed project analyzer Markdown rendering and added exact-output fixture coverage. |

## Source Pointers

- Current project tracker: `PROJECT_TRACKER.md`.
- Recent implementation notes: `implementation-notes.md`.
- Archived chronological implementation details:
  `docs/archive/implementation-notes-2026-06-29-through-2026-07-03.md`.
- Project analyzer calibration record: `docs/project-analyzer-calibration.md`.
- Tracked calibration target manifest: `docs/calibration/project_analyzer_targets.yml`.
- Draft `v0.4.0` release notes: `docs/releases/v0.4.0.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
