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

`metz-scan` is currently optimizing for conservative release readiness,
calibration confidence, and evidence-led tooling decisions, not detector
expansion.

The project analyzer detector set has enough current evidence to stay
candidate-heavy and opt-in. Recent work has therefore moved to release smoke,
artifact-pipeline reliability, package/release metadata hardening, and bounded
tooling spikes that do not commit the project to new maintenance surfaces.

## Current Snapshot

- Date: 2026-07-03.
- Latest pushed baseline: `60a7386 Record post-release feedback sweep`.
- CI state: run `28688031787` for `60a7386` succeeded. Earlier runs for
  `c0a01f5` (`28672899400`) and `64bceea` (`28680427556`) failed on
  calibration evidence runner environment assumptions, both since fixed.
- Release checklist issue: [#30](https://github.com/fuentesjr/metz-scan/issues/30),
  `Release v0.4.0`, is closed with the checklist complete.
- Release state: `v0.4.0` is tagged at `937afd8`, the GitHub Release is
  published, both GitHub Packages gems are published, and
  `bin/check_published_gem 0.4.0` passed.
- Local branch state: release tag, release target, release completion,
  package-monitor checkpoint, and feedback-sweep checkpoint are pushed to
  `origin/main`; this Sorbet spike report checkpoint is local until pushed.
- Latest checkpoint window: 16:37:04-17:10:42 -0700, 33m 38s elapsed.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Complete | `v0.4.0` is tagged, released on GitHub, published to GitHub Packages for both gems, verified with repeated post-publish smoke, issue #30 is closed, and post-release CI for `60a7386` is green. | Monitor package installation feedback; no `0.4.x` follow-up milestone is open without a concrete defect. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Generic classifier checkpoint concluded current evidence is too mixed for behavior changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated. | Do not add another target by default. |
| Sorbet adoption spike | Complete | Issue #26 was evaluated in a disposable workspace. The report recommends not adopting now: a narrow static setup is possible, but generated RBI churn, command policy, fixture scope, and runtime signature implications outweigh observed value. | Do not add Sorbet unless a concrete type-related defect, contributor ergonomics need, or stable public API typing requirement appears. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, current notes are short, and the Sorbet spike report records the tooling decision. | Keep docs changes minimal and evidence-led. |

## Next Queue

1. Continue package feedback watch without opening `0.4.x` work.
   - Why now: `bin/check_published_gem 0.4.0` passed immediately after publish,
     the first post-push recheck passed, and this feedback sweep found no
     release/package defect.
   - Definition of done: any reported package install issue is triaged against
     the release tag and package metadata.
   - Files likely touched: issue/bugfix docs or code only if a concrete defect
     appears.
   - Not in scope: speculative package changes without a failing install path.

2. Optionally sync the Sorbet spike decision back to issue #26.
   - Why now: the local report completes the investigation acceptance criteria,
     but the GitHub issue is still the public coordination surface.
   - Definition of done: comment on #26 with the report link and recommendation,
     then close or explicitly leave it open for future revisit.
   - Files likely touched: none unless the report needs wording cleanup.
   - Not in scope: adding Sorbet dependencies, RBIs, runtime signatures, or CI
     typecheck gates.

3. Keep #25 dogfood CI enforcement deferred until its trigger appears.
   - Why now: #25 explicitly waits for collaboration expansion; current evidence
     still shows no need to add optional Rubydex setup and dogfood runtime to CI.
   - Definition of done: leave #25 open but inactive unless collaboration
     broadens or CI dogfood enforcement becomes necessary.
   - Files likely touched: none.
   - Not in scope: adding a dogfood CI gate just because the release shipped.

4. Keep analyzer issues #27/#28 and analyzer behavior parked unless new
   evidence appears.
   - Why now: `0.4.0` shipped existing candidate analyzers and release
     hardening; it did not change the DeepInheritanceTree or RepeatedBranching
     evidence boundary.
   - Definition of done: future work resumes from concrete evidence rather than
     the fact that the release shipped.
   - Files likely touched: none.
   - Not in scope: analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or target intake.

## Latest Slice Checkpoint

Slice: 2026-07-03 push verification and Sorbet adoption spike.

Window: 16:37:04-17:10:42 -0700, 33m 38s elapsed.

1. Pushed and verified the feedback-sweep checkpoint.
   - `bin/check_ci_parity` passed before push: 465 runs, 2026 assertions,
     0 failures, 0 errors, 6 skips; RuboCop inspected 196 files with no
     offenses; calibration smoke and guard scripts passed.
   - `60a7386 Record post-release feedback sweep` was pushed to
     `origin/main`.
   - CI run `28688031787` passed for `60a7386`.
2. Rechecked package and baseline state before the spike.
   - GitHub Packages still reports `rubocop-metz 0.4.0` and `metz-scan 0.4.0`.
   - `bin/check_published_gem 0.4.0` passed again from a clean temporary
     consumer project.
   - `bin/check_dogfood` passed with the accepted project-analyzer baseline:
     0 findings.
   - Baseline inventory recorded Ruby 4.0.1, Bundler 4.0.8, 108 production Ruby
     files under `lib/` and `rubocop-metz/lib/`, and no existing Sorbet/Tapioca
     dependencies.
3. Completed the bounded Sorbet spike from issue #26.
   - Disposable workspace: `/private/tmp/metz-scan-sorbet-spike-20260703-1643`.
   - `sorbet 0.6.13323` and `tapioca 0.19.2` installed only in the disposable
     bundle.
   - `tapioca init` generated 34 RBI files and 165,751 RBI lines, including 31
     gem RBIs, 2 annotation RBIs, and a 25-line `todo.rbi` mostly for fixture
     constants.
   - Product-code-only `srb tc` passed only after using a writable temp HOME,
     `SRB_SKIP_GEM_RBIS=1`, and ignoring test fixtures/tests.
   - Five product-layer candidates were evaluated at `# typed: true`; three
     passed cleanly (`Occurrence`, `RubyFileEnumerator`, `SarifSeverity`) and
     two exposed adoption friction (`ProjectAnalyzerTriage`,
     `OffenseExtractor`).
4. Recorded the decision and kept analyzer behavior parked.
   - Added `docs/spikes/sorbet-issue-26.md` with the detailed evidence and
     recommendation: do not adopt Sorbet now.
   - No Sorbet dependencies, RBIs, runtime signatures, CI gates, or production
     code changes were added to the repo.
   - No analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or calibration targets changed in this slice.
   - #27 and #28 remain useful but inactive until new generic evidence justifies
     DeepInheritanceTree or RepeatedBranching work.

Agenticons used: `planner: Sorbet spike plan`.

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
| 2026-07-03 | `this commit` | Recorded the issue #26 Sorbet adoption spike, recommended not adopting now, and updated the next queue accordingly. |
| 2026-07-03 | `60a7386` | Recorded the post-release feedback sweep and kept #26 as the next bounded non-release work item before this spike. |
| 2026-07-03 | `64fa605` | Recorded the post-release package monitor checkpoint and deferred a `0.4.x` milestone without a concrete defect. |
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
- Sorbet adoption spike: `docs/spikes/sorbet-issue-26.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
