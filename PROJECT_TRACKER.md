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
  steps and tracker hygiene against the committed HEAD in a clean clone, so
  local-only environment assumptions (bundler config such as the optional
  rubydex group, untracked files) fail locally instead of in CI.
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

- Date: 2026-07-05.
- Latest pushed baseline: `8881795 Improve workflow diagnostics and summaries`.
- CI state: run `28747058143` for `8881795` succeeded in 1m 45s after the
  upstream push. Earlier runs for `c0a01f5` (`28672899400`) and `64bceea`
  (`28680427556`) failed on calibration evidence runner environment
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
  playbook, the actionable tracker rewrite (`74f3d75`), workflow-hardening
  slice (`8c740ee`), calibration-summary slice (`0d902f9`), and
  workflow-diagnostics slice (`8881795`) are pushed to `origin/main`. This
  README/read-only/Rubydex drift guard slice is local until validation, commit,
  and any requested upstream push complete.
- Latest checkpoint window: 2026-07-05 09:09:00-09:32:26 -0700, 23m 26s
  wall-clock elapsed through four guard/documentation tasks, agenticon evidence
  collection, focused tests, release-checklist docs, and tracker update.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Complete | `v0.4.0` is tagged, released on GitHub, published to GitHub Packages for both gems, verified with repeated post-publish smoke, issue #30 is closed, and post-release CI for `f9f5a10` is green. | Monitor package installation feedback; no `0.4.x` follow-up milestone is open without a concrete defect. |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, and the tracked target manifest under `docs/calibration/` are covered. | Maintain; change only when artifact or target-manifest behavior changes. |
| Analyzer behavior | Parked | Fresh #27/#28 Mastodon and Discourse reruns did not show enough misleading or underexplained findings to justify behavior, threshold, or output-policy changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Guarded | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated; Rubydex `0.2.7` was rechecked against the active manifest. Full active-manifest output is 697 findings/806 offenses; the four Rubydex-index-backed analyzers account for 607 findings/607 offenses. A compact Rubydex drift check covers those four analyzers, now with missing-Rubydex skip-path coverage and an exact sample-app text fixture, and `docs/calibration/project_analyzer_baseline.yml` captures the full active-manifest baseline for delta reporting. | Recheck only Rubydex-index-backed analyzers after future Rubydex upgrades unless an AST-only analyzer changes; use `--baseline-file docs/calibration/project_analyzer_baseline.yml` for full-manifest drift. |
| Workflow friction | Guarded | The lockfile rewrite came from a stale path dependency entry in `Gemfile.lock`; the lockfile now matches the gemspec's `rubocop-metz (~> 0.4.0)` constraint, read-only maintenance commands have a tracked-worktree mutation guard, the read-only command contract is documented in contributor/calibration/release docs, and `bin/check_ci_parity` runs tracker hygiene before Bundler work while preserving failed clean clones for inspection. | Maintain the guard list and docs as new read-only commands are added; do not bypass `BUNDLE_FROZEN=1` for read-only calibration checks. |
| Sorbet adoption spike | Complete | Issue #26 was evaluated in a disposable workspace, documented, synced back to GitHub, and closed. The report recommends not adopting now: a narrow static setup is possible, but generated RBI churn, command policy, fixture scope, and runtime signature implications outweigh observed value. | Do not add Sorbet unless a concrete type-related defect, contributor ergonomics need, or stable public API typing requirement appears. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, current notes are short, and the Sorbet spike report records the tooling decision. The README now splits RepeatedBranching generic-subject guidance into a short list, the analyzer behavior details into per-analyzer subsections, package install troubleshooting points at `bin/check_published_gem`, the analyzer status table has freshness coverage, and calibration docs point future Rubydex upgrades plus parked issue updates at repeatable local commands. | Keep docs changes minimal and evidence-led. |
| Handoff continuity | Active | Local ignored handoff `.handoffs/20260703173813_next_four_tasks_after_issue_sync.md` captures the pushed issue-sync summary, conversation-only requirements, and the next four evidence-gated tasks. | Use it as the first continuation surface if context resets in this workspace; do not commit handoff files. |

## Next Queue

1. Add a stable fixture for baseline-delta Markdown output.
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

2. Add analyzer-filter baseline guidance and examples.
    - Why now: the baseline scope guard intentionally rejects comparing a
      filtered analyzer run against the full active-manifest baseline, but the
      docs only describe the full-manifest path.
    - Definition of done: docs show how to create or use a matching-scope
      baseline for `--analyzer` filtered reruns and explain the scope mismatch
      failure.
    - Files likely touched: `docs/project-analyzer-calibration.md`, README, and
      command help tests if examples become part of help output.
    - Not in scope: relaxing the scope guard.

