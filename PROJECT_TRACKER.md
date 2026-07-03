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
- Branch state: `main` is ahead of `origin/main` by four local commits.
- Latest local commit: `f444313 Add project tracker`.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Active | Local release smoke, checklist, issue-preview, and package metadata coverage have been hardened. | Push local commits and watch CI before more release work. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, and sample-app calibration smoke are covered. | Maintain; change only when artifact behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Needs light curation | README and calibration docs are broad; release workflow is now guarded by tests. | Improve discoverability only when it reduces future-agent rediscovery. |

## Next Queue

1. Push and verify the three local release-maintenance commits.
   - Why now: local validation is green, but CI and remote state have not seen
     the release-hardening commits.
   - Definition of done: branch is synced with `origin/main`, CI status is
     inspected, and any failure is triaged.
   - Files likely touched: none unless CI fails.
   - Not in scope: detector behavior, thresholds, promotions, or target intake.

2. Do a release-readiness checkpoint.
   - Why now: release checklist, package metadata smoke, and issue preview are
     now covered; the next decision is whether the repo is ready for release
     prep or needs one more hardening pass.
   - Definition of done: run/inspect the release checklist path far enough to
     identify concrete blockers, then record the decision.
   - Files likely touched: `implementation-notes.md`, possibly
     `RELEASE_CHECKLIST.md` if the checklist itself is wrong.
   - Not in scope: publishing gems unless explicitly requested.

3. Improve tracker/docs discoverability if future agents still rediscover
   state from scratch.
   - Why now: `PROJECT_TRACKER.md` is new; it may need a README pointer after
     one or two slices prove the shape.
   - Definition of done: add only the smallest useful cross-reference.
   - Files likely touched: `README.md`, `PROJECT_TRACKER.md`.
   - Not in scope: duplicating calibration evidence or implementation notes.

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
| 2026-07-03 | `fc97947` | Hardened release issue dry-run, release metadata, and gem file-list smoke coverage. |
| 2026-07-03 | `92770d0` | Added calibration artifact release smoke, checklist drift coverage, and CI calibration smoke. |
| 2026-07-03 | `8753614` | Decomposed project analyzer Markdown rendering and added exact-output fixture coverage. |
| 2026-07-02 | `1ff9424` | Recorded the generic classifier checkpoint pause decision. |
| 2026-07-02 | `1d7811f` | Consolidated expanded package, namespace, and subclass evidence quality. |

## Source Pointers

- Current project tracker: `PROJECT_TRACKER.md`.
- Chronological implementation details: `implementation-notes.md`.
- Project analyzer calibration record: `docs/project-analyzer-calibration.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
