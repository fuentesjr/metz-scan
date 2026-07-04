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
- Latest pushed baseline: `3d9c360 Record rubydex bump and README cleanup`.
- CI state: run `28693957868` for `3d9c360` succeeded in 1m 20s. Earlier runs
  for `c0a01f5` (`28672899400`) and `64bceea` (`28680427556`) failed on
  calibration evidence runner environment assumptions, both since fixed.
- Release checklist issue: [#30](https://github.com/fuentesjr/metz-scan/issues/30),
  `Release v0.4.0`, is closed with the checklist complete.
- Release state: `v0.4.0` is tagged at `937afd8`, the GitHub Release is
  published, both GitHub Packages gems are published, and
  `bin/check_published_gem 0.4.0` passed again after the latest upstream push.
- Local branch state: release tag, release target, release completion,
  package-monitor checkpoint, feedback-sweep checkpoint, Sorbet spike report,
  issue-sync tracker checkpoint, handoff checkpoint, continuation sweep,
  next-four evidence sweep, Dependabot PR #29, and README cleanup are pushed to
  `origin/main`; this latest parked-queue tracker checkpoint is local until
  pushed.
- Latest checkpoint window: 20:45:33-20:55:34 -0700, 10m 01s elapsed through
  upstream push verification, package/#25/#27/#28 checks, and tracker review.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Complete | `v0.4.0` is tagged, released on GitHub, published to GitHub Packages for both gems, verified with repeated post-publish smoke, issue #30 is closed, and post-release CI for `3d9c360` is green. | Monitor package installation feedback; no `0.4.x` follow-up milestone is open without a concrete defect. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Fresh #27/#28 Mastodon and Discourse reruns did not show enough misleading or underexplained findings to justify behavior, threshold, or output-policy changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated; latest focused rerun covered Mastodon and Discourse for DeepInheritanceTree and RepeatedBranching. | Do not add another target by default. |
| Sorbet adoption spike | Complete | Issue #26 was evaluated in a disposable workspace, documented, synced back to GitHub, and closed. The report recommends not adopting now: a narrow static setup is possible, but generated RBI churn, command policy, fixture scope, and runtime signature implications outweigh observed value. | Do not add Sorbet unless a concrete type-related defect, contributor ergonomics need, or stable public API typing requirement appears. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, current notes are short, and the Sorbet spike report records the tooling decision. The README RepeatedBranching generic-subject paragraph is split into a short list for readability. | Keep docs changes minimal and evidence-led. |
| Handoff continuity | Active | Local ignored handoff `.handoffs/20260703173813_next_four_tasks_after_issue_sync.md` captures the pushed issue-sync summary, conversation-only requirements, and the next four evidence-gated tasks. | Use it as the first continuation surface if context resets in this workspace; do not commit handoff files. |

## Next Queue

1. Continue package feedback watch without opening `0.4.x` work.
   - Why now: `bin/check_published_gem 0.4.0` passed immediately after publish,
     the first post-push recheck passed, the post-handoff recheck passed, and
     the post-upstream-push recheck passed; GitHub issues/release/package
     metadata show no release/package defect. PR #29 only bumped optional
     development dependency `rubydex` to `0.2.7`; post-merge CI and the
     subsequent README/tracker CI passed.
   - Definition of done: any reported package install issue is triaged against
     the release tag and package metadata.
   - Files likely touched: issue/bugfix docs or code only if a concrete defect
     appears.
   - Not in scope: speculative package changes without a failing install path.

2. Keep #25 dogfood CI enforcement deferred until its trigger appears.
   - Why now: #25 explicitly waits for collaboration expansion; current evidence
     still shows only owner plus bot activity. There are no open PRs, so there
     is still no need to add optional Rubydex setup and dogfood runtime to CI.
   - Definition of done: leave #25 open but inactive unless collaboration
     broadens or CI dogfood enforcement becomes necessary.
   - Files likely touched: none.
   - Not in scope: adding a dogfood CI gate just because the release shipped.

3. Keep #27 DeepInheritanceTree parked unless new misleading root-label
   evidence appears.
   - Why now: fresh Mastodon and Discourse reruns showed current root-kind
     labels and broad-base downranking are doing the intended work. Discourse
     produced 47 findings (34 low broad-base, 13 medium manual-review);
     Mastodon produced 40 findings (34 low broad-base, 6 medium manual-review).
   - Definition of done: future work resumes from concrete cross-project
     evidence showing labels are insufficient, not from output volume alone.
   - Files likely touched: none.
   - Not in scope: analyzer behavior, thresholds, statuses, suppressions,
     default-output policy, or target intake.

4. Keep #28 RepeatedBranching parked unless new generic-subject evidence
   requires reporting changes.
   - Why now: fresh Mastodon and Discourse reruns showed current metadata already
     separates generic, state, and expression subjects. Discourse produced
     5 findings (generic 1, state 3, expression 1); Mastodon produced
     14 findings (generic 9, state 1, expression 4).
   - Definition of done: keep the queue empty of implementation work until a
     package defect, collaboration trigger, or cross-project analyzer evidence
     appears.
   - Files likely touched: none.
   - Not in scope: starting speculative detector, CI, or tooling changes to keep
     the queue busy.

## Latest Slice Checkpoint

Slice: 2026-07-03 upstream push and parked queue recheck.

Window: 20:45:33-20:55:34 -0700, 10m 01s elapsed through upstream push
verification, package/#25/#27/#28 checks, and tracker review.

1. Pushed the local README/tracker checkpoint upstream first.
   - `bin/check_ci_parity` passed before push on `3d9c360`: 465 runs,
     2026 assertions, 0 failures, 0 errors, 6 skips; RuboCop inspected
     196 files with no offenses; calibration smoke, dependency-direction, and
     frozen-sample checks passed.
   - `git push` advanced `main` from `c8c5ca3` to `3d9c360`; GitHub reported
     direct-push branch-protection bypasses for PR-required and expected-status
     rules.
   - CI run `28693957868` passed for `3d9c360` in 1m 20s.
2. Checked for higher-priority work before repeating the parked queue.
   - No open PRs were present.
   - Open issues remained exactly #25, #27, and #28.
   - The latest five `main` CI runs were green, so no CI triage outranked the
     parked queue.
3. Completed task 1: package/release feedback watch.
   - `bin/check_published_gem 0.4.0` passed again against GitHub Packages,
     resolving both `metz-scan` and `rubocop-metz` at `0.4.0`.
   - Issue search for release/package/install/GitHub Packages/Rubydex terms
     found no concrete package defect.
   - No `0.4.x` milestone was opened.
4. Completed task 2: #25 dogfood CI trigger check.
   - #25 remains open and explicitly trigger-gated.
   - Contributor evidence remains `fuentesjr` plus Dependabot, with no open PRs
     and no sign of broader human collaboration.
   - Dogfood CI enforcement remains deferred.
5. Completed task 3: #27 DeepInheritanceTree evidence check.
   - Focused Mastodon and Discourse check stayed at 87 findings and 87 offenses.
   - Discourse `2115f1cac5f9` stayed at 47 findings: 34 low broad-base and
     13 medium manual-review.
   - Mastodon `34bbb4748223` stayed at 40 findings: 34 low broad-base and
     6 medium manual-review.
   - No current evidence justified behavior, grouping, threshold, or
     default-output changes.
6. Completed task 4: #28 RepeatedBranching evidence check.
   - Focused Mastodon and Discourse check stayed at 19 findings and 41 offenses.
   - Discourse `2115f1cac5f9` stayed at 5 findings: generic 1, state 3,
     expression 1.
   - Mastodon `34bbb4748223` stayed at 14 findings: generic 9, state 1,
     expression 4.
   - The #28 helper also ran a full active-fixture `--no-write` pass:
     53 findings, 127 offenses; generic 13, state 25, expression 15. The
     existing subject-kind metadata and triage still match the issue bar.
7. Kept the evidence-gated queue parked.
   - No production Ruby, analyzer behavior, CI workflow, Sorbet, package
     release, or GitHub issue state changes were made in this slice.
   - Open issues remain exactly #25, #27, and #28.
   - The ignored handoff file remains in place because this parked-queue
     tracker checkpoint is not pushed yet.

Agenticons used: `helper_worker: priority/package/#25 trigger sweep`,
`helper_worker: #27 DeepInheritanceTree evidence`, and
`helper_worker: #28 RepeatedBranching evidence`.

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
| 2026-07-03 | `this commit` | Recorded the pushed README/tracker verification and kept package/#25/#27/#28 parked. |
| 2026-07-03 | `3d9c360` | Recorded PR #29 merge verification and README RepeatedBranching readability cleanup. |
| 2026-07-03 | `c8c5ca3` | Merged Dependabot PR #29, bumping optional `rubydex` from 0.2.5 to 0.2.7. |
| 2026-07-03 | `4b46153` | Recorded the upstream push verification and next-four evidence-gated task sweep. |
| 2026-07-03 | `d1d6ebb` | Recorded the post-handoff continuation sweep and kept all implementation work evidence-gated. |
| 2026-07-03 | `114fce1` | Added the next-four-tasks handoff and recorded the pushed issue-sync verification. |
| 2026-07-03 | `543dfe2` | Recorded the pushed Sorbet spike verification, closed #26, and updated the issue queue evidence bars. |
| 2026-07-03 | `797ade8` | Recorded the issue #26 Sorbet adoption spike, recommended not adopting now, and updated the next queue accordingly. |
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
- Local ignored handoff, not committed:
  `.handoffs/20260703173813_next_four_tasks_after_issue_sync.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
