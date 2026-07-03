# Project Tracker

This is the short, curated project-state file. Keep detailed chronological notes
in `implementation-notes.md`; keep local scratch strategy under `logs/`.

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
- Latest pushed baseline: `27c79a3 Add CI-parity guard script`.
- CI state: run `28680784978` for `27c79a3` succeeded — first green run since
  2026-06-30 (`c6cd0ce`). Runs for `c0a01f5` (`28672899400`) and `64bceea`
  (`28680427556`) failed on calibration evidence runner environment
  assumptions, both since fixed.
- Local branch state: `main` is synced with `origin/main` apart from this
  tracker update.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Active | CI is green on `27c79a3` (run `28680784978`); gemspec contact email is real; `bin/check_ci_parity` guards the local/CI environment gap. | Make the release-prep decision (open/update a release tracking issue or defer with a named blocker). |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, and sample-app calibration smoke are covered. | Maintain; change only when artifact behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Stable | README now points contributors and agents to this tracker; release workflow is guarded by tests and checklist smoke. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Make the release-prep decision.
   - Why now: CI is green on `27c79a3` and the full local non-publishing
     verification passed, including full tests, RuboCop, guards, calibration
     smoke, CI-parity check, release metadata smokes, and release issue
     dry-run.
   - Definition of done: decide whether to open/update a release tracking
     issue or defer release prep for a named blocker.
   - Files likely touched: `PROJECT_TRACKER.md`, possibly GitHub issue text.
   - Not in scope: publishing gems unless explicitly requested.

2. Repo housekeeping recommended by the 2026-07-03 external review, deferred
   by owner decision that day.
   - Scope when picked up: archive the bulk of `implementation-notes.md` and
     keep only recent slices; move the tracked
     `tmp/project-analyzer-calibration/project_analyzer_targets.yml` out of
     the gitignored `tmp/` tree; remove the stale local `metz-scan-0.2.0.gem`.
   - Definition of done: each item lands as its own small commit with tests
     and guards still green.
   - Not in scope: any analyzer or release behavior change.

## Latest Slice Checkpoint

Slice: 2026-07-03 external advisor review and CI-recovery follow-through.

1. External review confirmed the direction (conservative release readiness,
   no detector expansion) and flagged three problems: CI red since 2026-06-30
   with the fix sitting unpushed, both gemspecs shipping a placeholder
   contact email despite the metadata-hardening workstream, and no local
   check that reproduces the CI environment.
2. Pushed the stalled head (`a8428e9` + `64bceea`); its CI run `28680427556`
   still failed — `a8428e9` fixed only one of the two environment
   assumptions. The sample-app smoke also asserted positive findings, which
   requires the optional rubydex index backend CI never installs.
3. `35e33e6` made that smoke index-backend-aware: positive findings with a
   real backend, exactly zero with the null backend, real path exercised in
   both.
4. `5b285c4` set the real gemspec contact email in both gems and pinned it in
   `release_metadata_test.rb` so placeholders cannot return.
5. `27c79a3` added `bin/check_ci_parity` (clean clone of HEAD, no local
   bundler config, runs the single-command CI steps), documented it in both
   release checklists, and added drift tests tying the script to
   `.github/workflows/ci.yml`. The script reproduced the CI failure locally
   before the fix and passed after it.
6. CI run `28680784978` for `27c79a3` succeeded — first green since
   `c6cd0ce` (2026-06-30). Standing rules added above: no new slice on red
   CI, and run the parity check before pushing.

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
- Chronological implementation details: `implementation-notes.md`.
- Project analyzer calibration record: `docs/project-analyzer-calibration.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