3. Add exact text-output fixture coverage for aggregate project analyzer counts.
    - Why now: text output now shows analyzer, confidence, severity, and
      category aggregate lines, but current tests assert selected substrings.
    - Definition of done: an exact-output or fixture-backed test pins the
      project-analyzer summary block without pinning unrelated offense detail.
    - Files likely touched:
      `test/metz_scan/commands/scan_text_renderer_project_analyzer_test.rb`
      and `test/fixtures/`.
    - Not in scope: changing JSON/SARIF schemas.

4. Add a baseline refresh helper in dry-run mode.
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

5. Add exact-output fixture coverage for issue-comment summaries.
   - Why now: `bin/render_issue_comment_summary` is intentionally concise, so
     its paste-ready shape should be pinned before more parked issues use it.
   - Definition of done: fixture-backed tests cover #25, #27, and #28 output
     shape, including tracker boundary, readiness text, and baseline counts.
   - Files likely touched: `test/fixtures/`, `test/metz_scan/`, and
     `bin/render_issue_comment_summary`.
   - Not in scope: posting comments to GitHub.

6. Add `GEM_CREDENTIALS` fallback coverage for the package install smoke.
    - Why now: `bin/check_published_gem` supports Bundler credentials,
      `GITHUB_PACKAGES_TOKEN`, and `GEM_CREDENTIALS`, but the new failure-mode
      coverage still does not exercise the credentials-file fallback.
    - Definition of done: a subprocess test uses a temp credentials file with a
      `:github` token and verifies install output remains redacted.
    - Files likely touched: `test/metz_scan/check_published_gem_failure_test.rb`
      and `test/fixtures/check_published_gem/fake_bundle`.
    - Not in scope: changing credential precedence.

7. Add contributor docs for parity failure inspection.
    - Why now: release checklists note that failed clones are preserved, but
      contributors need one short troubleshooting example for rerunning the
      failed phase in that clone.
    - Definition of done: docs show how to use the `clean clone preserved at`
      and `next action` lines without implying the temp clone should be kept
      after successful runs.
    - Files likely touched: `README.md` and `RELEASE_CHECKLIST.md`.
    - Not in scope: adding automatic cleanup of failed clones.

8. Add issue-summary help examples and supported-target docs.
    - Why now: `bin/render_issue_comment_summary --help` currently shows only
      the argument shape, while the supported issues and analyzer aliases live
      in code.
    - Definition of done: help or docs list #25, #27, #28, mapped analyzer
      names, and the local-only/no-posting boundary.
    - Files likely touched: `bin/render_issue_comment_summary`, README, and
      `docs/project-analyzer-calibration.md`.
    - Not in scope: posting comments to GitHub or adding live issue lookups.

9. Add ProjectIndex missing-Rubydex backend subprocess coverage.
    - Why now: the drift command now simulates missing `rubydex` with a scoped
      `RUBYOPT` shim, but backend fallback behavior still relies on existing
      in-process coverage and manual confidence.
    - Definition of done: subprocess coverage forces `require "rubydex"` to
      raise, asserts `ProjectIndex.build(..., backend: :auto)` falls back to
      the null backend with a clear reason, and asserts explicit
      `backend: :rubydex` raises the expected unavailable-backend error.
    - Files likely touched: `test/metz_scan/project_index_test.rb` and
      possibly test support for scoped missing-Rubydex subprocess helpers.
    - Not in scope: changing backend selection behavior.

10. Add non-Rubydex compact text renderer fixture coverage.
    - Why now: the Rubydex drift text fixture is exact, but it still skips when
      the optional `rubydex` bundle group is unavailable.
    - Definition of done: a deterministic summary fixture or extracted renderer
      test pins the compact text shape without requiring the Rubydex backend,
      while keeping the end-to-end sample-app Rubydex test as optional
      integration coverage.
    - Files likely touched: `bin/check_rubydex_drift`, renderer/support code,
      `test/fixtures/check_rubydex_drift/`, and tests.
    - Not in scope: changing the command's user-facing text output.

11. Expose the read-only default command list as a public testable contract.
    - Why now: the docs freshness test now derives commands from
      `bin/check_read_only_commands`, but it parses the script's source layout.
    - Definition of done: the guard exposes default commands through a stable
      command-listing mode or importable constant, and docs tests use that
      surface instead of regexing the script body.
    - Files likely touched: `bin/check_read_only_commands`,
      `test/metz_scan/read_only_command_docs_test.rb`, and command/help tests.
    - Not in scope: changing the default guarded commands.

