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
- Latest pushed baseline: `c9bcb5e Record v0.4.0 release completion`.
- CI state: run `28686955598` for `c9bcb5e` succeeded. Earlier runs for
  `c0a01f5` (`28672899400`) and `64bceea` (`28680427556`) failed on
  calibration evidence runner environment assumptions, both since fixed.
- Release checklist issue: [#30](https://github.com/fuentesjr/metz-scan/issues/30),
  `Release v0.4.0`, is closed with the checklist complete.
- Release state: `v0.4.0` is tagged at `937afd8`, the GitHub Release is
  published, both GitHub Packages gems are published, and
  `bin/check_published_gem 0.4.0` passed.
- Local branch state: release tag, release target, and post-release completion
  checkpoint are pushed to `origin/main`; this package-monitor checkpoint is
  local until pushed.
- Latest checkpoint window: 15:58:47-16:02:27 -0700, 3m 40s elapsed.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Complete | `v0.4.0` is tagged, released on GitHub, published to GitHub Packages for both gems, verified with post-publish smoke, issue #30 is closed, and post-release CI for `c9bcb5e` is green. | Monitor package installation feedback; no `0.4.x` follow-up milestone is open without a concrete defect. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, and current notes are short. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Monitor published package installation feedback.
   - Why now: `bin/check_published_gem 0.4.0` passed immediately after publish,
     and the first post-push recheck also passed; external installs are now the
     next useful signal.
   - Definition of done: any reported package install issue is triaged against
     the release tag and package metadata.
   - Files likely touched: issue/bugfix docs or code only if a concrete defect
     appears.
   - Not in scope: speculative package changes without a failing install path.

2. Defer `0.4.x` follow-up planning until there is concrete work.
   - Why now: release readiness is complete, so future release work should be
     driven by package feedback or already-parked analyzer evidence.
   - Definition of done: no milestone is opened without a reproducible install
     issue, CI regression, or scoped follow-up requirement.
   - Files likely touched: GitHub issue/milestone, maybe `PROJECT_TRACKER.md`.
   - Not in scope: detector expansion without new evidence.

3. Keep analyzer behavior parked unless new evidence appears.
   - Why now: `0.4.0` shipped existing candidate analyzers and release
     hardening; it did not change the analyzer evidence boundary.
   - Definition of done: future work resumes from concrete evidence rather than
     the fact that the release shipped.
   - Files likely touched: none.
   - Not in scope: analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or target intake.

4. Reorient toward the next evidence-led workstream.
   - Why now: the release train is complete, and the project should avoid
     extending release work into speculative analyzer changes.
   - Definition of done: choose the next slice from package feedback, CI drift,
     or already-documented calibration evidence.
   - Files likely touched: `PROJECT_TRACKER.md`, issue tracker, or narrow code
     only after a concrete next slice is selected.
   - Not in scope: starting a new detector or milestone only because `0.4.0`
     shipped.

## Latest Slice Checkpoint

Slice: 2026-07-03 post-release push and package monitor.

Window: 15:58:47-16:02:27 -0700, 3m 40s elapsed.

1. Pushed the post-release completion checkpoint.
   - `bin/check_ci_parity` passed before push: 465 runs, 2026 assertions,
     0 failures, 0 errors, 6 skips; RuboCop inspected 196 files with no
     offenses; calibration smoke and guard scripts passed.
   - `c9bcb5e Record v0.4.0 release completion` was pushed to `origin/main`.
   - CI run `28686955598` passed for `c9bcb5e`.
2. Rechecked published package installation state.
   - GitHub Packages still reports `rubocop-metz 0.4.0` and `metz-scan 0.4.0`.
   - `bin/check_published_gem 0.4.0` passed again from a clean temporary
     consumer project.
3. Deferred a `0.4.x` follow-up milestone.
   - No open milestone exists.
   - Open issue search for `0.4.0`, `0.4.x`, install, or package returned only
     unrelated existing issues #25 and #26, so there is no concrete
     post-release defect to organize.
4. Kept analyzer behavior parked.
   - No analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or calibration targets changed in this slice.

Agenticons used: `planner: post-release queue`.

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
| 2026-07-03 | `c9bcb5e` | Recorded `v0.4.0` release completion, release links, package links, and closed issue #30. |
| 2026-07-03 | `937afd8` | Finalized `v0.4.0` release-note wording before tagging and publishing. |
| 2026-07-03 | `b026f7a` | Recorded the `v0.4.0` release authorization preflight and public-release boundary. |
| 2026-07-03 | `8de602f` | Recorded `v0.4.0` pre-publish package, CLI, output-format, and dry-run auto-fix smoke checks. |
| 2026-07-03 | `a42229f` | Recorded the `v0.4.0` release issue checkpoint after pushing release-prep commits and opening issue #30. |
| 2026-07-03 | `74be52f` | Pushed and verified the local `v0.4.0` release-prep checkpoint; remote CI passed and issue #30 was opened. |
| 2026-07-03 | `94fea40` | Prepared the `0.4.0` release target, version surfaces, release issue dry-run expectations, and draft release notes. |
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
- Published `v0.4.0` release notes: `docs/releases/v0.4.0.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
