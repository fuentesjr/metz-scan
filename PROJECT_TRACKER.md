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
- Do not commit tracker-only updates unless they accompany real project work.
  If the tracker is stale, rewrite it before proceeding, but commit that
  rewrite with the implementation, test, documentation, or tooling change that
  made the update necessary.
- Do not keep rechecking parked/watch-only items just because they are listed
  near the top of the tracker. Move them to trigger-gated parked work and pick
  the next actionable improvement.

## Current Direction

`metz-scan` is currently optimizing for developer workflow reliability,
calibration confidence, and evidence-led tooling decisions, not detector
expansion or repeated tracker-only sweeps.

The project analyzer detector set has enough current evidence to stay
candidate-heavy and opt-in. The next useful work is to remove recurring
workflow friction, make calibration commands safer and easier to interpret, and
add focused tests around behavior that has already been learned through
calibration.

## Current Snapshot

- Date: 2026-07-04.
- Latest pushed baseline: `e954cee Record parked queue follow-up`.
- CI state: run `28722722473` for `e954cee` succeeded in 1m 27s after the
  upstream push. The previous pushed baseline `f9f5a10` succeeded in run
  `28721866073` in 1m 28s. Earlier runs for `c0a01f5` (`28672899400`) and
  `64bceea` (`28680427556`) failed on calibration evidence runner environment
  assumptions, both since fixed.
