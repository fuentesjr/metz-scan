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
- Latest pushed baseline: `74f3d75 Rewrite tracker queue with actionable
  tasks`.
- CI state: run `28722875969` for `74f3d75` succeeded in about 1m 24s after
  the upstream push. The previous pushed baseline `e954cee` succeeded in run
  `28722722473` in 1m 27s. Earlier runs for `c0a01f5` (`28672899400`) and
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
  next-four evidence sweep, Dependabot PR #29, README cleanup, parked-queue
  tracker checkpoints, README analyzer-details cleanup, Rubydex spike results,
  the Rubydex 0.2.7 calibration drift checkpoint, the Rubydex release-response
  playbook, and the actionable tracker rewrite (`74f3d75`) are pushed to
  `origin/main`. The workflow-hardening slice (`8c740ee`) and this
  calibration-summary slice are local until the post-commit parity check and
  upstream push complete.
- Latest checkpoint window: 16:54:35-18:21:58 -0700, 1h 27m 23s elapsed through
  four calibration-summary tasks, agenticon evidence collection, full active
  manifest baseline comparison, focused tests, fast/slow test partitions, full
  RuboCop, and tracker update.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Complete | `v0.4.0` is tagged, released on GitHub, published to GitHub Packages for both gems, verified with repeated post-publish smoke, issue #30 is closed, and post-release CI for `f9f5a10` is green. | Monitor package installation feedback; no `0.4.x` follow-up milestone is open without a concrete defect. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Fresh #27/#28 Mastodon and Discourse reruns did not show enough misleading or underexplained findings to justify behavior, threshold, or output-policy changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Guarded | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated; Rubydex `0.2.7` was rechecked against the active manifest. Full active-manifest output is 697 findings/806 offenses; the four Rubydex-index-backed analyzers account for 607 findings/607 offenses. A compact Rubydex drift check covers those four analyzers, and `docs/calibration/project_analyzer_baseline.yml` now captures the full active-manifest baseline for delta reporting. | Recheck only Rubydex-index-backed analyzers after future Rubydex upgrades unless an AST-only analyzer changes; use `--baseline-file docs/calibration/project_analyzer_baseline.yml` for full-manifest drift. |
| Workflow friction | Guarded | The lockfile rewrite came from a stale path dependency entry in `Gemfile.lock`; the lockfile now matches the gemspec's `rubocop-metz (~> 0.4.0)` constraint, and read-only maintenance commands have a tracked-worktree mutation guard. | Maintain the guard list as new read-only commands are added; do not bypass `BUNDLE_FROZEN=1` for read-only calibration checks. |
| Sorbet adoption spike | Complete | Issue #26 was evaluated in a disposable workspace, documented, synced back to GitHub, and closed. The report recommends not adopting now: a narrow static setup is possible, but generated RBI churn, command policy, fixture scope, and runtime signature implications outweigh observed value. | Do not add Sorbet unless a concrete type-related defect, contributor ergonomics need, or stable public API typing requirement appears. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, current notes are short, and the Sorbet spike report records the tooling decision. The README now splits RepeatedBranching generic-subject guidance into a short list, the analyzer behavior details into per-analyzer subsections, and the calibration docs point future Rubydex upgrades at the compact drift command plus active-manifest baseline deltas. | Keep docs changes minimal and evidence-led. |
| Handoff continuity | Active | Local ignored handoff `.handoffs/20260703173813_next_four_tasks_after_issue_sync.md` captures the pushed issue-sync summary, conversation-only requirements, and the next four evidence-gated tasks. | Use it as the first continuation surface if context resets in this workspace; do not commit handoff files. |

## Next Queue

1. Wire the tracker hygiene guard into the push/parity path.
   - Why now: `bin/check_tracker_queue` now catches stale watch-only queues, but
     it is not yet part of the required push guard.
   - Definition of done: `bin/check_ci_parity` or another documented pre-push
     command runs `bin/check_tracker_queue`, and tests cover a failing queue
     without requiring a dirty worktree.
   - Files likely touched: `bin/check_ci_parity`, `bin/check_tracker_queue`,
     `test/metz_scan/check_tracker_queue_test.rb`, and this tracker.
   - Not in scope: blocking ordinary documentation changes when the queue
     remains actionable.

2. Add a contributor-facing package install troubleshooting smoke.
   - Why now: package watch is no longer active work, but the release response
     path would be faster with a scripted consumer install diagnostic.
   - Definition of done: a command or documented smoke verifies GitHub Packages
     credentials, installs `metz-scan`, and reports actionable failures without
     publishing or mutating the repo.
   - Files likely touched: `bin/check_published_gem`, README install docs,
     `docs/releases/`, and tests around error messages.
   - Not in scope: changing package ownership or publishing a new gem.

