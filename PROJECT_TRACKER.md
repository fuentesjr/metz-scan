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
- Local branch state: `main` has this release-readiness housekeeping checkpoint
  pending commit.
- Latest checkpoint window: 13:06:05-13:10:44 -0700, 4m 39s elapsed.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Active | CI is green on `2759102` (run `28680896907`); `v0.3.0` already exists while both gem versions still report `0.3.0`, so a new release issue is deferred until the next version target is chosen. | Choose the next version/scope before opening a release checklist issue. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, and current notes are short. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Choose the next release target.
   - Why now: `v0.3.0` is already published, both gems still report `0.3.0`,
     and `bin/create_release_issue --dry-run` would currently generate a
     duplicate `Release v0.3.0` checklist.
   - Definition of done: decide whether the next release is a patch release,
     a `0.4.0` analyzer/reporting release, or explicitly deferred.
   - Files likely touched: `PROJECT_TRACKER.md`; possibly version constants
     and release issue text if a release is chosen.
   - Not in scope: publishing gems unless explicitly requested.

2. Run `bin/check_ci_parity` before the next push.
   - Why now: this slice changed tracked docs and calibration manifest
     location; the standing rule requires the clean-clone CI check before
     pushing.
   - Definition of done: parity check passes against committed HEAD.
   - Files likely touched: none unless parity exposes a bug.
   - Not in scope: broad release checklist churn.

3. Keep housekeeping closed unless new evidence appears.
   - Why now: the archived implementation notes, moved target manifest, and
     stale ignored gem cleanup are complete.
   - Definition of done: future slices do not reopen these items without a
     concrete broken reference or generated artifact.
   - Files likely touched: none.
   - Not in scope: analyzer behavior or target intake.

## Latest Slice Checkpoint

Slice: 2026-07-03 release-readiness housekeeping.

Window: 13:06:05-13:10:44 -0700, 4m 39s elapsed.

1. Release-prep decision recorded.
   - Latest `origin/main` is `2759102` with green CI run `28680896907`.
   - No release issue was opened because `v0.3.0` already exists and both gems
     still report `0.3.0`; the next release needs an explicit version/scope
     decision first.
2. `implementation-notes.md` bulk archived.
   - Historical notes moved to
     `docs/archive/implementation-notes-2026-06-29-through-2026-07-03.md`.
   - Current `implementation-notes.md` is now a short recent-context stub.
3. Tracked calibration target manifest moved out of ignored `tmp/`.
   - Manifest moved to `docs/calibration/project_analyzer_targets.yml`.
   - Live docs now point to the new path; historical archive paths are left as
     historical notes.
4. Stale ignored gem artifacts removed.
   - Removed local `metz-scan-0.2.0.gem` and
     `rubocop-metz/rubocop-metz-0.2.0.gem`.

Agenticons used: `planner: next four task plan` and
`helper_worker: release/housekeeping evidence`.

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
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
