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
  `Release v0.4.0`, is open.
- Local branch state: pushed release-prep commits are on `origin/main`; this
  tracker checkpoint is local until pushed.
- Latest checkpoint window: 13:33:16-13:36:23 -0700, 3m 07s elapsed.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Active | Next target is `0.4.0`; both gems and the lockfile report `0.4.0`; local and remote CI checks are green for `74be52f`; release checklist issue #30 is open. | Work issue #30's pre-publish verification checklist, starting with package metadata and smoke tests. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, and current notes are short. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Complete package metadata and gem build checks from issue #30.
   - Why now: the release checklist issue is open and remote CI is green, so
     the next release risk is package content rather than source correctness.
   - Definition of done: version commands, release metadata tests,
     create-release-issue tests, both gem builds, and gem file inspections pass;
     generated gem files are removed unless explicitly retained.
   - Files likely touched: none unless packaging checks expose a concrete issue.
   - Not in scope: publishing gems, creating tags, or creating a GitHub release.

2. Complete CLI and output-format smoke checks from issue #30.
   - Why now: CI covers core behavior, but the release checklist still needs
     user-facing command, fixture scan, and dry-run auto-fix evidence.
   - Definition of done: CLI help/rules/explain commands pass; sample fixture
     scans produce well-formed text, project-analyzer text, JSON, SARIF, and
     GitHub annotation output; dry-run auto-fix leaves fixtures unchanged.
   - Files likely touched: none unless smoke checks expose a concrete issue.
   - Not in scope: changing analyzer findings just because smoke fixtures emit
     expected warnings.

3. Prepare a release authorization checkpoint after pre-publish checks.
   - Why now: tag, GitHub release, and package publish steps are irreversible
     enough to require an explicit human decision after checklist evidence is
     collected.
   - Definition of done: issue #30 records completed pre-publish checks and the
     tracker clearly states whether the project is ready for tag/publish
     authorization or what blocker remains.
   - Files likely touched: `PROJECT_TRACKER.md`, possibly issue #30 comments.
   - Not in scope: tagging, publishing, or creating a GitHub release without
     explicit approval.

4. Keep analyzer behavior parked during release prep.
   - Why now: `0.4.0` is packaging already-landed candidate analyzer and
     reporting work; it is not a signal to expand or promote analyzers.
   - Definition of done: release work changes packaging, docs, checks, or issue
     tracking only.
   - Files likely touched: release/checklist docs only.
   - Not in scope: analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or target intake.

## Latest Slice Checkpoint

Slice: 2026-07-03 v0.4.0 push, CI, and checklist issue.

Window: 13:33:16-13:36:23 -0700, 3m 07s elapsed.

1. Pushed the local release-prep commits upstream.
   - `main` and `origin/main` now point at
     `74be52f Record v0.4.0 release verification`.
   - GitHub reported direct-push branch-protection bypass notices for PR-only
     changes and the expected required `test` status check.
2. Verified remote CI for the pushed head.
   - CI run `28682228548` passed for `74be52f`: tests, RuboCop, calibration
     artifact smoke, GitHub annotations smoke, dependency-direction guard, and
     sample-app freeze guard.
3. Opened the release checklist issue.
   - `bin/create_release_issue --dry-run` rendered `Release v0.4.0` with both
     gem versions at `0.4.0`.
   - `bin/create_release_issue` created
     [#30](https://github.com/fuentesjr/metz-scan/issues/30), `Release v0.4.0`.
4. Kept analyzer behavior parked.
   - No analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or calibration targets changed in this slice.

Agenticons used: `planner: release issue sequence`.

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
