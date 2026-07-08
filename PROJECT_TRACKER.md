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
  made the update necessary. Exception: a deliberate direction change (new
  goals, queue strategy, or standing rules) may land as its own commit — the
  rule targets checkpoint churn, not strategy decisions.
- Do not keep rechecking parked/watch-only items just because they are listed
  near the top of the tracker. Move them to trigger-gated parked work and pick
  the next actionable improvement.
- Keep process overhead capped: slice checkpoints are a few lines (what
  changed, how it was verified, anything surprising) — git history carries the
  rest. Tracker/docs churn should not outweigh product-code churn across a
  multi-slice window; if it does, the queue has drifted inward.
- Prefer queue work that a user of the tool would notice over work only this
  repo's tests would notice. Coverage sweeps are parked by default.

## Current Direction

`metz-scan` is heading toward a public rubygems.org release, gated on product
quality proven through dogfooding — not on more internal process hardening.
The 2026-07-05 direction review found effort had drifted inward (docs/tracker
churn 2.6x product-code churn, test suite larger than both gems' product code)
while the first real dogfooding run immediately surfaced a headline UX defect
(#31). The engine for direction is now real usage: run the tool on real
codebases, triage what the output gets wrong or explains poorly, fix that, and
repeat.

Test-hardening is declared done: the fixture/guard surface built through
`3fb5747` is maintained, not extended. New tests accompany behavior changes or
defects, not coverage sweeps.

### Path to rubygems.org

Publishing to rubygems.org is intended but quality-gated: it is a larger
distribution surface and a bad first impression costs future adoption. To keep
that gate from becoming an indefinite "not good enough yet," the exit criteria
are concrete:

1. #31 (Metz-only scan default) and #32 (Metrics shadowing) are fixed and
   released on GitHub Packages.
2. A dogfooding round across 3-5 real external-shaped codebases produces no
   new defects in the headline-UX class (wrong default output, misleading or
   duplicated findings, broken quickstart) — findings-quality nits are fine
   and become queue work, they do not block.
3. The README quickstart is verified end-to-end against a clean install of the
   release candidate.
4. Gem metadata is release-ready: changelog, license, description, and
   homepage read correctly on a `gem build` inspection.

Both `metz-scan` and `rubocop-metz` were unclaimed on rubygems.org as of
2026-07-05. When the criteria pass, publish the then-current version; do not
burn a `1.0.0` signal on the first public push.

## Current Snapshot

- Date: 2026-07-08.
- Latest pushed baseline: `d9f92e4 Revise the testing-cops spec after review`.
- CI state: the most recent `main` runs, including the run for `d9f92e4`
  (`28904608653`), all succeeded.
- Release state: `v0.5.1` is published, but the 2026-07-07 dogfooding round
  found it carries a **crash regression** (default mode crashes on targets
  whose `.rubocop.yml` references absent external RuboCop gems). The 2026-07-08
  local slice fixes that crash/error path for the next release, pending commit,
  remaining dogfood fixes, re-dogfood, and release authorization. `v0.5.1`
  should not be recommended. Issues #33 and #34 are closed with release-link
  comments.
- Local branch state: everything through `a06b28c` (Prepare 0.5.2 release
  target) is pushed to `origin/main` with green CI (`28906854409`). `a06b28c`
  bumps both gems to `0.5.2`, but **0.5.2 must not ship as-is** — the dogfooding
  round found it still carries the crash regression. The version bump sits on
  `main` as the eventual carrier once the A/B/C fixes land; `docs/releases/v0.5.2.md`
  will be revised to describe the fixes, not only #37.
- Dogfooding state: **exit criterion 2 reran on 2026-07-07 against HEAD (0.5.2)
  and did NOT pass** — four headline-UX defects
  (`docs/dogfooding/2026-07-07-round-0.5.2.md`). The default-mode crash and
  misattributed/backtrace-leaking load-error path are fixed locally in the
  latest slice; remaining headline defects are `TargetRubyVersion` loss in
  default mode and `ControllersTooManyDirectCollaborators` over-counting
  raise-site exceptions/framework helpers. The prior 2026-07-05 `0.5.0` round
  (`docs/dogfooding/2026-07-05-round-0.5.0.md`) found #33/#34, both since fixed.
- Latest checkpoint window: 2026-07-08: default-mode crash + load-error text
  fixed locally with red-green tests and a scope-only RuboCop config loader.
  Next: fix `TargetRubyVersion`, fix collaborator over-count, re-dogfood, then
  cut a single release carrying #37 + fixes.
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | Release blocked by remaining dogfood defects | `0.5.2` version bump is committed/pushed (`a06b28c`); the 2026-07-08 local slice fixes the default-mode crash/error regression found in `v0.5.1`, but the release still needs the remaining dogfood fixes and a fresh criterion-2 pass. **0.5.2 must not be published as-is.** | Fix `TargetRubyVersion` and collaborator over-count, re-dogfood, then cut a single release carrying #37 + the fixes (own decision + authorization). |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, the tracked target manifest under `docs/calibration/`, baseline-delta Markdown fixtures, compact baseline preview structure, exact `--print-baseline` YAML output, baseline scope mismatch checks, and help examples for scope-matched baseline workflows are covered. | Maintain; change only when artifact, target-manifest, or baseline-document behavior changes. |
| Analyzer behavior | Parked | Fresh #27/#28 Mastodon and Discourse reruns did not show enough misleading or underexplained findings to justify behavior, threshold, or output-policy changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Guarded | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated; Rubydex `0.2.7` was rechecked against the active manifest. Full active-manifest output is 697 findings/806 offenses; the four Rubydex-index-backed analyzers account for 607 findings/607 offenses. A compact Rubydex drift check covers those four analyzers, now with ProjectIndex missing-Rubydex subprocess coverage, missing-Rubydex skip-path coverage, exact sample-app text/JSON fixtures, and deterministic non-Rubydex formatter fixtures; `docs/calibration/project_analyzer_baseline.yml` captures the full active-manifest baseline for delta reporting. | Recheck only Rubydex-index-backed analyzers after future Rubydex upgrades unless an AST-only analyzer changes; use `--baseline-file docs/calibration/project_analyzer_baseline.yml` for full-manifest drift. |
| Workflow friction | Guarded | The lockfile rewrite came from a stale path dependency entry in `Gemfile.lock`; the lockfile now matches the gemspec's `rubocop-metz (~> 0.4.0)` constraint, read-only maintenance commands have a tracked-worktree mutation guard plus a public command-listing mode, `--print-baseline` is in the default read-only guard list, the read-only command contract is documented in contributor/calibration/release docs, and `bin/check_ci_parity` runs tracker hygiene before Bundler work while preserving failed clean clones and printing `next action:` commands for inspection. | Maintain the guard list and docs as new read-only commands are added; do not bypass `BUNDLE_FROZEN=1` for read-only calibration checks. |
| Sorbet adoption spike | Complete | Issue #26 was evaluated in a disposable workspace, documented, synced back to GitHub, and closed. The report recommends not adopting now: a narrow static setup is possible, but generated RBI churn, command policy, fixture scope, and runtime signature implications outweigh observed value. | Do not add Sorbet unless a concrete type-related defect, contributor ergonomics need, or stable public API typing requirement appears. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, current notes are short, and the Sorbet spike report records the tooling decision. The README now splits RepeatedBranching generic-subject guidance into a short list, the analyzer behavior details into per-analyzer subsections, package install troubleshooting points at `bin/check_published_gem`, parity failure inspection points at preserved clone/`next action:` output, the analyzer status table has freshness coverage, `skills/metz-scan/SKILL.md` gives agents consumer-facing usage guidance, and calibration docs point future Rubydex upgrades, filtered baselines, compact baseline previews, and parked issue updates at repeatable local commands. | Keep docs changes minimal and evidence-led. |
| Path to rubygems.org | Active — criterion 2 failed again | Exit criterion 1 is met. Exit criterion 2 reran on 2026-07-07 (HEAD 0.5.2) and did NOT pass: four headline-UX defects (`docs/dogfooding/2026-07-07-round-0.5.2.md`). The default-mode crash/error path is fixed locally; remaining headline defects still block release readiness. Strategy remains **fix → re-dogfood → single release**. | Fix the remaining dogfood defects, re-run criterion 2 on the fixed HEAD, then a single release candidate carries #37 + fixes; verify the README quickstart (criterion 3) and run the preflight (criterion 4) against that candidate. |
| Test hardening | Done | Fixture/guard surface through `599a935` covers CLI text/JSON/help contracts, read-only guards, drift checks, package smoke, and CI parity output. Suite: 438 fast + 88 slow runs, all green. | Maintain only; new tests accompany behavior changes or defects, not coverage sweeps. |

## Next Queue

1. Fix defect B: default mode loses the target's `TargetRubyVersion` under
   `--force-default-config`, emitting false `Lint/Syntax` on Ruby 3.1+ syntax
   (`docs/dogfooding/2026-07-07-round-0.5.2.md` §3).
   - Why now: pollutes the "Metz-only" default output with wrong-cause noise on
     real production files (194 on redmine); pre-dates #33/#37 (since 0.5.0).
   - Definition of done: default mode carries the target's `TargetRubyVersion`
     (or detects it) so modern syntax parses cleanly; red-green with the
     anonymous-block-forwarding repro; no `Lint/Syntax` false positives.

2. Fix defect C: `Metz/ControllersTooManyDirectCollaborators` counts raise-site
   exception classes and framework helpers (e.g. `Arel`) as collaborators — a
   #34 sibling gap (`docs/dogfooding/2026-07-07-round-0.5.2.md` §4).
   - Why now: misleading counts/messages on idiomatic controllers; same defect
     class as the already-fixed #34.
   - Definition of done: exclude constants at `raise` sites (mirroring the
     existing `rescue`-site exclusion) and add a framework `AllowedReceivers`-style
     allowlist consistent with the sibling `DemeterTrainWreck`; red-green from the
     lobsters `login_controller` and huginn `jobs_controller` cases.

3. Re-run exit criterion 2 on the fixed HEAD, folding in the findings-quality
   notes as candidates (per-cop offense rollup / grand-total line in text
   output, a legacy-adoption/baseline path, clearer generic branch-subject
   wording, `RootKind` `*Component` allowlist). Then the single release
   candidate carries #37 + fixes A/B/C.
   - Definition of done: same rubric, no new headline-UX-class defects.
   - Not in scope: promoting candidate analyzers or changing thresholds.

4. Verify the README quickstart end-to-end against a clean install.
   - Why now: rubygems.org exit criterion 3; the quickstart is the first
     impression a public release trades on.
   - Definition of done: follow the README from a clean environment (fresh
     gem install through first scan) exactly as written; fix any step that
     does not work or under-explains.
   - Files likely touched: README, possibly install tooling.
   - Not in scope: restructuring the README beyond what the walkthrough
     demands.

5. Run the rubygems.org release preflight.
   - Why now: final exit criterion once 1-5 are done; both gem names were
     unclaimed as of 2026-07-05 and name availability should not be assumed
     indefinitely.
   - Definition of done: gem metadata (changelog, license, description,
     homepage, links) reads correctly on `gem build` inspection for both gems,
     and a go/no-go decision is recorded against the Path to rubygems.org
     criteria.
   - Files likely touched: gemspecs, `CHANGELOG`, README.
   - Not in scope: the publish itself, which is an explicit user decision.

## Latest Slice Checkpoint

Slice: 2026-07-08 dogfood defects A/B — default scan crash + load-error text.

What changed: default mode now resolves target file scope through a
wrapper-local scope-only RuboCop config loader instead of plain
`RuboCop::ConfigStore`, so `.rubocop.yml` entries under `plugins:`,
`require:`, and absent `inherit_gem:` no longer crash Metz-only scans. Local
`AllCops: Exclude` and `Metz/*: Exclude` still apply. Error handling now labels
only the wrapper's own missing `rubocop-metz` load as `could not load
rubocop-metz`; missing target extensions report as target RuboCop load errors,
and extensionless `bin/metz-scan` stack frames are stripped.

Decision: chose option 1 (honor scope without loading plugin gems), not the
warn-and-scan fallback. RuboCop 1.88.0 has no supported public API for this
scope-only path, so the internal-API exception is recorded in
`docs/ddrs/2026-07-08-rubocop-scope-only-config.md` and summarized in
`implementation-notes.md`.

Verification in progress for the slice: red-green focused tests are green
(`scan_test.rb`, `scan_error_test.rb`), touched-file RuboCop is clean, and the
full required gauntlet is `bundle exec rake`, `bundle exec rubocop`, and
`bin/check_dogfood` with the Rubydex group installed. No commit, push, tag, or
release from this executor; the orchestrating session owns git actions.

Prior slices: 2026-07-07 dogfooding round on HEAD 0.5.2 (criterion 2 not
passed, defects A/B/C/D recorded); `a06b28c` (prepare 0.5.2 release target —
the version bump the next release will carry once the dogfood fixes land);
`d9f92e4` (testing-cops spec revision); `847c478` (#37).

## Parked / Not Next

- Fixture/coverage sweeps are parked as a class per the 2026-07-05 direction
  review (this retired the former queue tasks 3-10: drift-command help and
  empty-result fixtures, calibration JSON fixtures, drift read-only guard
  coverage, project-analyzers JSON/help fixtures, scan project-analyzer text
  fixtures, and calibration help fixtures). Reopen an individual item only
  when a defect shows that exact missing fixture would have caught it.
- Package/release feedback watch is back to trigger-gated: the ctxpack
  dogfooding findings #31/#32 are fixed, released in `v0.5.0`, and closed
  with release links.
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
- Testing-discipline cops (`Metz/Test*`) are **spec'd and roadmapped, not
  parked-forever**: `docs/design/testing-cops.md` is the specification. This is
  a deliberate direction addition — a Metz-branded linter should encode Sandi's
  testing rules, not only her design rules. Implementation is deferred to
  **after the first public release** (to keep the v1 surface stable) and then
  proceeds slice-by-slice (Tier 1 as cops, Tier 2 as wrapper-side project
  analyzers per the spec's architecture decision), each earning default output
  only through per-cop dogfooding. Do not start implementing before release;
  do not attempt the documented non-goals (undetectable message-origin rules).

## Recently Completed

| Date | Commit | Summary |
| --- | --- | --- |
| 2026-07-08 | `this commit` | Fixed dogfood defects A/B: default mode now honors local target file scope without loading absent target RuboCop extensions (`plugins:`, `require:`, `inherit_gem:`), so external-gem configs no longer crash Metz-only scans; load-error text now distinguishes missing target extensions from missing `rubocop-metz` and strips extensionless `bin/metz-scan` stack frames. Added red-green default-scope and subprocess error tests, documented the RuboCop scope-only internal-API decision in a DDR/notes, and revised README/skill/release notes. No git actions taken by this executor. |
| 2026-07-07 | `this commit` | Reran exit criterion 2 (dogfooding) on HEAD 0.5.2 across five real codebases — **NOT PASSED**, four headline-UX defects (`docs/dogfooding/2026-07-07-round-0.5.2.md`): default-mode crash + misattributed error (regression from #33/#37, in `v0.5.1`), `TargetRubyVersion` loss → false `Lint/Syntax`, and `ControllersTooManyDirectCollaborators` over-count (#34 sibling). Reframed the release strategy to fix → re-dogfood → single release and rebuilt the queue around the fixes. Round doc + tracker only; no code change. |
| 2026-07-07 | `a06b28c` | Prepared the `0.5.2` release target carrying #37: bumped both gems 0.5.1 → 0.5.2, regenerated the lockfile pin (`~> 0.5.2`), moved release-issue dry-run expectations, and added `docs/releases/v0.5.2.md`. Patch bump, precedent-consistent with `0.5.1`. (The subsequent dogfooding round found 0.5.2 must not ship as-is; the bump now sits on `main` as the eventual carrier for #37 + the fixes.) |
| 2026-07-07 | `d9f92e4` | Revised the testing-cops spec after review: Tier 2 re-homed from cops to wrapper-side project analyzers (dependency-direction conflict), prior-art section added (rubocop-rspec / rubocop-minitest overlap and reusable heuristics), `TestAssertsOnInternals` narrowed to `instance_variable_get/_set` + `assigns` (bare-`@ivar` clause was a FP flood), and the design-cops-fire-on-tests claim corrected for `DemeterTrainWreck`'s `spec/**/*` exclude. Spec only; no cop code. |
| 2026-07-07 | `fb6156b` | Specced the testing-discipline cop family (`docs/design/testing-cops.md`): a deliberate direction addition so a Metz-branded linter encodes Sandi's testing rules, not only her design rules. Detectability-first catalog (AST-only Tier 1 + Rubydex-index Tier 2), both frameworks, explicit non-goals, calibration/dogfooding plan, and post-release cop-by-cop rollout. Spec only; no cop code. |
| 2026-07-07 | `847c478` | Fixed #37: default (Metz-only) scans now honor the project's per-cop `Exclude` (file scope) like #33 honors `AllCops: Exclude`, while still forcing Metz tuning; extracted `ProjectCopScope`, removed an inert `DemeterTrainWreck` test exclude, documented the scope-vs-tuning contract, and resolved `bin/check_dogfood` red on `main` (former Next Queue task 3) with red-green tests. |
| 2026-07-06 | `a4eb569` | Made the agent workspace dual-agent: canonical `CLAUDE.md` brief, four maintainer skills under `.claude/skills/`, `.agents/skills` symlink for Codex discovery, `AGENTS.md` router, operator playbook, goal backlog, and a routing freshness test. |
| 2026-07-06 | `554b89b` | Recorded `v0.5.1` release completion: tag at `3ec8f29`, GitHub Release, GitHub Packages publish for both gems, `bin/check_published_gem 0.5.1` PASS, and #33/#34 release-link comments. |
| 2026-07-06 | `3ec8f29` | Prepared the `0.5.1` release target carrying the #33/#34 fixes: bumped both gem versions and the lockfile, moved release-issue expectations to `0.5.1`, and drafted `docs/releases/v0.5.1.md`. |
| 2026-07-06 | `16824db` | Fixed #34: the collaborators cop no longer counts rescue classes, own constants, or core stdlib names, and no longer labels every method "Action"; regression tests per dogfooding spot check. |
| 2026-07-06 | `d041d51` | Fixed #33 (default scan honors project `AllCops: Exclude` while forcing Metz defaults) with regression tests, and filed #34 for the collaborators-cop miscounting. |
| 2026-07-05 | `5179431` | Ran the first qualitative dogfooding round on released `0.5.0` across five codebases; filed #33, drafted the collaborators-cop issue, recorded rubric notes, and rebuilt the queue around the two headline-UX defects. |
| 2026-07-05 | `46cc9b5` | Recorded `v0.5.0` release completion: tag, GitHub Release, GitHub Packages publish for both gems, post-publish smoke, and #31/#32 release links. |
| 2026-07-05 | `fb41288` | Prepared the `0.5.0` release target: version surfaces, lockfile, README install example, release issue expectations, and `docs/releases/v0.5.0.md`. |
| 2026-07-05 | `82bb331` | Fixed #31 (scan defaults to Metz/* cops with `--all-cops` opt-in) and #32 (default config disables shadowed Metrics cops), with README/help docs, test coverage, and tracker updates. |
| 2026-07-05 | `574afb7` | Set the quality-gated rubygems.org direction: four exit criteria, outward-facing queue, coverage sweeps parked as a class, process-overhead standing rules. |
| 2026-07-05 | `599a935` | Added Codex-delegated queue tasks 1-4: exact render-summary help fixture, tracker-fixture decoupling for #25 exact output, default `$HOME/.gem/credentials` smoke coverage, parity `next action:` failure coverage, plus #31/#32 triage and tracker updates. |
| 2026-07-05 | `3fb5747` | Added `--print-baseline` read-only guard coverage, baseline help examples, target/analyzer baseline mismatch tests, exact `metz-scan project-analyzers` text fixture coverage, and tracker updates. |
| 2026-07-05 | `b5f053f` | Added ProjectIndex missing-Rubydex subprocess coverage, deterministic Rubydex drift formatter fixtures, sample-app JSON drift fixture coverage, exact `--print-baseline` YAML fixture coverage, and tracker updates. |
| 2026-07-05 | `8f65252` | Added the in-repo `metz-scan` consumer agent skill, README discoverability, skill metadata, freshness coverage, and tracker updates. |
| 2026-07-05 | `a5df146` | Added exact issue-comment summary fixtures, `GEM_CREDENTIALS` smoke coverage, parity failure inspection docs, issue-summary help/docs, and tracker updates. |
| 2026-07-05 | `86733e0` | Added baseline-delta Markdown fixtures, analyzer-filter baseline guidance, aggregate project-analyzer text fixtures, `--print-baseline`, and tracker updates. |
| 2026-07-05 | `bf7a113` | Fixed LEAK-1 by exposing the read-only default command list through a stable command mode and moving docs freshness coverage off source parsing. |
| 2026-07-05 | `fd8a515` | Added README analyzer-status freshness coverage, Rubydex drift missing-backend and exact text fixture coverage, read-only maintenance docs, release guard checklist coverage, and tracker updates. |
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
- Dogfooding round notes: `docs/dogfooding/2026-07-07-round-0.5.2.md` (latest,
  criterion 2 NOT passed), `docs/dogfooding/2026-07-05-round-0.5.0.md`.
- Archived chronological implementation details:
  `docs/archive/implementation-notes-2026-06-29-through-2026-07-03.md`.
- Project analyzer calibration record: `docs/project-analyzer-calibration.md`.
- Tracked calibration target manifest: `docs/calibration/project_analyzer_targets.yml`.
- Tracked calibration baseline: `docs/calibration/project_analyzer_baseline.yml`.
- Published `v0.5.0` release notes: `docs/releases/v0.5.0.md`.
- Published `v0.4.0` release notes: `docs/releases/v0.4.0.md`.
- Sorbet adoption spike: `docs/spikes/sorbet-issue-26.md`.
- Candidate analyzer summary: `docs/sandi-metz-project-analyzer-candidates.md`.
- Testing-discipline cop design spec: `docs/design/testing-cops.md`.
- Release process: `RELEASE_CHECKLIST.md`.
- Local ignored strategy scratchpad: `logs/repeated-query-criteria-strategy-review.md`.