- Release checklist issue: [#30](https://github.com/fuentesjr/metz-scan/issues/30),
  `Release v0.4.0`, is closed with the checklist complete.
- Release state: `v0.4.0` is tagged at `937afd8`, the GitHub Release is
  published, both GitHub Packages gems are published, and
  `bin/check_published_gem 0.4.0` passed again during the 2026-07-04
  parked-queue follow-up sweep.
- Local branch state: release tag, release target, release completion,
  package-monitor checkpoint, feedback-sweep checkpoint, Sorbet spike report,
  issue-sync tracker checkpoint, handoff checkpoint, continuation sweep,
  next-four evidence sweep, Dependabot PR #29, README cleanup, the parked-queue
  tracker checkpoint, README analyzer-details cleanup, and Rubydex spike
  results, the Rubydex 0.2.7 calibration drift checkpoint, and the Rubydex
  release-response playbook, release-playbook follow-up tracker checkpoint
  (`1ae96ea`), queued-task follow-up tracker checkpoint (`b2513a8`), and
  parked-queue follow-up tracker checkpoint (`e954cee`) are pushed to
  `origin/main`.
- Latest checkpoint window: 16:04:26-16:08:05 -0700, 3m 39s elapsed through
  package/#25/#27/#28 checks, agenticon evidence collection, incidental lockfile
  restoration, and tracker review.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Complete | `v0.4.0` is tagged, released on GitHub, published to GitHub Packages for both gems, verified with repeated post-publish smoke, issue #30 is closed, and post-release CI for `f9f5a10` is green. | Monitor package installation feedback; no `0.4.x` follow-up milestone is open without a concrete defect. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Fresh #27/#28 Mastodon and Discourse reruns did not show enough misleading or underexplained findings to justify behavior, threshold, or output-policy changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Watching | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated; Rubydex `0.2.7` was rechecked against the active manifest. Full active-manifest output is 697 findings/806 offenses; the four Rubydex-index-backed analyzers account for 607 findings/607 offenses. | Recheck only Rubydex-index-backed analyzers after future Rubydex upgrades unless an AST-only analyzer changes. |
| Workflow friction | Active | Targeted calibration commands repeatedly rewrite the local path dependency in `Gemfile.lock` from `rubocop-metz (= 0.4.0)` to `rubocop-metz (~> 0.4.0)`, even when invoked with `--no-write`. | Fix the mutation path and add a regression guard before doing more calibration-heavy work. |
| Sorbet adoption spike | Complete | Issue #26 was evaluated in a disposable workspace, documented, synced back to GitHub, and closed. The report recommends not adopting now: a narrow static setup is possible, but generated RBI churn, command policy, fixture scope, and runtime signature implications outweigh observed value. | Do not add Sorbet unless a concrete type-related defect, contributor ergonomics need, or stable public API typing requirement appears. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, current notes are short, and the Sorbet spike report records the tooling decision. The README now splits RepeatedBranching generic-subject guidance into a short list, the analyzer behavior details into per-analyzer subsections, and the Rubydex spike/calibration docs reflect Rubydex `0.2.7` evidence plus the release-response playbook. | Keep docs changes minimal and evidence-led. |
| Handoff continuity | Active | Local ignored handoff `.handoffs/20260703173813_next_four_tasks_after_issue_sync.md` captures the pushed issue-sync summary, conversation-only requirements, and the next four evidence-gated tasks. | Use it as the first continuation surface if context resets in this workspace; do not commit handoff files. |

## Next Queue

1. Fix calibration commands mutating `Gemfile.lock`.
   - Why now: repeated targeted `bin/check_project_analyzer_calibration`
     invocations rewrite `rubocop-metz (= 0.4.0)` to `rubocop-metz (~> 0.4.0)`,
     creating manual cleanup after read-only calibration.
   - Definition of done: the targeted DeepInheritanceTree and RepeatedBranching
     no-write calibration commands leave `git diff -- Gemfile.lock` empty, with
     a regression test covering the no-mutation behavior.
   - Files likely touched: `bin/check_project_analyzer_calibration`,
     `Gemfile.lock`, calibration runner tests, and test support helpers.
   - Not in scope: changing dependency constraints or release metadata.

2. Add a no-worktree-mutation guard for read-only maintenance commands.
   - Why now: `--no-write` should mean no tracked-file mutations, and the
     lockfile drift shows this contract is currently implicit.
   - Definition of done: a focused test or helper runs representative read-only
     commands in a temporary copy and fails if tracked files change.
   - Files likely touched: `test/`, `bin/check_project_analyzer_calibration`,
     and possibly a small reusable test helper.
   - Not in scope: enforcing the guard on commands that intentionally write
     artifacts.

3. Add a tracker hygiene guard that separates actionable queue items from
   parked/watch-only items.
   - Why now: repeated package/#25/#27/#28 sweeps proved the tracker can send
     agents into bookkeeping loops.
   - Definition of done: a lightweight script or test fails when every top
     `Next Queue` item is phrased as watch/keep/defer without an actionable
     code, test, docs, or tooling outcome.
   - Files likely touched: `PROJECT_TRACKER.md`, `test/`, and optionally a
     small `bin/check_tracker_queue` helper.
   - Not in scope: building a general project-management system.

4. Add a Rubydex drift check command for future dependency upgrades.
   - Why now: the Rubydex `0.2.7` upgrade showed only four index-backed
     analyzers need rechecking after Rubydex version drift.
   - Definition of done: a command runs the four index-backed analyzers
     against the active manifest and prints a compact count/confidence/severity
     summary suitable for release-response notes.
   - Files likely touched: `bin/`, `docs/rubydex-spike.md`,
     `docs/project-analyzer-calibration.md`, and tests for command output.
   - Not in scope: rechecking AST-only analyzers after Rubydex-only upgrades.

5. Add calibration delta reporting against the last documented baseline.
   - Why now: manual comparisons of 697/806, 607/607, 363/363, and 51/122 are
     error-prone and encourage repeated full reruns.
   - Definition of done: calibration output can show count deltas by analyzer,
     confidence, severity, and category compared with a checked-in baseline
     file.
   - Files likely touched: calibration evidence runner code, fixtures under
     `test/fixtures/`, and `docs/project-analyzer-calibration.md`.
   - Not in scope: changing analyzer thresholds from the delta output alone.

6. Add stable DeepInheritanceTree category fixture coverage.
   - Why now: #27 is parked because broad-root labels are currently doing the
     intended work; that learned behavior should be guarded directly.
   - Definition of done: tests assert representative broad-root categories such
     as `rails application base`, `controller base`, `serializer base`,
     `application job base`, and `framework root`.
   - Files likely touched: `test/metz_scan/analyzers/inheritance_descendants*`,
     project-index fixtures, and focused calibration fixtures.
   - Not in scope: adding new root-kind categories without evidence.

7. Add stable RepeatedBranching triage fixture coverage.
   - Why now: #28 is parked because generic subjects are already low/context
     required while state/expression subjects remain medium/design pressure.
   - Definition of done: tests assert representative metadata and message output
     for generic, state, and expression branch subjects, including
     `decision_subject_kind`.
   - Files likely touched: `test/metz_scan/analyzers/repeated_branching_*` and
     `lib/metz_scan/analyzers/repeated_branching*` only if gaps appear.
   - Not in scope: expanding branch parsing or changing thresholds.

8. Improve project analyzer summary output for high-volume opt-in runs.
   - Why now: large opt-in outputs are hard to scan, and repeated manual
     summaries have focused on the same confidence/severity/category breakdowns.
   - Definition of done: text output includes a compact top-level summary with
     analyzer counts, confidence counts, severity counts, and category counts
     before detailed findings.
   - Files likely touched: scan output rendering, calibration output fixtures,
     and README examples if the user-facing output changes.
   - Not in scope: changing JSON/SARIF schemas unless necessary.

9. Add a contributor-facing package install troubleshooting smoke.
   - Why now: package watch is no longer active work, but the release response
     path would be faster with a scripted consumer install diagnostic.
   - Definition of done: a command or documented smoke verifies GitHub Packages
     credentials, installs `metz-scan`, and reports actionable failures without
     publishing or mutating the repo.
   - Files likely touched: `bin/check_published_gem`, README install docs,
     `docs/releases/`, and tests around error messages.
   - Not in scope: changing package ownership or publishing a new gem.

10. Make `bin/check_ci_parity` faster to diagnose when it fails.
    - Why now: the parity guard is required before pushes and can take enough
      time that failures should point directly to the failing phase and clone
      path.
    - Definition of done: failure output names the exact phase, preserves the
      clean clone path for inspection, and has tests for at least one failing
      phase.
    - Files likely touched: `bin/check_ci_parity` and command tests.
    - Not in scope: removing any existing parity phase.

11. Add a command for generating a concise issue-comment evidence summary.
    - Why now: parked issues #25/#27/#28 repeatedly need the same concise
      evidence, but agents should not manually rewrite it each time.
    - Definition of done: a script can render a read-only summary for a chosen
      issue or analyzer from current tracker/calibration state without posting
      to GitHub.
    - Files likely touched: `bin/`, `docs/project-analyzer-calibration.md`, and
      tests for rendered output.
    - Not in scope: automatically commenting on GitHub issues.

12. Add a docs freshness check for README analyzer-status claims.
    - Why now: README status tables, readiness catalog text, and calibration
      docs can drift as analyzer status and default-output eligibility change.
    - Definition of done: a focused test checks README analyzer statuses against
      the analyzer constants/readiness catalog for status and default-output
      eligibility.
    - Files likely touched: `README.md`,
      `lib/metz_scan/calibration/project_analyzer_evidence_runner/readiness_catalog.rb`,
      and docs/tests.
    - Not in scope: rewriting analyzer behavior.

## Latest Slice Checkpoint

Slice: 2026-07-04 parked-queue follow-up and package watch recheck.

Window: 16:04:26-16:08:05 -0700, 3m 39s elapsed through package/#25/#27/#28
checks, agenticon evidence collection, incidental lockfile restoration, and
tracker review.

1. Checked for higher-priority work before repeating the parked queue.
   - `git fetch origin` found no new remote work.
   - Local `main` was clean and two commits ahead of `origin/main` at
     `b2513a8 Record queued task follow-up`; `origin/main` remained at
     `f9f5a10 Document Rubydex release response playbook`.
   - There were no open PRs.
   - The latest five `main` CI runs were green, including run `28721866073`
     for `f9f5a10`.
   - Open issues remained exactly #25, #27, and #28.
2. Completed task 1: package/release feedback watch.
   - `bin/check_published_gem 0.4.0` passed again against GitHub Packages,
     resolving both `metz-scan` and `rubocop-metz` at `0.4.0`.
   - The `v0.4.0` GitHub Release remains published, not draft or prerelease.
   - Both package versions are visible in GitHub Packages, issue search found
     no concrete package/install/release defect, and there are no open
     milestones.
3. Completed task 2: #25 dogfood CI trigger check.
   - #25 remains open and explicitly trigger-gated.
   - Contributor evidence remains `fuentesjr` plus Dependabot, currently 197
     owner contributions and 7 Dependabot contributions, with no open PRs and
     no regular multi-human PR flow.
   - CI still intentionally has no `bin/check_dogfood` step.
   - Dogfood CI enforcement remains deferred.
4. Completed task 3: #27 DeepInheritanceTree evidence check.
   - A targeted no-write active-fixture recheck produced 363 DeepInheritanceTree
     findings and 363 offenses: low 213, medium 150, broad-base 213, and
     manual-review 150.
   - The issue's concrete noisy examples are already covered by current labels:
     `rails application base`, `controller base`, `application job base`,
     `framework root`, and `serializer base`.
   - Focused Mastodon/Discourse reruns stayed at 87 findings:
     Discourse 47, Mastodon 40; 68 broad-base and 19 manual-review overall.
   - Current broad-root labels and triage are already in place, and the
     remaining medium bucket is too heterogeneous for another filter.
   - No behavior, grouping, threshold, status, or output-policy change is
     justified. Keep #27 parked for future generic root-kind evidence only.
5. Completed task 4: #28 RepeatedBranching evidence check.
   - RepeatedBranching is AST-only, so Rubydex drift does not directly affect
     it. A targeted no-write active-fixture recheck produced 51 findings and
     122 offenses: generic 13, state 25, expression 13, low 13, medium 38,
     context-required 13, and design-pressure 38.
   - Focused Mastodon/Discourse reruns stayed at 19 findings and 41 offenses:
     generic 10, state 4, expression 5.
   - Current implementation already downranks generic subjects to
     low/context-required and includes decision-subject metadata.
   - No wording, metadata, grouping, confidence/severity, threshold, or
     output-policy change is justified.
6. Restored an incidental Bundler lockfile rewrite.
   - A targeted calibration command again rewrote `Gemfile.lock` from
     `rubocop-metz (= 0.4.0)` to `rubocop-metz (~> 0.4.0)`.
   - The line was restored because this slice should not change dependency
     resolution.
7. Kept implementation work out of scope.
   - No production Ruby, analyzer behavior, CI workflow, package release, or
     GitHub issue state changes were made in this slice.
   - The ignored handoff file remains in place because this tracker checkpoint
     is not pushed yet.

Agenticons used: `helper_worker: package/release feedback and priority sweep`
(`019f2f60-7245-7dc3-bd2d-f21e6bbc687d`),
`helper_worker: #25 dogfood CI trigger check`
(`019f2f60-8c62-7672-88ea-924966d3b227`),
`helper_worker: #27 DeepInheritanceTree evidence`
(`019f2f60-a799-7580-a053-6fa50138fa64`), and
`helper_worker: #28 RepeatedBranching evidence`
(`019f2f60-c4b2-7d63-8e92-5cc85e1ba290`).

## Parked / Not Next

- Package/release feedback watch is trigger-gated. Reopen only for a concrete
  install, package metadata, release artifact, or registry access defect.
- #25 dogfood CI enforcement is trigger-gated. Reopen only when collaboration
  expands beyond owner plus Dependabot, when PRs regularly come from multiple
  people, or when CI-enforced dogfood drift becomes a deliberate policy goal.
- #27 DeepInheritanceTree remains parked. Reopen only with new misleading
  root-label evidence that is not already covered by current broad-root labels
  and downranking.
- #28 RepeatedBranching remains parked. Reopen only with new evidence that
  generic low/context-required branch-subject findings are still confusing or
  underexplained after the README and metadata improvements.
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
| 2026-07-04 | `e954cee` | Recorded the parked-queue follow-up and kept package/#25/#27/#28 parked. |
| 2026-07-04 | `b2513a8` | Recorded the queued-task follow-up and kept package/#25/#27/#28 parked. |
| 2026-07-04 | `1ae96ea` | Recorded the release-response playbook follow-up and kept package/#25/#27/#28 parked. |
| 2026-07-04 | `f9f5a10` | Documented the Rubydex release-response playbook. |
| 2026-07-04 | `d7fd52d` | Recorded the Rubydex 0.2.7 calibration drift recheck and kept package/#25/#27/#28 parked. |
| 2026-07-03 | `4d88a82` | Updated Rubydex spike results for Rubydex 0.2.7. |
| 2026-07-03 | `c275c6c` | Restructured the README analyzer behavior details and recorded the pushed parked-queue checkpoint. |
| 2026-07-03 | `45f25a8` | Recorded the pushed README/tracker verification and kept package/#25/#27/#28 parked. |
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