12. Add a compact JSON fixture for the Rubydex drift command.
    - Why now: text output is now fixture-backed, but JSON output is still
      covered only by selected field assertions.
    - Definition of done: a sample-app JSON fixture pins targets, analyzer
      names, finding/offense counts, rule summaries, and breakdown payload.
    - Files likely touched: `test/fixtures/check_rubydex_drift/` and
      `test/metz_scan/check_rubydex_drift_test.rb`.
    - Not in scope: pinning active-manifest JSON counts.

## Latest Slice Checkpoint

Slice: 2026-07-05 README/read-only/Rubydex drift guard next four tasks.

Window: 2026-07-05 09:09:00-09:32:26 -0700, 23m 26s wall-clock
elapsed through four guard/documentation tasks, agenticon evidence collection,
focused tests, release-checklist docs, and tracker update.

1. Completed task 1: added README analyzer-status freshness coverage.
   - `test/metz_scan/readme_project_analyzer_status_test.rb` parses the README
     status table and compares analyzer names, rollout status, and default scan
     eligibility against `ProjectAnalyzerRunner::ANALYZERS` plus
     `default_output_analyzer?`.
   - The check ignores expected-finding prose and row order so it guards the
     status/default-output claims without freezing hand-written examples.
2. Completed task 2: added Rubydex drift missing-backend coverage.
   - `test/metz_scan/check_rubydex_drift_test.rb` now uses a scoped child
     `RUBYOPT` shim to make `require "rubydex"` raise without changing the
     installed bundle or adding a production-only test knob.
   - The default command now has subprocess coverage for clear failure, and
     `--allow-missing-rubydex` has subprocess coverage for a successful skip
     message.
3. Completed task 3: documented the read-only maintenance command contract.
   - README and calibration docs now name `bin/check_read_only_commands`,
     `BUNDLE_FROZEN=1`, tracked-file dirtiness checks, and the current
     read-only command set.
   - `RELEASE_CHECKLIST.md` and the release issue template now include
     `bin/check_read_only_commands` as an explicit verification step.
   - Added docs tests for the read-only contract and release-checklist
     coverage; the read-only docs test derives the expected command list from
     `bin/check_read_only_commands`.
4. Completed task 4: added stable Rubydex drift text output coverage.
   - `test/fixtures/check_rubydex_drift/sample_app_text.txt` pins the compact
     sample-app text output, including analyzer list, finding/offense counts,
     rule summary, and confidence/severity breakdowns.
   - The test intentionally uses the positional sample-app path, not the active
     target manifest, so it avoids volatile upstream fixture counts.
5. Verification so far.
   - Focused tests passed for Rubydex drift, README analyzer status, read-only
     docs, release checklist sync, and release issue dry-run rendering.
   - `bundle exec rake test:fast` passed with 412 runs, 1910 assertions, no
     failures/errors, and 2 skips.
   - `bundle exec rake test:slow` passed with 86 runs, 424 assertions, and no
     failures/errors/skips.
   - Full `bundle exec rubocop` passed across 211 files with no offenses.
   - `bin/check_tracker_queue` and `git diff --check` passed.
   - `bin/check_read_only_commands` was spot-checked before commit and
     correctly refused the dirty tracked worktree; run it only from a clean
     tree.
   - Strategic validation passed: slice tests, red/green, lint,
     debt-marker gate, and warnings all clean.
   - Required design review verdict was clean. One remaining concern is tracked
     in the next queue: the read-only docs test derives commands by parsing the
     guard script's source layout instead of a public listing surface.

Agenticons used: `helper_worker: README analyzer-status freshness`
(`019f3316-d801-7d10-8d29-582391892713`),
`helper_worker: Rubydex missing-backend skip path`
(`019f3317-0e4a-7cf3-a18d-9be8bcaf72f0`),
`helper_worker: read-only maintenance command contract docs`
(`019f3317-273b-77e1-b345-5f377a7b31f6`), and
`helper_worker: Rubydex drift output fixture coverage`
(`019f3317-41fd-7461-bd6a-08711cb09303`).

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
| 2026-07-05 | `this commit` | Added README analyzer-status freshness coverage, Rubydex drift missing-backend and exact text fixture coverage, read-only maintenance docs, release guard checklist coverage, and tracker updates. |
| 2026-07-05 | `8881795` | Wired tracker hygiene into CI parity, improved parity/package troubleshooting diagnostics, added issue-comment evidence summaries, and updated the tracker queue. |
| 2026-07-04 | `0d902f9` | Added calibration baseline deltas, broader DeepInheritanceTree and RepeatedBranching fixture coverage, aggregate project-analyzer text summaries, and tracker updates. |
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