3. Make `bin/check_ci_parity` faster to diagnose when it fails.
    - Why now: the parity guard is required before pushes and can take enough
      time that failures should point directly to the failing phase and clone
      path.
    - Definition of done: failure output names the exact phase, preserves the
      clean clone path for inspection, and has tests for at least one failing
      phase.
    - Files likely touched: `bin/check_ci_parity` and command tests.
    - Not in scope: removing any existing parity phase.

4. Add a command for generating a concise issue-comment evidence summary.
    - Why now: parked issues #25/#27/#28 repeatedly need the same concise
      evidence, but agents should not manually rewrite it each time.
    - Definition of done: a script can render a read-only summary for a chosen
      issue or analyzer from current tracker/calibration state without posting
      to GitHub.
    - Files likely touched: `bin/`, `docs/project-analyzer-calibration.md`, and
      tests for rendered output.
    - Not in scope: automatically commenting on GitHub issues.

5. Add a docs freshness check for README analyzer-status claims.
    - Why now: README status tables, readiness catalog text, and calibration
      docs can drift as analyzer status and default-output eligibility change.
    - Definition of done: a focused test checks README analyzer statuses against
      the analyzer constants/readiness catalog for status and default-output
      eligibility.
    - Files likely touched: `README.md`,
      `lib/metz_scan/calibration/project_analyzer_evidence_runner/readiness_catalog.rb`,
      and docs/tests.
    - Not in scope: rewriting analyzer behavior.

6. Add Rubydex drift skip-path coverage without the optional bundle group.
    - Why now: `bin/check_rubydex_drift --allow-missing-rubydex` is intended for
      environments without the optional project index, but the current command
      tests exercise the installed-Rubydex path.
    - Definition of done: a subprocess test simulates missing `rubydex`, asserts
      the default command fails clearly, and asserts `--allow-missing-rubydex`
      exits successfully with a skip message.
    - Files likely touched: `bin/check_rubydex_drift` and
      `test/metz_scan/check_rubydex_drift_test.rb`.
    - Not in scope: changing optional dependency constraints.

7. Document the read-only maintenance command contract.
    - Why now: `--no-write`, `BUNDLE_FROZEN=1`, and tracked-worktree mutation
      checks now have repo behavior behind them, but contributors need one
      short place to see the contract.
    - Definition of done: contributor-facing docs name the read-only commands,
      explain the tracked-file guard, and point future command authors at
      `bin/check_read_only_commands`.
    - Files likely touched: `README.md`, `docs/project-analyzer-calibration.md`,
      and possibly `CONTRIBUTING.md` if it exists by then.
    - Not in scope: documenting commands that intentionally write artifacts.

8. Add a stable output fixture for the Rubydex drift command.
    - Why now: the compact drift command is intended for release-response notes,
      so its summary shape should be pinned before it becomes another manual
      reporting surface.
    - Definition of done: a fixture or exact-output test covers text output for
      the sample app, including analyzer list, finding/offense counts, and
      confidence/severity breakdowns.
    - Files likely touched: `test/fixtures/`, `bin/check_rubydex_drift`, and
      `test/metz_scan/check_rubydex_drift_test.rb`.
    - Not in scope: pinning active-manifest counts that change with upstream
      fixture repositories.

9. Add a stable fixture for baseline-delta Markdown output.
   - Why now: baseline deltas now persist to Markdown artifacts, but the exact
     Markdown shape is covered through behavioral assertions rather than a
     stable fixture pair.
   - Definition of done: a representative baseline-aware summary fixture pins
     the Markdown `Baseline Deltas` table shape, including no-change and changed
     rows.
   - Files likely touched: `test/fixtures/project_analyzer_evidence_runner/`,
     `test/metz_scan/calibration/project_analyzer_evidence_runner_test.rb`,
     and possibly `markdown_renderer.rb`.
   - Not in scope: changing the baseline-delta JSON payload.

10. Add analyzer-filter baseline guidance and examples.
    - Why now: the baseline scope guard intentionally rejects comparing a
      filtered analyzer run against the full active-manifest baseline, but the
      docs only describe the full-manifest path.
    - Definition of done: docs show how to create or use a matching-scope
      baseline for `--analyzer` filtered reruns and explain the scope mismatch
      failure.
    - Files likely touched: `docs/project-analyzer-calibration.md`, README, and
      command help tests if examples become part of help output.
    - Not in scope: relaxing the scope guard.

11. Add exact text-output fixture coverage for aggregate project analyzer counts.
    - Why now: text output now shows analyzer, confidence, severity, and
      category aggregate lines, but current tests assert selected substrings.
    - Definition of done: an exact-output or fixture-backed test pins the
      project-analyzer summary block without pinning unrelated offense detail.
    - Files likely touched:
      `test/metz_scan/commands/scan_text_renderer_project_analyzer_test.rb`
      and `test/fixtures/`.
    - Not in scope: changing JSON/SARIF schemas.

