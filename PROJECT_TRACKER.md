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

## Current Direction

`metz-scan` is currently optimizing for conservative release readiness and
calibration confidence, not detector expansion.

The project analyzer detector set has enough current evidence to stay
candidate-heavy and opt-in. Recent work has therefore moved to release smoke,
artifact-pipeline reliability, and package/release metadata hardening.

## Current Snapshot

- Date: 2026-07-03.
- Latest pushed baseline: `c0a01f5 Explain project tracker role`.
- Local branch state: `main` has the unpushed CI fix
  `a8428e9 Fix calibration evidence runner CI assumptions` plus this
  tracker/docs update.
- Latest checkpoint window: 09:35:35-12:24:31 -0700, 2h 48m 56s elapsed.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Active | The pushed `c0a01f5` CI run failed in the calibration evidence runner; local fix `a8428e9` passes the full local release-readiness checkpoint. | Push the local commits and verify CI for the fixed head. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, and sample-app calibration smoke are covered. | Maintain; change only when artifact behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Stable | README now points contributors and agents to this tracker; release workflow is guarded by tests and checklist smoke. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Push and verify the local release-readiness head.
   - Why now: `origin/main` is still at `c0a01f5`, whose CI run failed; the
     local head will include the CI fix plus this tracker/docs checkpoint.
   - Definition of done: branch is synced with `origin/main`, CI status is
     inspected, and any failure is triaged.
   - Files likely touched: none unless CI fails.
   - Not in scope: detector behavior, thresholds, promotions, or target intake.

2. Record the fixed-CI outcome.
   - Why now: release-prep decisions should wait until GitHub Actions has run
     on the fixed head.
   - Definition of done: update this tracker with the fixed-head run id,
     conclusion, and any remaining blocker.
   - Files likely touched: `PROJECT_TRACKER.md`.
   - Not in scope: release prep or publishing.

3. Make the release-prep decision only after fixed CI is green.
   - Why now: local non-publishing verification is green, including full tests,
     RuboCop, guards, calibration smoke, release issue dry-run, version checks,
     release metadata smokes, CLI/format smokes, gem build/spec inspection in
     temp storage, and dry-run auto-fix smoke.
   - Definition of done: if CI is green, decide whether to open/update a
     release tracking issue or defer release prep for a named blocker.
   - Files likely touched: `PROJECT_TRACKER.md`, possibly GitHub issue text.
   - Not in scope: publishing gems unless explicitly requested.

4. Re-run only failed or time-sensitive release checks after push.
   - Why now: the full local checkpoint already passed, so repeated local work
     should be driven by CI results or a materially changed branch.
   - Definition of done: document any new failure with exact command, run id, or
     log excerpt before changing code.
   - Files likely touched: only files implicated by evidence.
   - Not in scope: broad release checklist churn.

## Latest Six-Task Checkpoint

Window: 2026-07-03 09:35:35-12:24:31 -0700, 2h 48m 56s elapsed.

1. Confirmed the post-push baseline.
   - `main` was clean and synced with `origin/main` at `c0a01f5` when the slice
     started; no pre-existing tracked work needed a commit.
2. Verified upstream CI state.
   - GitHub Actions run `28672899400` for `c0a01f5` failed in `bundle exec rake`
     with two calibration evidence runner test failures.
3. Fixed the CI blocker.
   - `a8428e9` validates analyzer filters before default target presence checks
     and stops assuming optional `rubydex` is installed when asserting the
     active project index backend.
4. Ran the non-publishing release-readiness checkpoint.
   - Passed: `bundle exec rake`, `bundle exec rubocop`,
     `bin/check_dependency_direction`, `bin/check_sample_app_frozen`,
     calibration smoke, release metadata tests, release issue dry-run, version
     checks, CLI help/rules/project-analyzers/explain smoke, format scan smoke,
     gem build/spec inspection in temp storage, and dry-run auto-fix smoke with
     a sandbox-local RuboCop cache.
5. Used agenticons for planning, evidence gathering, and review.
   - `planner: next six-task release-readiness plan` and
     `helper_worker: release-readiness evidence` both kept the slice on
     release readiness; `reviewer: strategic design review` returned a clean
     verdict for the Ruby fix.
6. Updated local coordination docs.
   - README points future contributors and agents to this tracker; this tracker
     records the elapsed time, evidence, local branch state, and next queue.

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
