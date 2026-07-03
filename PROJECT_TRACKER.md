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
- Latest pushed baseline: `74be52f Record v0.4.0 release verification`.
- CI state: run `28682228548` for `74be52f` succeeded. Earlier runs for
  `c0a01f5` (`28672899400`) and `64bceea` (`28680427556`) failed on
  calibration evidence runner environment assumptions, both since fixed.
- Release checklist issue: [#30](https://github.com/fuentesjr/metz-scan/issues/30),
  `Release v0.4.0`, is open. Verification, package metadata, and smoke-test
  sections are checked; tag, GitHub release, publish, post-publish smoke, and
  final cleanup sections remain unchecked.
- Local branch state: pushed release-prep commits are on `origin/main`; local
  tracker/checklist checkpoint commits are ahead until pushed.
- Latest checkpoint window: 13:42:28-14:53:50 -0700, 1h 11m 22s wall-clock
  elapsed, including the interrupted approval pause.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Active | Next target is `0.4.0`; both gems and the lockfile report `0.4.0`; local and remote CI checks are green for `74be52f`; issue #30's verification, package metadata, and smoke-test sections are checked. | Pause at the explicit release authorization gate before tagging, creating a GitHub release, or publishing packages. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, and current notes are short. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Decide whether to authorize the `v0.4.0` source tag and GitHub Release.
   - Why now: pre-publish release checks are green and recorded in issue #30,
     so the next release step leaves ordinary verification and enters a public
     release action.
   - Definition of done: user explicitly approves or declines tag/release work,
     and the tracker records the decision or blocker.
   - Files likely touched: `PROJECT_TRACKER.md`, issue #30.
   - Not in scope: creating a tag or GitHub Release before approval.

2. If authorized, perform the source tag and GitHub Release steps.
   - Why now: issue #30's next unchecked section is Source Tag and GitHub
     Release.
   - Definition of done: fetch tags, confirm `v0.4.0` does not already exist,
     create and push the annotated tag, create the GitHub Release from
     `docs/releases/v0.4.0.md`, and record links in issue #30 and the tracker.
   - Files likely touched: `PROJECT_TRACKER.md`, issue #30; no source files
     unless release notes expose a concrete blocker.
   - Not in scope: publishing gems unless separately authorized.

3. If authorized, publish `rubocop-metz` and then `metz-scan`.
   - Why now: package publish is the next unchecked release section after tag
     and GitHub Release.
   - Definition of done: GitHub Packages auth is confirmed, `rubocop-metz`
     publishes before `metz-scan`, both package URLs resolve, and issue #30 is
     updated.
   - Files likely touched: issue #30, `PROJECT_TRACKER.md`, generated gem
     artifacts that must be cleaned up.
   - Not in scope: publishing without explicit approval.

4. Run post-publish smoke and final cleanup, while keeping analyzer behavior
   parked.
   - Why now: `0.4.0` is packaging already-landed candidate analyzer and
     reporting work, not a signal to expand or promote analyzers.
   - Definition of done: `bin/check_published_gem 0.4.0` passes, generated gem
     files are removed, issue #30 is complete or records the exact blocker, and
     no analyzer behavior changed.
   - Files likely touched: issue #30, `PROJECT_TRACKER.md`, generated gem
     artifacts that must be cleaned up.
   - Not in scope: analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or target intake.

## Latest Slice Checkpoint

Slice: 2026-07-03 v0.4.0 pre-publish package and smoke checks.

Window: 13:42:28-14:53:50 -0700, 1h 11m 22s wall-clock elapsed, including
the interrupted approval pause.

1. Completed package metadata and gem build checks from issue #30.
   - Both version commands printed `0.4.0`.
   - Release metadata tests passed: 4 runs, 16 assertions, 0 failures,
     0 errors.
   - Create-release-issue tests passed: 2 runs, 18 assertions, 0 failures,
     0 errors.
   - `gem build metz-scan.gemspec` and `gem build rubocop-metz.gemspec`
     produced `0.4.0` gems without warnings; both gem file lists were
     inspected.
2. Completed CLI and output-format smoke checks from issue #30.
   - `bundle exec metz-scan --help`, `rules`, `project-analyzers`, and
     `explain Metz/DemeterTrainWreck` passed.
   - Fixture scan smoke produced expected findings and exit `1` for text,
     project-analyzer text, JSON, SARIF, and GitHub annotations; JSON parsed as
     `metadata`/`files`/`summary`, SARIF parsed as version `2.1.0`, and
     GitHub annotations emitted 4 warning lines.
   - Dry-run auto-fix exited `1` for remaining findings with RuboCop cache
     redirected to temp storage, and `diff -qr` proved the copied fixture was
     unchanged.
3. Prepared the release authorization checkpoint.
   - Issue #30 has the Verification, Package Metadata, and Smoke Tests sections
     checked.
   - Source tag, GitHub Release, publish, post-publish smoke, and final cleanup
     remain unchecked and require explicit approval before proceeding.
   - Generated gem files were removed after inspection.
4. Kept analyzer behavior parked.
   - No analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or calibration targets changed in this slice.

Agenticons used: `helper_worker: release checklist sanity pass`.

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
- Draft `v0.4.0` release notes: `docs/releases/v0.4.0.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
