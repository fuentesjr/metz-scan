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
- Latest pushed baseline: `1397a2c Bump rubocop 1.88.2, rubocop-ast 1.50.0,
  rubydex 0.2.8`. Post-`v0.5.3` slices on `main`: `2edc63a` (check_ci_parity
  speedup) and `1397a2c` (dependency bumps); `9b1c0fd` is the tagged `v0.5.3`
  release commit.
- CI state: the most recent `main` CI-workflow runs, including `1397a2c`,
  `2edc63a`, and `9b1c0fd`, all succeeded.
- Release state: **`v0.5.3` is published and verified on both rubygems.org and
  GitHub Packages** (tag `v0.5.3` → `9b1c0fd`, GitHub Release, both gems live,
  `rubocop-metz` before `metz-scan`). Verified end-to-end: a clean
  `bundle exec metz-scan scan` from rubygems.org runs a real scan with the
  `Summary` scorecard (not just `--version`), and `bin/check_published_gem 0.5.3`
  PASS on GitHub Packages. `gem install metz-scan` now works from rubygems.org.
  `0.5.3` fixes the corrupt rubygems.org `0.5.2` push (a `rubocop-metz` built
  from the wrong CWD packaged the wrapper's files); the gemspecs now raise a
  loud, self-explaining error on a wrong-directory build instead of shipping a
  corrupt gem, and gemspec eval stays clean under Bundler/Dependabot. The corrupt
  `0.5.2` has been **yanked** from rubygems.org (the versions API now lists only
  `0.5.3` for both gems); GitHub Packages `0.5.2` is fine and stays. The release
  is fully complete. All carried issues (#33/#34/#37) closed.
- Local branch state: `main` HEAD is `1397a2c`; the tagged `v0.5.3` commit is
  `9b1c0fd`. Tree clean, in sync with `origin/main`. The `v0.5.2` tag/GitHub
  Release stay as historical.
- Dogfooding state: **exit criterion 2 PASSED on 2026-07-08** on the re-verify
  round (`docs/dogfooding/2026-07-08-round-0.5.2-reverify.md`). The 2026-07-07
  round (`docs/dogfooding/2026-07-07-round-0.5.2.md`) found four headline-UX
  defects; all four are fixed and pushed — A/B (`8b246ba`), C (`4b64a93`), D
  (`cd6f18c`) — and re-verified across all five codebases with no new headline
  defect. One accepted known limitation (absent-`inherit_gem` excludes silently
  dropped; documented trade-off, zero observed effect on the five targets) has a
  queued loud-warning follow-up, not a blocker.
- Latest checkpoint window: 2026-07-08: fixed all four round-2 defects (`8b246ba`,
  `4b64a93`, `cd6f18c`), re-ran exit criterion 2 (PASSED), added the inherit_gem
  warning (`d57d2e7`), and completed criteria 3-4 (quickstart verified vs a clean
  candidate install; preflight — metadata reads correctly, links/LICENSE added).
  **All four exit criteria met; go/no-go: GO.**
- Pre-publish competitive gate (2026-07-08, user-added): **CLOSED** — the
  compliance scorecard and the README "How metz-scan compares" section shipped in
  `v0.5.2`, covering `sandi_meter`'s one edge (a compliance-% scorecard) on top of
  metz-scan's existing wins (coverage, modern-Ruby accuracy, project analyzers,
  SARIF/CI, integration, active maintenance).
- Working tree expectation: keep tracked work clean before starting another
  slice; keep ignored `logs/` notes out of commits unless explicitly requested.

## Active Workstreams

| Workstream | Status | Current State | Next Move |
| --- | --- | --- | --- |
| Release readiness | v0.5.3 released; complete | `v0.5.3` published and verified on rubygems.org and GitHub Packages (tag `v0.5.3` → `9b1c0fd`, GitHub Release, rubocop-metz before metz-scan; real-scan verified from rubygems.org, `check_published_gem 0.5.3` PASS). Fixed the corrupt `0.5.2` rubygems push, gemspecs guard against wrong-directory builds, and the corrupt `0.5.2` is yanked. | Done. Next release only when there's shippable work (e.g. testing-cops). |
| Calibration artifact pipeline | Healthy | Markdown output, artifact write path, sample-app calibration smoke, the tracked target manifest under `docs/calibration/`, baseline-delta Markdown fixtures, compact baseline preview structure, exact `--print-baseline` YAML output, baseline scope mismatch checks, and help examples for scope-matched baseline workflows are covered. | Maintain; change only when artifact, target-manifest, or baseline-document behavior changes. |
| Analyzer behavior | Parked | Fresh #27/#28 Mastodon and Discourse reruns did not show enough misleading or underexplained findings to justify behavior, threshold, or output-policy changes. | Reopen only with new generic evidence, not app-specific suppressions. |
| Calibration evidence | Guarded | Redmine, Rubygems.org, ManageIQ, and Foreman evidence has been consolidated; Rubydex `0.2.8` was rechecked (`check_dogfood` PASS / 0 findings and `bin/check_rubydex_drift` on sample_app unchanged at 1 DeepInheritanceTree finding — no drift from the 0.2.7→0.2.8 bump). Full active-manifest output is 697 findings/806 offenses; the four Rubydex-index-backed analyzers account for 607 findings/607 offenses. A compact Rubydex drift check covers those four analyzers, now with ProjectIndex missing-Rubydex subprocess coverage, missing-Rubydex skip-path coverage, exact sample-app text/JSON fixtures, and deterministic non-Rubydex formatter fixtures; `docs/calibration/project_analyzer_baseline.yml` captures the full active-manifest baseline for delta reporting. | Recheck only Rubydex-index-backed analyzers after future Rubydex upgrades unless an AST-only analyzer changes; use `--baseline-file docs/calibration/project_analyzer_baseline.yml` for full-manifest drift. |
| Workflow friction | Guarded | The lockfile rewrite came from a stale path dependency entry in `Gemfile.lock`; the lockfile now matches the gemspec's `rubocop-metz (~> 0.4.0)` constraint, read-only maintenance commands have a tracked-worktree mutation guard plus a public command-listing mode, `--print-baseline` is in the default read-only guard list, the read-only command contract is documented in contributor/calibration/release docs, and `bin/check_ci_parity` runs tracker hygiene before Bundler work while preserving failed clean clones and printing `next action:` commands for inspection. Parity now runs a deliberate CI subset (docs-freshness tests for docs-only commits, `rake test:fast` for code commits) instead of the full suite on every commit; `CI_PARITY_FULL=1` forces the full local suite, and remote CI stays the full-suite backstop either way. | Maintain the guard list and docs as new read-only commands are added; do not bypass `BUNDLE_FROZEN=1` for read-only calibration checks; use `CI_PARITY_FULL=1` before release prep. |
| Sorbet adoption spike | Complete | Issue #26 was evaluated in a disposable workspace, documented, synced back to GitHub, and closed. The report recommends not adopting now: a narrow static setup is possible, but generated RBI churn, command policy, fixture scope, and runtime signature implications outweigh observed value. | Do not add Sorbet unless a concrete type-related defect, contributor ergonomics need, or stable public API typing requirement appears. |
| Docs/adoption | Stable | README points contributors and agents to this tracker; old implementation notes are archived, current notes are short, and the Sorbet spike report records the tooling decision. The README now splits RepeatedBranching generic-subject guidance into a short list, the analyzer behavior details into per-analyzer subsections, package install troubleshooting points at `bin/check_published_gem`, parity failure inspection points at preserved clone/`next action:` output, the analyzer status table has freshness coverage, `skills/metz-scan/SKILL.md` gives agents consumer-facing usage guidance, and calibration docs point future Rubydex upgrades, filtered baselines, compact baseline previews, and parked issue updates at repeatable local commands. | Keep docs changes minimal and evidence-led. |
| Path to rubygems.org | Live on rubygems.org (v0.5.3) | `metz-scan`/`rubocop-metz` `0.5.3` are the public rubygems.org release, verified with a real scan from a clean install; the corrupt `0.5.2` is yanked (only `0.5.3` installable). | Done. `1.0.0` still reserved for a later, deliberate signal. |
| Test hardening | Done | Fixture/guard surface through `599a935` covers CLI text/JSON/help contracts, read-only guards, drift checks, package smoke, and CI parity output. Suite: 438 fast + 88 slow runs, all green. | Maintain only; new tests accompany behavior changes or defects, not coverage sweeps. |
| Testing-discipline cops | Active | Tier 1 complete: three cops landed opt-in and **all three dogfooded → stay opt-in** (`TestReachesPrivate` ~22/100, `TestAssertsOnInternals` ~32/100, `TestStubsSubject` 0 FP but suite-dependent ~11.9/100 on OpenFoodNetwork — `docs/dogfooding/2026-07-09-test-stubs-subject.md`). **Tier 2 landed 2026-07-09**: `MetzProject/TestCallsPrivateMethod` — wrapper-side index-backed project analyzer (candidate, opt-in), the Rubydex-confirmed form of `Metz/TestReachesPrivate`. SUT-scoped conservative (describe/described_class/`FooTest`→`Foo` unique-match; receivers = `subject`/`described_class.new`/`Const.new`/single-assign ivar; own-declarations-only; method_identity match). Added `visibility` to `ProjectIndex::MethodDeclaration` + an AST `module_function` seam (Rubydex 0.2.8 `#visibility` panics unrescuably on `module_function` — upstream bug, local workaround). Supersession of Tier-1 is documentation-only (dependency direction forbids the cop seeing the index). Codex-implemented, orchestrator-reviewed (verified the panic empirically + e2e smoke). | Dogfood `TestCallsPrivateMethod` on test-heavy RSpec/Minitest suites with Rubydex. Then assess remaining rollout (`TestTooManyAssertions` candidate — likely drop per spec §10). |

## Next Queue

1. Dogfood `MetzProject/TestCallsPrivateMethod` (now landed, candidate/opt-in)
   on test-heavy RSpec + Minitest suites with Rubydex installed, per
   `docs/design/testing-cops.md` §8 — judge-only round, record false-positive
   rate and default-output eligibility (same bar as the other testing analyzers;
   promotion stays escalation-gated). Use the per-cop round method fixes recorded
   in `docs/dogfooding/2026-07-09-test-stubs-subject.md` (scan outside repo `tmp/`,
   pin `TargetRubyVersion`), and include test paths in the scan set (`scan .`).
2. After that, assess the remaining testing-cops rollout
   (`docs/design/testing-cops.md`): `TestTooManyAssertions` is a weak candidate
   (§10 — likely drop; both ecosystems already ship it). Do not start a cop
   before its dogfooding evidence; do not attempt the documented non-goals.

(All three shipped testing cops are calibrated and **stay opt-in** — accurate but
not reliably sparse enough for default output: `Metz/TestReachesPrivate`
(`docs/dogfooding/2026-07-08-test-reaches-private.md`, 21.7/100 on Rails),
`Metz/TestAssertsOnInternals`
(`docs/dogfooding/2026-07-09-test-asserts-on-internals.md`, ~32/100 on Rails),
and `Metz/TestStubsSubject`
(`docs/dogfooding/2026-07-09-test-stubs-subject.md`, RSpec-only: 0 FP but
suite-dependent density, ~11.9/100 on OpenFoodNetwork despite near-zero on three
other suites). `remove_method` remains a minor `AllowedMethods` candidate for
`TestReachesPrivate`, parked.)

## Latest Slice Checkpoint

Slice: 2026-07-11 README scope statement (docs-only, user-requested).

What changed: two-line scope statement added to README's "How metz-scan
compares" — metz-scan measures design pressure only and is not a security or
correctness auditor; pair it with brakeman or a full audit pipeline. Positions
the tool against the reader's likely alternatives (audit stacks), not just
sandi_meter.

How verified: README/docs freshness tests green, `rubocop` clean (242 files),
dependency-direction / sample-frozen / tracker-queue guards pass. No CLI
behavior changed.

Prior committed slice — 2026-07-09 Tier-2 testing analyzer —
`MetzProject/TestCallsPrivateMethod` (wrapper-side, Rubydex-index-backed,
candidate/opt-in).

What changed: new project analyzer flagging tests that call an index-confirmed
private/protected method on the subject-under-test — the Rubydex-confirmed form
of the opt-in Tier-1 cop `Metz/TestReachesPrivate`. SUT-scoped conservative
(near-zero FP by design): infers the SUT from `describe`/`described_class` (RSpec)
or `FooTest`→`Foo` with a required unique index match (Minitest); only flags
sends whose receiver is provably the SUT (`subject` — dropped if redefined to a
non-SUT; `described_class.new`; `Const.new`; a single-assignment ivar/local from
`Const.new`); own-declarations-only visibility, `method_identity` (instance vs
singleton) match, and the confirming declaration must not itself be a test file.
Extended `ProjectIndex::MethodDeclaration` with a `visibility` field. Registered
in `ANALYZERS` + `INDEX_BACKED_ANALYZERS` (auto-enrolled in `check_rubydex_drift`,
0 findings on sample_app). Ships `PROJECT_ANALYZER_STATUS = "candidate"`, no
`DEFAULT_OUTPUT_ELIGIBLE` — promotion escalation-gated. Tier-1 supersession is
documentation-only (dependency direction forbids the cop seeing the index).

Surprise: Rubydex 0.2.8 `#visibility` **panics unrescuably** (SIGABRT,
"module_function visibility translation is not implemented") on `module_function`
methods — and it runs for every method at index build, so it would abort
`check_rubydex_drift` on real targets. Worked around with an AST-based
`module_function` visibility seam (singleton copy → public, instance copy →
private). Upstream Rubydex bug drafted for filing; delete the workaround once
upstream fixes it.

How verified: Codex-implemented (`task-mre3lvsp-lp3np0`, ~50m, after a first
dispatch hit the #432 foreground-reap wedge — cleared, redispatched with
`--background`), then **orchestrator independently reviewed the full diff**
(traced the SUT/receiver/scope resolution and all FP guards), **verified the
Rubydex panic and the workaround empirically**, **re-ran the focused tests**
(analyzer 26/141/0F, index 11/94/0F) and drove a **real end-to-end scan**
(flags a private `subject.send`, ignores public + collaborator sends). Codex
gates: `bundle exec rake` 664/0F/0E (2 skips), `rubocop` clean (242 files),
`check_dogfood` 0 findings (early + final), dependency-direction / sample-frozen
/ rubydex-drift all PASS. Both-paths `missing_rubydex` coverage; fixtures
additive; `readiness_catalog` records "do not promote / dogfood first".

Prior committed slice — 2026-07-09 `Metz/TestStubsSubject` calibration round (judge-only, docs).

What changed: dogfooded the third opt-in cop against **four** real RSpec suites
(Mastodon, Discourse, Forem, OpenFoodNetwork) per `docs/design/testing-cops.md`
§8. Verdict: **accurate (0 false positives, reproduces `RSpec/SubjectStub` —
several offenses carry hand-written `# rubocop:disable RSpec/SubjectStub`) but
stays opt-in** because density is **suite-dependent**: 0.0/0.28/0.33 per 100 spec
files on Discourse/Mastodon/Forem but **~11.9/100 on OpenFoodNetwork** (a legacy
report-heavy suite that stubs the subject-under-test pervasively). The initial
Mastodon+Discourse read (n=3) looked sparse-and-clean — a promotion candidate —
but the two added targets showed the sparse signal does not generalize, so the
cop is not default-output eligible. `Enabled: false` stands, aligning all three
testing cops (accurate, opt-in). Round doc:
`docs/dogfooding/2026-07-09-test-stubs-subject.md`. No code changed.

Two reusable method corrections recorded in the doc: never scan a checkout under
the repo's `tmp/` (RuboCop default `Exclude: tmp/**/*` silently drops all files),
and never use `--force-default-config` for these rounds (it parses at Ruby 2.7,
raising `Lint/Syntax` that silently skips ~12% of files — the defect-C class); pin
`TargetRubyVersion: 3.4` via an explicit config instead.

How verified: offense counts from raw JSON per target (mastodon 3 / discourse 0 /
forem 4 / ofn 76), zero `Lint/Syntax` after the target-ruby fix (full coverage);
offenses spot-checked against source on all four targets — every sampled offense
stubs the object-under-test, collaborators correctly not flagged. Judge-only — no
fixes (dogfood rubric).

Prior committed slice — 2026-07-09 third testing-discipline cop — `Metz/TestStubsSubject`
(Tier 1, RSpec-only, AST), opt-in.

What changed: new cop flagging RSpec tests that stub/mock the subject under test
— `expect`/`allow(subject).to receive*`, `is_expected.to receive*`, and named
subjects (`subject(:x)`) — an inline port of `RSpec/SubjectStub`. Subject names
are folded through ancestor example groups (root→node): `subject`/`subject!` add
names, `let`/`let!` subtract, the set always includes `:subject`; sibling groups
stay isolated and the stub matcher (`receive`/`receive_messages`/
`receive_message_chain`/`have_received`) is found recursively (so
`all(receive(...))` matches). **RSpec-only by design** — Minitest deferred
(only RSpec has a detectable subject token; general Minitest inference floods
FPs). Ships `Enabled: false` with an RSpec-only `Include` (`**/*_spec.rb`);
reuses the slice-1 opt-in gate (no runner/wrapper changes). `TestFrameworks`
deferred again (built inline; no both-framework consumer yet). `on_send` cop →
includes `OnSendCsendBridge`.

How verified: Codex-implemented (`task-mrdnzm3c-ilww8x`, ~25m) with red-green +
its own reviewer; **orchestrator independently reviewed the full diff** (traced
the fold and every FP-guard fixture — collaborator, sibling, `let`/`let!`
override, `described_class`, message-result receiver, non-stub matcher — plus
the tricky positives inherited-named-subject and outer-`let`-then-inner-subject)
and **reran full verification**: `bundle exec rake` 637/0F/0E (2 expected
missing-rubydex skips), `bundle exec rubocop` clean (231 files),
`check_dependency_direction` / `check_sample_app_frozen` / `check_dogfood`
(0 findings) all PASS. 28 cop tests over 24 both-branch fixtures; opt-in gate
extended in `scan_test.rb` (`ScanOptInCopSelectionTest` now proves both
`TestReachesPrivate` and `TestStubsSubject` are hidden by default and surface
under `--all-cops` + project enablement). Note: Codex's sandbox blocked GitHub,
so it built from the brief without the live `RSpec/SubjectStub` oracle — the
orchestrator's diff/fixture trace is the cross-check. Dogfooding of the cop is
the next slice (Next Queue #1). DEP-1 (`23aaf37`) preceded this slice.

Prior committed slice — 2026-07-09 DEP-1 decouple — neutral operator predicate.

What changed: extracted `RuboCop::Cop::Metz::OperatorMethods` (new
`operator_methods.rb`) holding the canonical operator-symbol set + `operator?`
predicate, so `Metz/TestReachesPrivate` no longer requires or calls into
`DemeterTrainWreck::TypeInference`. `TypeInference.operator?` now delegates to
the neutral module (behavior unchanged; `demeter_train_wreck.rb` untouched).
Behavior-preserving refactor; unblocks the `TestStubsSubject` slice from the
Demeter coupling. Also locked the `TestStubsSubject` design: RSpec-only,
`TestFrameworks` deferred again (see Next Queue #1).

How verified: `type_inference_test`, `test_reaches_private_test`, and the new
`operator_methods_test` all green; `rake test:fast` 499/0F/0E (2 expected
missing-rubydex skips); `rubocop` clean on changed files; `check_dogfood`
0 findings; `check_dependency_direction` PASS.

Prior committed slice — 2026-07-09 `Metz/TestAssertsOnInternals` calibration round (judge-only, docs).

What changed: dogfooded the second opt-in cop against the same Rails (Minitest) +
Mastodon/Discourse (RSpec) suites. Verdict: accurate (low FP — `instance_variable_get`/`_set`
are unambiguous internal-state reaches, spot-checked on Rails adapter tests) but
**too dense for default output** — ~32 findings/100 test files on Rails (364
offenses; even denser than `TestReachesPrivate`), Discourse ~3.3, Mastodon ~0.4.
So it **stays opt-in** (`Enabled: false`). No `assigns` offenses (modern suites
use request specs). Round doc:
`docs/dogfooding/2026-07-09-test-asserts-on-internals.md`. No code changed.

How verified: offenses from raw JSON (rails 364 / discourse 53 / mastodon 4);
Rails samples spot-checked against source. Judge-only — no fixes (dogfood rubric).

Prior committed slice — 2026-07-09 second testing-discipline cop — `Metz/TestAssertsOnInternals`
(Tier 1, AST-only), opt-in.

What changed: new cop flagging tests that assert on internal state —
`instance_variable_get`/`_set` on any receiver, and receiverless literal
`assigns(:x)` (Rails controller tests) — in test files, both frameworks. Bare
`@ivar` is not flagged (fixture state). Ships `Enabled: false`; reuses the
slice-1 opt-in gate, so **no runner/wrapper changes**. Escape hatch:
`AllowedReceivers`. `TestFrameworks` deferred again (still not needed — file-glob
+ method-send detection); no `DemeterTrainWreck` coupling; DEP-1 stays queued.

How verified: Codex-implemented (`task-mrcz5vis-1ndds2`; the recorded ~10h49m is
wall-clock across an overnight machine sleep, not work time), independently
reviewed + re-run: `bundle exec rake` 603/0F/0E, `bundle exec rubocop` clean
(227 files), dep-direction / sample-frozen / dogfood (0 findings) PASS. 17
both-framework cop tests.

Prior committed slice — 2026-07-08 `Metz/TestReachesPrivate` calibration round (judge-only, docs).

What changed: dogfooded the opt-in cop against real Minitest + RSpec suites
(Rails, Mastodon, Discourse) for default-output eligibility. Verdict: accurate
(low FP — nearly all offenses are genuine tests-of-private-methods) but **too
dense for default output** (Rails 21.7 findings/100 test files, Discourse 8.8,
Mastodon 4.2), so it **stays opt-in** (`Enabled: false`). Validates the slice-1
ship-opt-in decision. Round doc:
`docs/dogfooding/2026-07-08-test-reaches-private.md`. Non-blocking nit:
`remove_method` is an `AllowedMethods` candidate (parked). No code changed.

How verified: offenses recounted from raw JSON (rails 247 / mastodon 45 /
discourse 140); samples spot-checked against source. Judge-only — no fixes
applied (dogfood rubric).

Prior committed slice — 2026-07-08 first testing-discipline cop —
`Metz/TestReachesPrivate` (Tier 1, AST-only), opt-in.

What changed: new cop in `rubocop-metz` flagging `send`/`__send__` with a bare
symbol/string literal method name inside test files (Include globs
`**/*_test.rb`, `**/test_*.rb`, `**/*_spec.rb`; both Minitest and RSpec).
Escape hatches: `AllowedMethods`
(default define_method/remove_const/include/extend/prepend/alias_method),
`AllowedReceivers`, operator-symbol skip. Ships `Enabled: false`; message is
mechanism-only (AST cannot prove privacy). Established the **reusable opt-in
gate for the whole `Metz/Test*` family**: dropped `--enable-all-cops` from the
default-mode scan argv so `--force-default-config --only Metz` respects the
plugin `default.yml` `Enabled` flag (empirically verified) — `Enabled: false`
now genuinely gates a cop out of default output, and promotion is a later
`Enabled: true` flip. Companion fix: the `scan --fix` path (`auto_fix.rb`
`run_in_place`) pipes stderr to the user, so removing `--enable-all-cops`
re-surfaced RuboCop's pending-cops banner there; added `--disable-pending-cops`
to the fix path only (the scan path swallows stderr into a StringIO).

Deliberate spec deviations (recorded in `docs/design/testing-cops.md`):
`public_send` dropped from detection (it can only call public methods →
guaranteed FP; core `Style/SendWithLiteralMethodName` owns the indirection
angle); the `TestFrameworks` support module deferred (YAGNI — this cop is
file-scoped and framework-agnostic; the module lands with the first cop that
needs test-case-boundary detection). Known follow-up **DEP-1**: the cop reaches
into `DemeterTrainWreck::TypeInference.operator?` (a testing cop coupled to a
Demeter-specific module, and this is the template) — accepted as low-risk for
this slice, decouple folded into the next testing-cops slice.

How verified: Codex-implemented (`task-mrcs1x1q-mzdk93`, ~20m) with its own
red-green + reviewer; orchestrator independently reviewed the full diff and
reran verification — `bundle exec rake` 586/0F/0E, `bundle exec rubocop` clean
(225 files), `check_dependency_direction` / `check_sample_app_frozen` /
`check_dogfood` (0 findings) all PASS. New both-framework cop tests (14 runs) +
a wrapper gate test (`ScanOptInCopSelectionTest`) proving default mode hides the
cop while `--all-cops` + project enablement surfaces it.

Prior committed slice — 2026-07-08 dependency bumps — rubocop 1.88.2, rubocop-ast 1.50.0,
rubydex 0.2.8 (supersedes Dependabot PRs) + GitHub housekeeping.

What changed: `bundle update rubocop rubocop-ast rubydex` bumped rubocop
1.88.0→1.88.2, rubocop-ast 1.49.1→1.50.0, and rubydex 0.2.7→0.2.8 (Gemfile pin
`~> 0.2.8`), plus transitive json/language_server-protocol. The rubocop bump
added two `Style/ArrayIntersect` offenses (`.any? { include? }` → `.intersect?`
in `package_map.rb` and `project_analyzer_runner.rb`), autocorrected —
equivalent, and `Array#intersect?` is Ruby 3.1+ (repo requires 3.3). This
supersedes the conflicting Dependabot PRs #35 (rubocop-ast) and #36 (rubocop),
which auto-close once the versions land on `main`. GitHub housekeeping: open
issues #27/#28 (parked, no new evidence) and #25 (dogfood-CI, trigger-gated) are
accurately captured already and need no update.

How verified: `bundle exec rubocop` clean (223 files, 0 offenses) after the
autocorrect; rubydex 0.2.8 rechecked — `bin/check_dogfood` PASS (0 findings) and
`bin/check_rubydex_drift` on sample_app unchanged (1 DeepInheritanceTree
finding) → no analyzer drift from the bump; parity (code mode → `rake test:fast`)
green before push.

Prior committed slice — 2026-07-08 `check_ci_parity` speedup (`2edc63a`): parity
now scales its tests step to the commits being pushed (docs-freshness for
docs-only, `rake test:fast` for code, `CI_PARITY_FULL=1` for the full suite),
making it a deliberate CI subset with remote CI as the full backstop.

Prior committed slice — 2026-07-08 v0.5.3 release — fix and republish the
corrupt rubygems.org `0.5.2`.

What changed: `v0.5.3` is published and verified on **rubygems.org and GitHub
Packages** (tag `v0.5.3` → `9b1c0fd`, GitHub Release, `rubocop-metz` before
`metz-scan`). Root cause of the `0.5.2` incident: `rubocop-metz` was built with
`gem build rubocop-metz/rubocop-metz.gemspec` from the repo root, so the
gemspec's CWD-relative `Dir.glob` packaged the wrapper's `lib/metz_scan` files
and `require "rubocop-metz"` failed for consumers; rubygems.org can't overwrite
a version, so we republished as `0.5.3`. The first hardening attempt
(`File.expand_path(__dir__)` + a side-effecting `Dir.chdir` in the gemspec) was
fragile — `__dir__` resolves differently when a gemspec is eval'd by
Bundler/Dependabot, so it crashed gemspec evaluation; the CI test workflow was
green but the Dependabot job went red, which caught it. Replaced with a
side-effect-free guard (`9b1c0fd`): keep the CWD-relative `Dir.glob` and raise a
clear "build from the gem's own directory" error if the entrypoint
(`lib/rubocop-metz.rb` / `lib/metz_scan.rb`) is missing from the packaged files
— turning a wrong-directory build into a loud failure while leaving gemspec eval
clean everywhere. This time each gem was built with the correct command and its
contents were verified before every push (rubocop-metz carries its cops, zero
`metz_scan` leak). Verified end-to-end: a clean `bundle exec metz-scan scan`
from rubygems.org runs a real scan with the `Summary` scorecard, and
`bin/check_published_gem 0.5.3` PASS on GitHub Packages. Delegation: the
version-bump/hardening prep was sonnet-delegated; the orchestrator caught the
Dependabot regression, replaced the fragile fix with the guard, and ran every
irreversible build/publish/verify step directly. The corrupt `0.5.2` was then
yanked from rubygems.org (once the maintainer added the `yank_rubygem` scope);
only `0.5.3` is installable. The release is fully complete.

Prior committed slice — 2026-07-08 v0.5.2 GitHub Packages release (`ebd5a4e`):
published `v0.5.2` to GitHub Packages (that build was correct); its rubygems.org
push was the corrupt one, now superseded by `0.5.3`.

Prior committed slice — 2026-07-08 README rubygems polish (`7b06793`, the tagged
release commit): Install now leads with `gem install metz-scan`, a real `scan`
hero example ends in the compliance scorecard, and ~135 lines of per-analyzer
calibration internals moved to `docs/project-analyzer-calibration.md`.

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
  Rollout started 2026-07-08 with `Metz/TestReachesPrivate` (opt-in).
- `test-prof` (github.com/test-prof/test-prof) evaluated 2026-07-08, **not
  adopted**: no ActiveRecord/FactoryBot/Rails/DB, so its headline features
  (`let_it_be`/`before_all`/FactoryProf) don't apply; the suite's slow tests are
  subprocess-bound (they spawn RuboCop), which test-prof can't speed up; adding
  it cuts against the 2026-07-05 "test-hardening done / inward-drift" direction.
  Reopen only if a demonstrated test-perf problem appears that its
  Minitest-applicable profilers (EventProf/StackProf/sampling) would address.

## Recently Completed

| Date | Commit | Summary |
| --- | --- | --- |
| 2026-07-11 | `this commit` | Docs-only: README scope statement in "How metz-scan compares" — metz-scan measures design pressure only, not a security/correctness auditor (pair with brakeman or a full audit pipeline). Freshness tests, rubocop, and repo guards green; no CLI behavior changed. |
| 2026-07-09 | `this commit` | Tier-2 testing analyzer: `MetzProject/TestCallsPrivateMethod` (wrapper-side, Rubydex-index-backed, candidate/opt-in). Flags tests calling an index-confirmed private/protected SUT method — the confirmed form of `Metz/TestReachesPrivate`. SUT-scoped conservative (describe/described_class/`FooTest`→`Foo` unique-match; SUT-only receivers; own-declarations-only; method_identity match). Added `visibility` to `ProjectIndex::MethodDeclaration` + an AST `module_function` seam (Rubydex `#visibility` panics unrescuably on `module_function` — upstream bug, local workaround verified). Registered in `INDEX_BACKED_ANALYZERS` (drift-covered, 0 sample_app findings). Codex-implemented (redispatched past a #432 wedge), orchestrator-reviewed + panic-verified empirically + e2e smoke. rake 664/0F, rubocop clean, dogfood 0 findings. Both-paths missing_rubydex; docs/spec/notes updated. |
| 2026-07-09 | `this commit` | Per-cop calibration round for `Metz/TestStubsSubject` (`docs/dogfooding/2026-07-09-test-stubs-subject.md`). Dogfooded against **four** RSpec suites (Mastodon, Discourse, Forem, OpenFoodNetwork): accurate (0 FP, reproduces `RSpec/SubjectStub`) but **stays opt-in** — density is suite-dependent (0.0–0.33/100 on three suites, **~11.9/100 on OpenFoodNetwork**), so not reliably sparse for default output. The initial n=3 (Mastodon+Discourse) sparse read did not generalize; a 4th target flipped the verdict. Judge-only; docs + tracker, no code. Also records two reusable round-method fixes (avoid repo `tmp/`; pin `TargetRubyVersion`, not `--force-default-config`). |
| 2026-07-09 | `this commit` | Third testing-discipline cop: `Metz/TestStubsSubject` (Tier 1, **RSpec-only**, AST), opt-in (`Enabled: false`). Flags RSpec tests that stub/mock the subject under test (`expect`/`allow(subject).to receive*`, `is_expected`, named subjects) — an inline port of `RSpec/SubjectStub` with an ancestor-group subject-name fold (`subject`/`subject!` add, `let`/`let!` subtract, always include `:subject`, siblings isolated, recursive stub-matcher search). Minitest deferred (no detectable subject token); `TestFrameworks` deferred again. RSpec-only `Include`; reuses the slice-1 opt-in gate. Codex-implemented, orchestrator-reviewed (traced fold + all FP-guard fixtures) and re-verified: rake 637/0F/0E, rubocop clean, dogfood 0 findings. 28 cop tests / 24 fixtures; opt-in gate coverage extended. |
| 2026-07-09 | `23aaf37` | DEP-1 decouple: extracted neutral `RuboCop::Cop::Metz::OperatorMethods` (operator-symbol set + `operator?`) so `Metz/TestReachesPrivate` no longer reaches into `DemeterTrainWreck::TypeInference`; `TypeInference.operator?` delegates to it (behavior unchanged). Also locked `TestStubsSubject` as RSpec-only with `TestFrameworks` deferred again. Behavior-preserving; new `operator_methods_test`, existing tests green, dogfood 0 findings. |
| 2026-07-09 | `this commit` | Per-cop calibration round for `Metz/TestAssertsOnInternals` (`docs/dogfooding/2026-07-09-test-asserts-on-internals.md`). Dogfooded against Rails (Minitest), Mastodon + Discourse (RSpec): accurate (low FP — `instance_variable_get`/`_set` are unambiguous internal-state reaches) but too dense for default output (~32 findings/100 test files on Rails, 364 offenses; Discourse ~3.3, Mastodon ~0.4) → **stays opt-in**. No `assigns` offenses in modern suites. Judge-only; docs + tracker, no code. |
| 2026-07-09 | `this commit` | Second testing-discipline cop: `Metz/TestAssertsOnInternals` (Tier 1, AST-only), opt-in (`Enabled: false`). Flags `instance_variable_get`/`_set` and receiverless literal `assigns(:x)` in test files (Minitest + RSpec); bare `@ivar` not flagged. Reuses the slice-1 opt-in gate (no runner changes). `TestFrameworks` deferred again; no DemeterTrainWreck coupling. Codex-implemented, orchestrator-reviewed; rake 603/0F/0E, rubocop clean, dogfood 0 findings. 17 both-framework cop tests. |
| 2026-07-08 | `this commit` | Per-cop calibration round for `Metz/TestReachesPrivate` (`docs/dogfooding/2026-07-08-test-reaches-private.md`). Dogfooded the opt-in cop against Rails (Minitest), Mastodon + Discourse (RSpec): accurate (low FP — ~all offenses are genuine tests-of-private-methods) but too dense for default output (Rails 21.7 findings/100 test files, Discourse 8.8, Mastodon 4.2) → **stays opt-in**, validating the slice-1 ship-opt-in decision. `remove_method` noted as a minor AllowedMethods candidate (parked). Judge-only; docs + tracker, no code. |
| 2026-07-08 | `this commit` | First testing-discipline cop: `Metz/TestReachesPrivate` (Tier 1, AST-only), opt-in (`Enabled: false`). Flags `send`/`__send__` + literal method name in test files (Minitest + RSpec). Established the reusable opt-in gate — dropped `--enable-all-cops` from default-mode argv so `Enabled: false` gates a cop out of default output (+ `--disable-pending-cops` on `scan --fix` to suppress the now-surfaced pending-cops banner). Deliberate spec deviations: `public_send` dropped (can't reach privates); `TestFrameworks` module deferred (YAGNI). Follow-up DEP-1 (decouple from `DemeterTrainWreck::TypeInference`) tracked. Codex-implemented, orchestrator-reviewed; rake 586/0F/0E, rubocop clean, dogfood 0 findings. Also records test-prof as evaluated-not-adopted. |
| 2026-07-08 | `this commit` | Made `bin/check_ci_parity` fast: a mode resolved from `git diff --name-only @{upstream} HEAD` runs docs-freshness tests for docs-only commits, `rake test:fast` for code commits, and falls back to the full `bundle exec rake` whenever the range can't be determined or `CI_PARITY_FULL` is set. Parity is now a deliberate subset of CI, not a mirror; remote CI stays the full-suite backstop. New end-to-end fixture test proves docs-only detection; existing tests (no-upstream fallback) stay green. Docs updated: `RELEASE_CHECKLIST.md`/issue template run parity with `CI_PARITY_FULL=1`, `CLAUDE.md` and the `land-slice`/`release` skills describe the subset behavior. |
| 2026-07-08 | `this commit` | Bumped `rubocop` 1.88.0→1.88.2, `rubocop-ast` 1.49.1→1.50.0, `rubydex` 0.2.7→0.2.8 (`bundle update`; Gemfile pin `~> 0.2.8`), superseding conflicting Dependabot PRs #35/#36. Autocorrected two new `Style/ArrayIntersect` offenses to `.intersect?`. Rubydex rechecked: `check_dogfood` PASS + `check_rubydex_drift` unchanged (no drift). Open issues #27/#28/#25 assessed — accurately captured, no update needed. |
| 2026-07-08 | `2edc63a` | Made `bin/check_ci_parity` fast: the tests step now scales to the commits being pushed — docs-freshness for docs-only commits, `rake test:fast` for code commits, `CI_PARITY_FULL=1` forces the full suite. Fail-safe (unknown→code; undeterminable range→full). Parity is now a deliberate CI subset with remote CI as the full backstop. Added an end-to-end docs-only mode test; updated CLAUDE.md/RELEASE_CHECKLIST/skills/issue-template. |
| 2026-07-08 | `4e0401f` | Yanked the corrupt `rubocop-metz`/`metz-scan` `0.5.2` from rubygems.org (maintainer added the `yank_rubygem` scope); the versions API now lists only `0.5.3`. Marks the `v0.5.3` release fully complete. Tracker/memory only. |
| 2026-07-08 | `b42be0c` | **`v0.5.3` released to rubygems.org + GitHub Packages** (completion record). Tag `v0.5.3` → `9b1c0fd`, GitHub Release, both gems in dependency order, each built with the correct command and content-verified before push. Verified: clean `bundle exec metz-scan scan` from rubygems.org runs a real scan with the `Summary` scorecard; `check_published_gem 0.5.3` PASS on GitHub Packages. Fixed the corrupt rubygems.org `0.5.2`. No product code. |
| 2026-07-08 | `9b1c0fd` | Replaced the fragile v0.5.3 gemspec fix (a side-effecting `Dir.chdir` that crashed gemspec eval under Bundler/Dependabot — CI green but the Dependabot job red) with a side-effect-free guard: keep the CWD-relative `Dir.glob` and raise a clear "build from the gem's own directory" error if `lib/rubocop-metz.rb`/`lib/metz_scan.rb` is missing from the packaged files. Prevents wrong-directory build corruption while leaving gemspec eval clean everywhere. |
| 2026-07-08 | `c9fa339` | `v0.5.3` prep: version bump 0.5.2 → 0.5.3 (both `version.rb`, lockfile, release-issue test expectations, README install pins), `docs/releases/v0.5.3.md`, and a first (later replaced) gemspec-hardening attempt. Cut to republish the corrupt rubygems.org `rubocop-metz 0.5.2`. |
| 2026-07-08 | `ebd5a4e` | **`v0.5.2` released to GitHub Packages.** Annotated tag `v0.5.2` → `7b06793`, GitHub Release, both gems published in order (`rubocop-metz` then `metz-scan`); `bin/check_published_gem 0.5.2` PASS with live `Summary` scorecard + absent-external-gem crash-fix spot-checks. Publish autobots-delegated (sonnet, SHA-pinned); orchestrator independently verified tag/release/package versions. rubygems.org publish still pending maintainer auth. Phase-4 completion record; no product code. |
| 2026-07-08 | `7b06793` | README rubygems first-impression polish (docs only): Install now leads with `gem install metz-scan` (GitHub Packages auth flow demoted to its own section near Requirements; maintainer commands moved to Contributing); a real `scan` hero example ending in the compliance `Summary` scorecard leads the README; ~135 lines of per-analyzer calibration internals moved from Usage to a new "Analyzer behavior reference" section in `docs/project-analyzer-calibration.md` (status table + summary + link kept); JSON `summary` scorecard fields surfaced in Usage. Docs-freshness 18/0F. |
| 2026-07-08 | `0339bfb` | Closed the `sandi_meter` pre-publish gate. Added the compliance scorecard: `scan`/`report` text output ends with Metz compliance, total offenses across cops, per-cop counts, and top offending files; JSON summaries add `clean_file_count`, `files_with_offenses`, and `offenses_by_cop`. Added a README "How metz-scan compares" section crediting `sandi_meter` as prior art. Red-green command tests, exact scorecard fixtures, README/skill docs, tracker updates. Scorecard Codex-delegated and recovered from a mid-verification worker reap (verified on disk, stale record cleared). |
| 2026-07-08 | `f801b94` | Session handoff: recorded the `sandi_meter` competitive analysis and a user-added pre-publish gate. metz-scan already beats it on coverage, modern-Ruby accuracy, project analyzers, CI/SARIF, integration, and maintenance; its one edge was a compliance-% scorecard. Queued two pre-publish items (a `scan` compliance scorecard + a README "how it compares" section) with the exact scorecard spec and README draft in `implementation-notes.md`, then publish. Docs/tracker/notes only; no code. |
| 2026-07-08 | `e78c5af` | Release readiness — exit criteria 3 and 4. Criterion 3: verified the quickstart against a clean install of the locally-built `0.5.2` candidate (crash-fix ships in the built gem) and fixed the README Quick Start's repo-relative fixture step (consumer first-scan + scoped demo). Criterion 4: gem metadata reads correctly; added `changelog_uri`/`bug_tracker_uri` to both gemspecs, `rubocop-metz` now ships `LICENSE`, revised `docs/releases/v0.5.2.md` for all fixes, pinned new metadata in `release_metadata_test`. **All four exit criteria met; go/no-go: GO.** |
| 2026-07-08 | `d57d2e7` | Closed the accepted `inherit_gem`-exclude limitation: default mode now emits a one-line stderr warning naming an unresolvable `inherit_gem` gem ("... not applied; install the gem or use --all-cops") instead of silently dropping its `Exclude` — stdout report stays clean, `--all-cops` unchanged. `ProjectConfigScope` collects unresolved gems, `Runner` warns once per gem. README/skill note + red-green test. |
| 2026-07-08 | `3e7dbe9` | Re-ran exit criterion 2 (dogfooding) on the fixed HEAD across five codebases — **PASSED** (`docs/dogfooding/2026-07-08-round-0.5.2-reverify.md`): all four 2026-07-07 defects re-verified (no crashes, 0 false `Lint/Syntax`, corrected collaborator counts), no new headline defect. Recorded one accepted `inherit_gem`-absent exclude limitation with a queued loud-warning follow-up. Round doc + tracker only; no code change. |
| 2026-07-08 | `cd6f18c` | Fixed dogfood defect D: `Metz/ControllersTooManyDirectCollaborators` no longer counts raise-site exception classes (added `raise_exception_class?` mirroring the `rescue`-site exclusion) or the `Arel` SQL helper (added to `CORE_COLLABORATOR_ALLOWLIST`) — the #34 sibling gap. Verified on real code (lobsters `login` 8→3; huginn `jobs_controller` no longer flags); red-green cop tests. Completes all four round-2 defects. |
| 2026-07-08 | `4b64a93` | Fixed dogfood defect C: default scans now honor the target's `TargetRubyVersion` (declared or detected) by carrying it through the scope-only loader and `RUBOCOP_TARGET_RUBY_VERSION`, so `--force-default-config` no longer parses with the 2.7 floor and emits false `Lint/Syntax` on Ruby 3.1+ syntax. Still no plugin loading; `--all-cops` and forced Metz tuning unchanged. Codex-implemented, orchestrator-polished (`Metrics/ModuleLength`) and independently verified (repro clean, rake 558/0F, rubocop clean, dogfood PASS); red-green test in `scan_test.rb`. |
| 2026-07-08 | `8b246ba` | Fixed dogfood defects A/B: default mode now honors local target file scope without loading absent target RuboCop extensions (`plugins:`, `require:`, `inherit_gem:`), so external-gem configs no longer crash Metz-only scans; load-error text now distinguishes missing target extensions from missing `rubocop-metz` and strips extensionless `bin/metz-scan` stack frames. Added red-green default-scope and subprocess error tests, documented the RuboCop scope-only internal-API decision in a DDR/notes, and revised README/skill/release notes. |
| 2026-07-07 | `1f34145` | Reran exit criterion 2 (dogfooding) on HEAD 0.5.2 across five real codebases — **NOT PASSED**, four headline-UX defects (`docs/dogfooding/2026-07-07-round-0.5.2.md`): default-mode crash + misattributed error (regression from #33/#37, in `v0.5.1`), `TargetRubyVersion` loss → false `Lint/Syntax`, and `ControllersTooManyDirectCollaborators` over-count (#34 sibling). Reframed the release strategy to fix → re-dogfood → single release and rebuilt the queue around the fixes. Round doc + tracker only; no code change. |
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
- Dogfooding round notes: `docs/dogfooding/2026-07-08-round-0.5.2-reverify.md`
  (latest, criterion 2 PASSED), `docs/dogfooding/2026-07-07-round-0.5.2.md`
  (criterion 2 failed, four defects), `docs/dogfooding/2026-07-05-round-0.5.0.md`.
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