12. Add a baseline refresh helper in dry-run mode.
    - Why now: `docs/calibration/project_analyzer_baseline.yml` is manually
      checked in, and future fixture updates need a repeatable way to preview
      the next baseline without writing artifacts or guessing the compact
      schema.
    - Definition of done: a command prints the compact baseline document for a
      calibration summary and can be used in docs to refresh the tracked
      baseline intentionally.
    - Files likely touched: `bin/`, calibration runner helpers, tests, and
      `docs/project-analyzer-calibration.md`.
    - Not in scope: automatically changing the baseline during normal
      calibration runs.

## Latest Slice Checkpoint

Slice: 2026-07-04 calibration summary next four tasks.

Window: 16:54:35-18:21:58 -0700, 1h 27m 23s elapsed through four
calibration-summary tasks, agenticon evidence collection, full active-manifest
baseline comparison, focused tests, fast/slow test partitions, full RuboCop,
and tracker update.

1. Completed task 1: added calibration delta reporting against the checked-in
   active-manifest baseline.
   - Added `docs/calibration/project_analyzer_baseline.yml`, seeded from the
     full active manifest at 697 findings and 806 offenses.
   - Added `--baseline-file` to `bin/check_project_analyzer_calibration`.
   - Baseline deltas now compare total findings/offenses, analyzer rule counts,
     confidence counts, severity counts, and `project_analyzer_category`
     counts. The comparison is in the summary payload, so text, JSON, and
     Markdown artifacts share the same result.
   - Scope validation rejects misleading comparisons across `targets_file`,
     `default_output`, or analyzer-filter mismatches.
2. Completed task 2: broadened DeepInheritanceTree category fixture coverage.
   - Added command-level merged-output coverage for representative broad-root
     categories: `rails application base`, `controller base`, `serializer base`,
     `application job base`, and `framework root`.
   - The tests assert low-confidence `broad base` triage, root-kind metadata,
     message labels, and summary breakdowns without changing analyzer behavior.
3. Completed task 3: broadened RepeatedBranching triage fixture coverage.
   - Added explicit state-subject metadata assertions, including
     `decision_subject_kind`, `decision_subject_label`, and message text.
   - Added expression-subject triage coverage showing expression subjects stay
     validated medium-confidence `design pressure`.
   - Added command-level merged-offense coverage proving
     `decision_subject_kind` survives into the emitted project-analyzer
     metadata.
4. Completed task 4: improved high-volume project analyzer text summaries.
   - Text output now prints aggregate analyzer, confidence, severity, and
     category count lines immediately after the project-analyzer heading and
     before per-rule summaries.
   - JSON and SARIF schemas remain unchanged; the formatter derives aggregate
     lines from existing rule summaries and breakdowns.
   - README and calibration docs now describe aggregate summary output and
     baseline delta usage.
5. Verified the slice locally.
   - Full active-manifest baseline comparison passed with zero deltas:
     697 findings, 806 offenses, analyzer deltas none, confidence deltas none,
     severity deltas none, and category deltas none.
   - Focused tests passed for calibration evidence runner, scan text renderer,
     RepeatedBranching subject/triage, DeepInheritanceTree runner output, and
     project-analyzer triage metadata.
   - `bundle exec rake test:fast` passed with 404 runs, 1830 assertions, no
     failures/errors, and 2 skips.
   - `bundle exec rake test:slow` passed with 77 runs, 368 assertions, and no
     failures/errors/skips.
   - Full `bundle exec rubocop` passed across 205 files with no offenses.

Agenticons used: `helper_worker: calibration delta reporting design`
(`019f2f8e-d830-7041-a8ff-259bffae08f0`),
`helper_worker: DeepInheritanceTree category fixture coverage`
(`019f2f8e-edc2-7310-86d6-4cd001d14040`),
`helper_worker: RepeatedBranching triage fixture coverage`
(`019f2f8f-027b-7662-98eb-b4def1524c8d`), and
`helper_worker: project analyzer text summary output`
(`019f2f8f-231c-7c01-b167-900183817edf`).

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
| 2026-07-04 | `this commit` | Added calibration baseline deltas, broader DeepInheritanceTree and RepeatedBranching fixture coverage, aggregate project-analyzer text summaries, and tracker updates. |
| 2026-07-04 | `8c740ee` | Added lockfile no-mutation coverage, read-only command guard, tracker hygiene guard, Rubydex drift command, and workflow-hardening tracker updates. |
| 2026-07-04 | `74f3d75` | Rewrote the tracker queue with at least ten actionable tasks and recorded the tracker-only commit rule. |
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
- Tracked calibration baseline: `docs/calibration/project_analyzer_baseline.yml`.
- Published `v0.4.0` release notes: `docs/releases/v0.4.0.md`.
- Sorbet adoption spike: `docs/spikes/sorbet-issue-26.md`.
- Local ignored handoff, not committed:
  `.handoffs/20260703173813_next_four_tasks_after_issue_sync.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
