# Implementation Notes

This file keeps recent implementation context only. Older chronological notes
were archived to
`docs/archive/implementation-notes-2026-06-29-through-2026-07-03.md` during the
2026-07-03 release-readiness housekeeping pass.

Use `.trk/` (`trk status --json`) for the current goal, next steps, backlog, and
log. Add new notes here only when a slice needs more durable detail than STATE
should carry.

## 2026-07-09: Tier-2 TestCallsPrivateMethod analyzer

Task: implement wrapper-side `MetzProject/TestCallsPrivateMethod`, the
Rubydex-index-confirmed form of opt-in Tier-1 `Metz/TestReachesPrivate`.

Scope boundaries: wrapper/project-analyzer only; no RuboCop cop changes, no
runtime double-report coordination, no default-output promotion, and no commit
or push. The analyzer bails when the project index is unavailable and only
considers test files in the Tier-1 include globs.

Decisions: added `visibility` to `ProjectIndex::MethodDeclaration` from
`Rubydex::Method#visibility`; added an AST-backed `module_function` visibility
seam because Rubydex 0.2.8 aborts on that visibility form; kept lookup
own-declaration-only and conservative for SUT resolution; requires test paths
in the scan set (`scan . --project-analyzers`, not only `app lib`). Tier-2
supersession of `Metz/TestReachesPrivate` is documented, not runtime-enforced,
because the cop cannot depend on the wrapper index.

Verification: red-green started with failing analyzer/index tests. Final gates:
`bundle exec rake` passed with 664 runs, 3151 assertions, 0 failures, 0 errors,
2 skips; `bundle exec rubocop` passed with 242 files inspected and no offenses;
`bin/check_dependency_direction`, `bin/check_sample_app_frozen`,
`bin/check_rubydex_drift`, and early/final `bin/check_dogfood` all passed.

## 2026-07-09: Second testing-discipline cop — Metz/TestAssertsOnInternals (opt-in)

Task: Next Queue item 1 — `Metz/TestAssertsOnInternals` (`docs/design/testing-cops.md`
§5), the second testing cop, copying the `TestReachesPrivate` template.

Cop: `RuboCop::Cop::Metz::TestAssertsOnInternals` (rubocop-metz, Tier 1, AST-only,
`on_send` + `OnSendCsendBridge`). Flags, in test files (Include globs
`*_test.rb`/`test_*.rb`/`*_spec.rb`):

- `instance_variable_get` / `instance_variable_set` on any receiver (arg literal or
  dynamic — the method is the signal);
- receiverless `assigns(:name)` with a bare symbol/string literal arg (Rails
  controller-test reading a controller-assigned ivar).
Does NOT flag bare `@ivar` reads/writes (the test's own fixture state — FP-flood
avoidance per spec §5), or `assigns` with a receiver / dynamic arg / no arg. Escape
hatch: `AllowedReceivers`. Ships `Enabled: false`. Message is mechanism-based.

`TestFrameworks` module DEFERRED AGAIN (re-evaluated): like `TestReachesPrivate`, this
cop is file-glob scoped and keys off specific method sends, so it needs no
test-case-boundary or assertion detection. The module earns its place at
`TestStubsSubject` (identifying the subject + double/stub sends genuinely needs it).
No `DemeterTrainWreck`/`TypeInference` coupling (no operator logic) — kept the template
clean; DEP-1 remains a separate queued decouple.

No wrapper changes: the family opt-in gate (dropped `--enable-all-cops`) and the
fixture-app exclusion already exist from slice 1. Only `ALL_METZ_COPS` (rules/explain)
and the README/SKILL opt-in note needed updating.

Delegation/verification: Codex-implemented (`task-mrcz5vis-1ndds2`; the recorded
~10h49m duration is wall-clock across an overnight machine sleep, not work time) with
red-green + reviewer; the orchestrator independently reviewed the full diff and reran
verification — `bundle exec rake` 603/0F/0E, `bundle exec rubocop` clean (227 files),
`check_dependency_direction` / `check_sample_app_frozen` / `check_dogfood` (0 findings)
all PASS. 17 both-framework cop tests.

## 2026-07-08: First testing-discipline cop — Metz/TestReachesPrivate (opt-in)

Task: Next Queue item 1 — begin the testing-cops rollout
(`docs/design/testing-cops.md` §9 step 2) with the template cop, opt-in.

Cop: `RuboCop::Cop::Metz::TestReachesPrivate` (rubocop-metz, Tier 1, AST-only).
Flags `send`/`__send__` with a bare symbol/string literal method name inside
test files (Include globs `**/*_test.rb`, `**/test_*.rb`, `**/*_spec.rb`).
Escape hatches: `AllowedMethods` (default
define_method/remove_const/include/extend/prepend/alias_method),
`AllowedReceivers`, operator-symbol skip. Ships `Enabled: false`. Message is
mechanism-only ("reaches past the public interface via `send`") — AST cannot
prove privacy, and receiverless `send(:foo)` may call the test's own method.

Deliberate deviations from the spec (also recorded in
`docs/design/testing-cops.md`):

- **`public_send` DROPPED** from detection (spec §5 listed it). It can only
  invoke public methods, so flagging it contradicts the cop's principle and is a
  guaranteed FP; core `Style/SendWithLiteralMethodName` already owns the
  pointless-indirection angle. (Fable design review + verified.)
- **`TestFrameworks` support module DEFERRED** (YAGNI). This cop scopes by
  file-glob and is framework-agnostic, so it needs no per-framework matchers;
  both Minitest and RSpec are covered by fixtures. The module earns its place
  with the first cop that needs test-case-boundary/assertion detection
  (`TestAssertsOnInternals`), which will also carry the DEP-1 decouple.

Opt-in gate (reusable for the whole `Metz/Test*` family): default-mode scan ran
`--force-default-config --enable-all-cops --only Metz`; `--enable-all-cops`
force-enables every Metz cop regardless of `Enabled`. Dropped it →
`--force-default-config --only Metz` respects the plugin `default.yml` `Enabled`
flag (empirically verified: a cop set `Enabled: false` in the gem default.yml
does not run under this argv, but does with `--enable-all-cops`), so
`Enabled: false` genuinely gates a cop out of default output; promotion = flip
to `Enabled: true`. Companion fix: `scan --fix` (`auto_fix.rb` `run_in_place`)
pipes stderr to the user, so removing `--enable-all-cops` re-surfaced RuboCop's
pending-cops banner there; added `--disable-pending-cops` to the fix path only
(the scan path swallows stderr into a StringIO, so it doesn't need it).

Known follow-up (**DEP-1**, tracked in Next Queue): the cop reaches into
`DemeterTrainWreck::TypeInference.operator?` — a testing cop coupled to a
Demeter-specific module, and this is the template. Accepted for this slice
(low-risk, same gem, dependency-direction clean, fully tested); extract a
neutral operator predicate as its own change folded into the
`TestAssertsOnInternals`/`TestFrameworks` slice rather than bundling a cross-cop
refactor here.

Delegation/verification: Codex-implemented (`task-mrcs1x1q-mzdk93`, ~20m) with
its own red-green + reviewer; the orchestrator independently reviewed the full
diff and reran verification — `bundle exec rake` 586/0F/0E, `bundle exec
rubocop` clean (225 files), `check_dependency_direction` /
`check_sample_app_frozen` / `check_dogfood` (0 findings) all PASS. New
both-framework cop tests (14 runs) + a wrapper gate test
(`ScanOptInCopSelectionTest`) proving default mode hides the cop while
`--all-cops` + project enablement surfaces it.

## 2026-07-08: v0.5.3 — corrupt rubygems.org publish, recovery, and gemspec guard

Incident: the first rubygems.org push (`0.5.2`) shipped a **corrupt
`rubocop-metz`**. It was built with `gem build rubocop-metz/rubocop-metz.gemspec`
**from the repo root**, and the gemspec's `spec.files` used a CWD-relative
`Dir.glob("{lib,config}/**/*")`, so it packaged the wrapper's `lib/metz_scan`
files instead of `rubocop-metz`'s own cops. `require "rubocop-metz"` then failed
for anyone who installed from rubygems.org — the documented `bundle exec
metz-scan scan` path was broken (a bare `--version` check would NOT have caught
it; only running a real scan did). The `RELEASE_CHECKLIST.md` command is
`cd rubocop-metz && gem build` precisely to avoid this; the orchestrator
deviated. GitHub Packages `0.5.2` was fine (built via `cd rubocop-metz`).

Constraint: rubygems.org forbids overwriting a version and forbids re-pushing a
yanked one, so `0.5.2` can't be fixed in place — the fix is a clean `0.5.3`.

Fix, second attempt (the first was wrong): the initial hardening made the
gemspec compute `gem_root = File.expand_path(__dir__)` and `Dir.chdir` there.
`__dir__` is unreliable when a gemspec is **eval'd** (Bundler/Dependabot eval it
with a relative `__FILE__` after chdir'ing into the gem dir, so
`File.expand_path(__dir__)` produced a doubled path), and the side-effecting
`Dir.chdir` then crashed gemspec evaluation. The CI **test** workflow stayed
green (it builds/tests from the repo root where it happened to resolve) but the
**Dependabot** job went red loading the gemspec — that's what surfaced it. The
shipped fix (`9b1c0fd`) is side-effect-free: keep the original CWD-relative
`Dir.glob` and, right after building `spec.files`, `raise` a clear "build from
the gem's own directory" error if the entrypoint (`lib/rubocop-metz.rb` /
`lib/metz_scan.rb`) is missing. This converts a wrong-directory build into an
immediate, self-explaining failure instead of a silently corrupt gem, and leaves
gemspec eval clean in every context (Bundler, Dependabot, `gem build`).

Lessons (durable):

- Release verification for a wrapper+plugin gem pair MUST run a real `scan` from
  a clean install of each registry, not just `--version` — a broken transitive
  dependency only shows up when the plugin is actually required.
- Always build `rubocop-metz` from its own directory; the gemspec now enforces
  this. Content-verify each built gem (`gem spec <gem> files`) BEFORE `gem push`.
- Don't put side effects (`Dir.chdir`) or `__dir__`-dependent absolute-path
  logic in a gemspec — it's eval'd in several contexts (gem build, Bundler,
  Dependabot) with different CWD/`__FILE__` semantics. Prefer a loud guard.
- `check_ci_parity` and the CI **test** workflow do not exercise the Dependabot
  gemspec-eval path; a green test suite is not proof the gemspec loads cleanly
  everywhere.

Delegation: version-bump/first-hardening prep was sonnet-delegated; the
orchestrator caught the Dependabot regression, replaced the fragile fix with the
guard, and ran all irreversible build/publish/verify/yank steps directly.
Pending: `gem yank rubocop-metz -v 0.5.2` / `metz-scan -v 0.5.2` need a key with
the `yank_rubygem` scope (the maintainer's key only has `push_rubygem`).

## 2026-07-08: v0.5.2 release completion (GitHub Packages)

`v0.5.2` published to GitHub Packages under explicit user authorization. Tag
`v0.5.2` (annotated `b38a3ba`) → commit `7b06793`; GitHub Release from
`docs/releases/v0.5.2.md`; both gems pushed in dependency order (`rubocop-metz`
then `metz-scan`).

Delegation: the publish execution was autobots-delegated to a sonnet
`coding-worker` (SHA-pinned to `7b06793`, ordered pushes, explicit
stop-on-anomaly conditions, scoped to GitHub Packages only — no rubygems.org, no
issue writes, no commits). The orchestrator ran a read-only pre-flight first
(tag absent, `gh` `write:packages` present, CI green on `7b06793`, rubygems.org
credential absent) and independently verified the outcome after: remote tag →
correct SHA, GitHub Release live (not draft), both packages report `0.5.2`, and
`bin/check_published_gem 0.5.2` PASS with the live `Summary` scorecard and the
absent-external-gem crash-fix confirmed in a clean consumer project. Shape of the
"2026-07-06: v0.5.1 release completion" record.

**rubygems.org still pending.** The release machine has no rubygems.org
credential, and `gem push` to rubygems.org needs interactive `gem signin`
(account + OTP) or an API key — neither the orchestrator nor a subagent can do
that headlessly. Until the maintainer authenticates and pushes `rubocop-metz`
then `metz-scan` to rubygems.org, the README's `gem install metz-scan` resolves
only from GitHub Packages. All carried issues (#33/#34/#37) were already closed,
so no issue writes were needed.

## 2026-07-08: sandi_meter pre-publish gate CLOSED (scorecard + README) + Codex reap recovery

Status: **both pre-publish items landed** and verified. The compliance scorecard
(item 1) and the README "How metz-scan compares" section (item 2) are on `main`'s
working tree, verified on the settled tree (`rake` 569/0F/0E, `rubocop` clean,
`check_dogfood` PASS, docs-freshness green). Only publish (explicit user
authorization) remains. The sandi_meter analysis and the item specs below are
kept as the record.

Codex delegation + reap recovery (durable, matches the CLAUDE.md delegation
protocol and the #432 root-cause class): the scorecard was implemented by a
foreground-forwarded Codex task (`task-mrbo8b3m-rcqu7z`). Its companion worker
was reaped mid-verification — the node companion orphaned to PPID 1 with its
`bundle exec rake` subprocess already dead and the job log 30+ min stale, while
`status` still read `running` (the status Progress snapshot lagged badly and was
misleading twice; the log mtime + a live-process check were the reliable
signals). The deliverable was complete on disk, so per protocol it was verified
directly (full suite + rubocop + dogfood), the stale record cleared with
`codex-companion.mjs cancel`, and the work taken over. Note the environment ran
`bundle exec rake` at ~84 min vs a normal ~8 min (load/flakiness), which made the
"is it hung or slow" call harder — a live ruby/rake process check disambiguated
it (none existed → dead, not slow). Lesson: trust log mtime + `ps`/`kill -0` over
the `status` Progress block, and confirm no subprocess before concluding a slow
run is wedged.

Original state at handoff: all four rubygems.org exit criteria were met
(go/no-go: GO) and `main` HEAD was a publishable release candidate. The user
added a **pre-publish gate**: make sure `metz-scan` clearly beats the prior-art
gem `sandi_meter` (makaroni4/sandi_meter). The two items below are now done.

### sandi_meter competitive analysis (research done this session)

sandi_meter facts: classic four rules only (classes ≤100, methods ≤5, ≤4 args,
controllers ≤1 ivar/action) + misindent warnings; Ripper-based with **open bugs
on modern/concise Ruby** (one-line/endless/private methods — issues #60/#66/#68);
output = compliance %, details tables, JSON, HTML pie charts (auto-opens
browser); **CI exit codes broken (#69)**; not a RuboCop plugin; **dormant — last
release v1.2.0 May 2015**; 769★, ~305k downloads. metz-scan already beats it on:
rule coverage (6 cops incl Demeter + views), **modern-Ruby accuracy** (we just
fixed exactly its weakness), 8 project-level analyzers, SARIF/gh-annotations,
reliable exit codes, RuboCop-native integration, active maintenance, and
`explain`/`rules`. sandi_meter's ONE real edge: its headline **compliance-%
scorecard** — which is also the "no rollup/total line" nit our dogfooding rounds
flagged. The two pre-publish items below close that and stake the positioning.

### Item 1 (DONE): compliance scorecard in `scan` text output

User chose "% headline + per-cop rollup + worst offenders." Metric = **Metz
compliance = % of scanned files with zero `Metz/*` rule-cop offenses** (project
analyzers are advisory, kept out of the %). Re-dispatch to Codex (heavy: touches
text_renderer + many exact-output fixtures + JSON summary + tests + usage docs).
Exact spec to hand Codex verbatim:

- Append a Summary block at the END of `scan` **text** output (after findings and
  the project-analyzers block), one blank line before it. Also in the `report`
  re-render. Not in sarif/gh-annotations.
- Format (align counts, 2-space gutter):

  ```

  Summary
  -------
  Metz compliance: 62% (312/500 files clean)
  435 offenses across 6 cops

  By cop:
    Metz/MethodsTooLong                          333
    Metz/ControllersTooManyDirectCollaborators    58
    ...

  Most offenses:
    app/models/story.rb                           31
    ...
  ```

- Metric defs: compliance % = round((inspected_file_count − files_with_Metz/*_offenses)/inspected_file_count×100);
  "files clean" uses the same numerator. inspected==0 → "Metz compliance: n/a (no files scanned)".
  "<N> offenses across <K> cops": N=offense_count, K=distinct cops with ≥1 offense (Metz/* and MetzProject/*); singular "1 offense across 1 cop".
  "By cop": every cop with ≥1 offense, count DESC then name ASC.
  "Most offenses": top 5 files by total offense count, DESC then path ASC; list all if <5.
  Clean scan (0 offenses): `Metz compliance: 100% (N/N files clean)` + `No offenses found.`, omit By cop/Most offenses.
- JSON summary additive (non-breaking): add `clean_file_count`, `files_with_offenses`, `offenses_by_cop` (cop→count). Do NOT print the text block into JSON.
- Red-green tests; regenerate ALL affected exact-output fixtures under test/fixtures/ + README/skill freshness DELIBERATELY (never loosen). Don't modify test/fixtures/sample_app/ files themselves. Fix lives in lib/metz_scan. Summary must not change exit codes.

### Item 2 (DONE): README "How metz-scan compares" section

Do this AFTER the scorecard lands (avoid README edit conflict). Orchestrator
writes it (positioning narrative). Draft to adapt (factual, credits sandi_meter
as prior art, not disparaging):

> ## Why metz-scan?
>
> metz-scan is a modern, actively maintained take on the question `sandi_meter`
> popularized — how well does this code follow Sandi Metz's rules?
>
> - All four classic rules, plus Law-of-Demeter chains and deep view navigation.
> - Correct on modern Ruby: analyzes at your project's `TargetRubyVersion`, so
>   Ruby 3.x syntax (endless methods, anonymous forwarding, pattern matching)
>   isn't misparsed.
> - Project-level design pressure (8 analyzers), not just per-file rules.
> - CI-native: JSON, SARIF (code scanning), GitHub annotations, reliable exit codes.
> - RuboCop-native: honors your `Exclude` scope; slots into existing pipelines.
> - Explains itself: `metz-scan explain <cop>` / `metz-scan rules`.

### Then: publish (explicit user authorization)

`release` skill runbook: tag `main` HEAD `v0.5.2` → GitHub Release → publish both
GitHub Packages gems (`rubocop-metz` before `metz-scan`) → `bin/check_published_gem 0.5.2`.
Whether to also push to rubygems.org (both names unclaimed as of 2026-07-05) is
part of the go decision.

## 2026-07-08: Release readiness — criteria 3 (quickstart) and 4 (preflight)

Task: rubygems.org exit criteria 3 and 4 against the fixed HEAD.

Criterion 3 (README quickstart vs a clean install): built the candidate gems
locally (`gem build` both) and installed them into an isolated `GEM_HOME`
(real deps from rubygems.org) — this is the faithful "release candidate" target
since the published `0.5.1` still has the crash. Verified `metz-scan --version`
(0.5.2), `rules`, `explain`, and `scan` of the service-soup fixture all work,
and that the crash-fix ships in the *built gem* (scanning redmine's external
`plugins:` returns exit 1, not the old exit-2 crash). Found + fixed one README
gap: the Quick Start's `cp -R test/fixtures/service_soup_app` is repo-relative
(a fresh consumer doesn't have it), so it now leads with a consumer first-scan
(`scan app lib`), explains that exit 1 means findings, and scopes the fixture
demo to "from a checkout of this repository."

Criterion 4 (gem metadata / preflight): `gem specification` on both built gems.
Description, homepage, MIT license, `source_code_uri`, `github_package_uri`,
and the `~> 0.5.2` pin all read correctly. Fixed gaps: added `changelog_uri`
(→ releases page) and `bug_tracker_uri` (→ issues) to both gemspecs, and made
`rubocop-metz` ship its `LICENSE` (it declared MIT but didn't package the file;
copied the root LICENSE). New assertions in `release_metadata_test.rb` pin these.
Left `github_repo` (`ssh://…`, a non-standard key with an unclear consumer)
alone to avoid breaking it. Revised `docs/releases/v0.5.2.md` to cover all four
fixes plus the warning and the metadata additions.

Go/no-go: **GO.** All four exit criteria met (1 names/released, 2 dogfood-clean,
3 quickstart verified, 4 metadata reads correctly). The candidate is the current
`main` HEAD carrying the `0.5.2` bump; publish is the user's explicit decision.

Verified: `release_metadata_test` + `release_checklist_test` green; rebuilt gems
show the new metadata and shipped LICENSE; no stray `.gem` in the repo. Docs
freshness unaffected (Quick Start isn't pinned).

## 2026-07-08: Warn on unresolvable inherit_gem excludes (no silent degrade)

Task: Next Queue item 1 — the 2026-07-08 re-dogfood round accepted one
limitation (`docs/dogfooding/2026-07-08-round-0.5.2-reverify.md`): when a
target's `Exclude` lives only in an absent `inherit_gem`'d config (Rails 8
omakase), default mode silently dropped it. This turns the silent degrade loud,
honoring the DDR's "no silent degrade" principle.

Change: `ProjectConfigScope` accumulates `[config_path, gem_name]` whenever an
`inherit_gem` can't be resolved (the rescued `Gem::LoadError` in `gem_dir_for`),
reset per scan; `Runner.perform` warns once per gem to stderr after default-mode
scope resolution (guarded `unless all_cops`), threading the CLI's injected
`stderr` through `Runner.invoke`/`Scan#scan`. Warning is stderr-only (stdout
report/JSON stays byte-clean) and deduped by gem name. `--all-cops` unchanged
(it already errors loudly on missing gems). README + skill note added.

Delegation/verification: implemented via an autobots `coding-worker`; the
orchestrator reviewed the diff and independently verified — focused `scan_test`
14 runs/0F (new `ScanUnresolvedInheritGemWarningTest` + a deliberately-updated
external-config test), `bundle exec rubocop` clean, and reproduced the warning
(stderr one-liner naming the gem, stdout clean, exit 0). Full suite is verified
via `bin/check_ci_parity` (clean clone, no rubydex — the worker's local
`.bundle/config with rubydex` slows local `bundle exec` but does not affect CI).

## 2026-07-08: ControllersTooManyDirectCollaborators stops over-counting (dogfood defect D)

Task: dogfood defect D from `docs/dogfooding/2026-07-07-round-0.5.2.md` §4 — the
cop counted non-collaborators, the same class as the already-fixed #34 (whose
fix excluded exception constants at `rescue` sites but did not carry to this
sibling cop). Two verified facets: raise-site exception classes (lobsters
`login_controller` reported `login` as 8 collaborators, 5 of them file-local
`*Error` classes raised/rescued in the method) and framework query helpers
(huginn `jobs_controller` counted `Arel` in `Delayed::Job.order(Arel.sql(...))`).

Fix (`rubocop-metz/lib/rubocop/cop/metz/controllers_too_many_direct_collaborators.rb`):
add `raise_exception_class?` to the `ignored?` chain, mirroring the existing
`rescue_exception_class?` — a const that is the first argument of a receiverless
`raise`/`fail` (covering `raise Klass, "msg"` and `raise Klass.new(...)`) is not
a collaborator; and add `Arel` to the existing `CORE_COLLABORATOR_ALLOWLIST`
(which already held `Rails Time Date DateTime` etc.), the minimal consistent
change (no new configurable surface, matching the sibling `DemeterTrainWreck`
intent). The cop is `on_def`, so no `OnSendCsendBridge` is involved.

Delegation/verification: implemented via an autobots `coding-worker` in an
isolated git worktree (parallel with defect C in the main tree, no collision);
the orchestrator applied the two-file diff to `main` and independently verified.
Real repros: lobsters `login` 8→3 collaborators; huginn `jobs_controller#index`
no longer flags (Arel allowlisted → 1 = Max). Red-green tests in the cop's test
file. `bundle exec rake` 561 runs/0F/0E; `bundle exec rubocop` clean; dependency
direction ok; `bin/check_dogfood` PASS.

## 2026-07-08: Default scans honor the target's Ruby version (dogfood defect C)

Task: dogfood defect C from `docs/dogfooding/2026-07-07-round-0.5.2.md` §3 —
default mode ran RuboCop with `--force-default-config`, discarding the target's
`TargetRubyVersion`, so RuboCop fell back to its 2.7 floor parser and emitted
false `Lint/Syntax` on Ruby 3.1+ syntax (194 bogus offenses on redmine).

Fix: extend the scope-only `ProjectConfigScope` (from the crash-fix slice) to
also read the target's effective Ruby version — declared `AllCops:
TargetRubyVersion` or, when absent, RuboCop's own detection from
`.ruby-version`/Gemfile via `RuboCop::Config#target_ruby_version` (not the 2.7
floor). `TargetRubyVersion.with_project_config` wraps the default-mode RuboCop
run and sets `RUBOCOP_TARGET_RUBY_VERSION` (a first-class RuboCop `TargetRuby`
source in 1.88.0 — a supported mechanism, not an internal hack), restoring the
prior ENV after. Still no plugin loading; `--all-cops` unchanged; Metz tuning
still forced (only the parser Ruby version is honored).

Delegation/verification: implemented via Codex, which stopped at its two-strikes
rule with only mechanical `Metrics/ModuleLength`/style offenses left; the
orchestrator finished the polish (inlined the single-use `offenses?` predicate,
autocorrected the helper) and independently verified. End-to-end repro: default
mode emits no `Lint/Syntax` on anonymous-block-forwarding. `bundle exec rake`
558 runs/0F/0E; `bundle exec rubocop` clean (221 files); `bin/check_dogfood`
PASS. Red-green test in `test/metz_scan/commands/scan_test.rb`.

## 2026-07-08: Default scans avoid target RuboCop extension loads

Task: dogfood defects A + B from
`docs/dogfooding/2026-07-07-round-0.5.2.md` — default mode crashed on targets
whose `.rubocop.yml` referenced absent RuboCop extension gems, and the error
path blamed `rubocop-metz` or leaked a `bin/metz-scan` stack frame.

Decision: **option 1, honor scope without loading plugin gems.** RuboCop 1.88.0
does not expose a supported "scope only, no extensions" config API; normal
`RuboCop::ConfigStore` eagerly resolves `plugins:`, `require:`, and inherited
gem configs. The fix adds a wrapper-local `ProjectConfigScope` loader that
parses RuboCop YAML, preserves only file-scope data (`AllCops` Include/Exclude,
Metz per-cop Include/Exclude, and Ruby interpreters for target discovery), and
feeds that into `RuboCop::TargetFinder` / `excluded_file?`. This keeps the

# 33/#37 scope contract for local target config without requiring target

extension gems in the `metz-scan` bundle. An absent `inherit_gem` cannot
contribute scope because its config file is unavailable; installed inherited
configs are parsed through the same scope-only path. Durable internal-API
exception recorded in
`docs/ddrs/2026-07-08-rubocop-scope-only-config.md`.

Error handling: only the wrapper's own `require "rubocop-metz"` failure is
reported as `could not load rubocop-metz`. Later `LoadError`s from a target
config now surface as RuboCop config load failures, and `concise_message`
filters extensionless entrypoint stack frames such as `bin/metz-scan:10:in`.

Red-green: added a default-mode fixture whose `.rubocop.yml` declares
`plugins:`, `require:`, and `inherit_gem:` entries for absent extension gems
while also scoping off `excluded/**/*` and `spec/**/*`; it failed with exit 2
before the fix and now exits 1 with the local scopes honored. Added subprocess
coverage for `--all-cops` missing target plugin errors and a shimmed missing
`rubocop-metz` case so the two messages stay distinct.

## 2026-07-07: Prepare 0.5.2 release target (carries #37)

Task: Release readiness / Path-to-rubygems.org next move — cut the release
carrying #37 so exit criterion 2 can rerun against released gems that include
the per-cop `Exclude` behavior.

Version choice: **0.5.2 patch.** Precedent-consistent — the sibling #33
default-scan-`AllCops: Exclude` change shipped as the `0.5.1` patch, and #37 is
the same class (default scans now honor the finer-grained per-cop `Exclude`
scope while still forcing Metz tuning). No threshold/policy change, so patch,
not minor.

Shape: mirrors `3ec8f29` exactly — bump both `version.rb` to 0.5.2, regenerate
`Gemfile.lock` (`~> 0.5.1` pin → `~> 0.5.2`, 5 lines), move the release-issue
dry-run expectations, add `docs/releases/v0.5.2.md` (describes only #37).
Delegated the mechanical prep to an autobots `coding-worker`; orchestrator
reviewed the diff and owns the tracker/notes updates in the same commit.

Verified (worker + independent review): focused release-issue test 2 runs/18
assertions PASS; `bundle exec rake` 553 runs/2652 assertions/0F/0E/2 skips PASS;
`bundle exec rubocop` clean (219 files); `git diff` matches the `3ec8f29` shape
with no stray churn. `bin/check_ci_parity` is the pre-push gate — run it after
commit, before push. Publish/tag/GitHub Release remain gated on user
authorization.

## 2026-07-06: #37 default scans honor project per-cop Exclude (fixes check_dogfood red)

Task: tracker Next Queue task 3 — resolve `bin/check_dogfood` red on `main`,
recording an explicit intended-vs-defect decision.

Decision: **defect.** Per-cop `Metz/*: Exclude` is file *scope*, not cop
*tuning*, so default mode should honor it the same way #33 honors
`AllCops: Exclude`. The distinction that resolves the whole fork: default mode
overrides *tuning* (Max/Enabled/Severity) but honors *scope* (Include/Exclude).

# 33 already committed to honoring scope at the AllCops level; per-cop `Exclude`

is the same file-scoping mechanism at finer granularity, and it matches Sandi
Metz's intent (the length rules target production code, not arrange-act-assert
tests with embedded fixtures). Honoring it grants no new hiding power users did
not already have via `AllCops: Exclude`. Filed as #37 (user-approved).

Root cause (was): default mode resolves target files with the project config
(honoring `AllCops: Exclude`, per #33) but ran RuboCop with
`--force-default-config --enable-all-cops --only Metz`, discarding *per-cop*
config including `Exclude`. This repo excludes its test trees from
`Metz/MethodsTooLong`/`Metz/ClassesTooLong` per-cop, so the dogfood scan
reported 90 offenses, all in test files.

Fix: `lib/metz_scan/commands/scan/runner.rb` — in default mode only, post-filter
offenses through a new `ProjectCopScope.honor`, dropping any `(cop, file)` pair
the project config scopes off (RuboCop's own `Cop.new(project_config)
.excluded_file?`), then recomputing `summary.offense_count`. Invalid project
config → no filtering (matches the target-discovery fallback). `--all-cops` is
unchanged (already honors the full project config). Extracted into its own
module to keep `Runner` under `Metrics/ModuleLength`.

Granularity is the point and is test-locked: a coupling smell in a
length-excluded spec still reports (`DemeterTrainWreck`), so we keep the Metz
opinions Sandi holds about test code while dropping the length noise.

Also cleaned an inert exclude: `.rubocop.yml` no longer lists
`Metz/DemeterTrainWreck` in the test-tree exclude set (verified 0 offenses
there), so the config documents "only the length cops are exempt on tests;
coupling stays enforced."

Verification: new red-green tests in
`test/metz_scan/commands/scan_test.rb::ScanProjectPerCopExcludeTest`;
`bin/check_dogfood` PASS on `scan .` unchanged; `bundle exec rubocop` clean
(219 files). User-facing behavior change — release-worthy, noted for the next
release; not bumped/tagged in this slice.

## 2026-07-06: Dual-agent workspace (Claude Code + OpenAI/Codex)

Task: user-requested — make the agent workspace (brief, skills, guides) usable
by both Claude Code and OpenAI/Codex sessions.

Decisions:

- One source of truth: `CLAUDE.md` is the canonical shared brief for all
  agents; `AGENTS.md` is a thin OpenAI entrypoint that routes to it (plus the
  OpenAI-only sections it already had). No content duplication between them.
- Skills stay canonical in `.claude/skills/` (known-working Claude discovery);
  Codex discovers them through a `.agents/skills → ../.claude/skills` symlink.
  Verified against developers.openai.com/codex/skills: Codex scans
  `$REPO_ROOT/.agents/skills`, follows symlinked skill folders, and needs only
  `name`/`description` frontmatter.
- Skill bodies use harness-neutral wording ("use the land-slice skill") instead
  of Claude slash syntax; `test/metz_scan/agent_workspace_docs_test.rb` pins
  the symlink, frontmatter, neutral wording, and cross-references so the two
  entrypoints cannot silently drift.
- Codex-specific UI metadata (`agents/openai.yaml`, as `skills/metz-scan/`
  has) deliberately skipped for the maintainer skills — SKILL.md alone is
  sufficient per the Codex docs; add it only if the skills misbehave in Codex.

## 2026-07-06: v0.5.1 release completion

Published the prepped `0.5.1` target (`3ec8f29`) after green CI on the push:
tag `v0.5.1` at `3ec8f29`, GitHub Release cut from `docs/releases/v0.5.1.md`,
then `gem push` of `rubocop-metz` before `metz-scan` to GitHub Packages.

Verification: `bin/check_published_gem 0.5.1` PASS against a clean consumer
install resolving both gems from GitHub Packages; the #34 fix is confirmed
live (`Controller method` label). Both packages are visible under the account
package pages. Issues #33 and #34 (already closed by their fix commits) carry
release-link comments. Built `.gem` artifacts were removed after publish.

rubygems.org exit criterion 2 still requires a fresh dogfooding round on these
released gems — that is the next queue item, not part of this release.

## 2026-07-06: v0.5.1 release target prep

Task: tracker Next Queue task 1 — release the #33/#34 fixes to GitHub Packages.

Scope boundaries:

- No behavior changes beyond version surfaces; the analyzer fixes already
  landed in `d041d51` (#33) and `16824db` (#34).
- Tagging and publishing wait for explicit release authorization; the local
  prep is committed and pushed first, CI watched, then publish.

Decisions:

- Chose `0.5.1` (patch), not `0.6.0`: both shipped changes are pure defect
  fixes that reduce false positives and misleading output, with no new
  features or default-behavior change from `0.5.0`.
- Bumped both gem version constants and the lockfile to `0.5.1`. The
  `metz-scan.gemspec` dependency pin is `"~> #{MetzScan::VERSION}"`, so the
  lockfile PATH constraint moved to `rubocop-metz (~> 0.5.1)` automatically.
- Left the README install example at `~> 0.5.0`: it already resolves to
  `0.5.1` and stays valid for the whole `0.5.x` line.
- Drafted `docs/releases/v0.5.1.md` centered on #33/#34 with no migration
  note.

## 2026-07-06: #34 controller collaborators false positives

Task: GitHub issue #34 / tracker Next Queue task 1 — reduce false
collaborators and misleading action wording in
`Metz/ControllersTooManyDirectCollaborators`.

Decisions:

- Kept `MaxCollaborators` unchanged; the dogfooding evidence justified
  collaborator classification fixes, not threshold movement.
- Reworded offenses to `Controller method` for all instance methods instead of
  trying to infer Rails public actions from callback/private visibility.
- Filtered constants only where the AST gives local evidence: rescue class
  positions, constants defined directly on the enclosing controller class, and
  a small framework/stdlib allowlist.

## 2026-07-06: #33 default scan excludes

Task: GitHub issue #33 / tracker Next Queue task 1 — default Metz-only scans
must honor target project `AllCops: Exclude` while keeping Metz cop defaults.

Decision:

- Split file selection from cop configuration. Default scan now asks RuboCop for
  target files using the project config first, then invokes RuboCop on that
  explicit file list with `--force-default-config --enable-all-cops --only
  Metz`. This keeps project-level excludes without letting project cop
  thresholds/disables override stock Metz defaults.
- Project analyzers use the same project-config target-file helper in default
  mode so wrapper-level findings do not reintroduce files RuboCop excluded.
- Invalid project config still falls back to forced-default target discovery,
  preserving the previous default-mode behavior of not failing on unreadable
  project config.

## 2026-07-05: Dogfooding round on released 0.5.0

Task: tracker Next Queue task 1 — qualitative dogfooding round, rubygems.org
exit criterion 2.

Scope boundaries: judge output only; no fixes to what the round found (that
became queue tasks 1-2). Target checkouts under
`tmp/project-analyzer-calibration/apps/` were read, never modified.

Decisions:

- Installed the released GitHub Packages gems into a clean Bundler consumer
  (README install path) and ran scans via `BUNDLE_GEMFILE` from each target
  root, rather than editing target Gemfiles — same gems a user gets, without
  mutating the checkouts.
- Targets: lobsters + huginn (no `.rubocop.yml`, satisfying the small-project
  slot), maybe, redmine, rubygems.org.
- Both headline defects were verified against target source before filing;
  #33 also got a minimal released-gem repro (default vs `--all-cops`
  exclude disagreement, rooted at `--force-default-config` in
  `lib/metz_scan/commands/scan/runner.rb:38`).

Verification status: notes and repro are in
`docs/dogfooding/2026-07-05-round-0.5.0.md`; #33 filed. The second issue
(`ControllersTooManyDirectCollaborators` miscounting) is drafted but unfiled —
issue creation was permission-blocked mid-session; the draft needs user
approval to file.

## 2026-07-05: v0.5.0 release target prep

Task: tracker Next Queue task 1 — release the #31/#32 fixes to GitHub
Packages.

Scope boundaries:

- Prepare the `0.5.0` release target only; tagging and publishing wait for
  explicit release authorization.
- No behavior changes beyond version surfaces.

Decisions:

- Chose `0.5.0` (not `0.4.1`) because #31 is a default-behavior change: scans
  now default to Metz-only output and `--all-cops` is required for the old
  full-suite behavior.
- Bumped both gem version constants, the lockfile, the README install
  example, and the release issue dry-run expectations to `0.5.0`.
- Drafted `docs/releases/v0.5.0.md` centered on the #31/#32 fixes and the
  `--all-cops` migration note.

## 2026-07-05: Direction review and course correction

Task: review whether the project was proceeding in the right direction.

Findings: effort had drifted inward — since 2026-06-25, docs/tracker churn
(18.2k lines) ran 2.6x product-code churn (6.8k), the test suite (10.3k lines)
outgrew both gems' product code (8.8k), and the extensive internal
verification surface still missed the headline UX defect (#31) that one
afternoon of ctxpack dogfooding found immediately.

Decisions:

- Direction is now a quality-gated path to rubygems.org with four concrete
  exit criteria (see `PROJECT_TRACKER.md` Current Direction). The gate is
  deliberately concrete so "not good enough yet" cannot become indefinite.
- Test hardening is declared done; fixture/coverage sweeps are parked as a
  class with a defect-based reopen trigger.
- Dogfooding on real codebases is the direction engine going forward;
  qualitative "was this finding worth reading?" evidence outranks drift
  counts.
- Added standing rules capping checkpoint prose and requiring queue work a
  tool user would notice over work only this repo's tests would notice.
- Both gem names verified unclaimed on rubygems.org (API 404) on 2026-07-05.

## 2026-07-05: Codex-delegated queue tasks 1-4 (test-hardening fixtures)

Task: delegate tracker Next Queue tasks 1-4 to Codex (session
`019f3434-3ed8-7ec3-8fb1-bf23ae145220`) with agenticons, then review and
update the tracker.

Scope boundaries: test files and fixtures only; no production script changes,
no live lookups, no credential precedence changes, no clone cleanup changes.

Decisions:

- `RENDER_ISSUE_COMMENT_TRACKER_PATH` fixture decoupling removes the recurring
  breakage risk where every tracker edit could invalidate the #25 exact-output
  test.
- The default gem-credentials test reuses the existing fake-HOME subprocess
  pattern rather than adding a new harness.

Verification: Codex ran focused tests, fast/slow suites, full rubocop, diff
check, strategic validation, and design review, all clean. The orchestrating
session independently reran the three focused test files (18 runs, 136
assertions, 0 failures) and reviewed the full diff.

Follow-up: dogfooding issues #31/#32 were triaged into queue positions 1-2;
see `PROJECT_TRACKER.md`.

Task: start the next four large tracker tasks, keep using agenticons, track
elapsed time, update `PROJECT_TRACKER.md`, and commit.

Scope boundaries:

- Keep release readiness conservative.
- Do not publish gems, create tags, or create GitHub releases.
- Do not change analyzer behavior, thresholds, statuses, default-output
  policy, suppressions, or calibration targets.
- Preserve historical implementation context in an archive instead of deleting
  it.

Decisions:

- Deferred a new release tracking issue because both gems still report version
  `0.3.0`, and GitHub already has a `v0.3.0` release. The next release issue
  should wait for an explicit next version target.
- Moved the tracked calibration target manifest out of the ignored `tmp/` tree
  so future tracked edits are visible without special Git handling.
- Removed stale ignored local gem artifacts for release hygiene.

## 2026-07-03: v0.4.0 release target prep

Task: start the next four large tracker tasks, keep using agenticons, track
elapsed time, update `PROJECT_TRACKER.md`, and commit.

Scope boundaries:

- Prepare the next release target only.
- Do not publish gems, create tags, create GitHub releases, or push.
- Do not change analyzer behavior, thresholds, statuses, default-output
  policy, suppressions, or calibration targets.

Decisions:

- Chose `0.4.0` as the next release target because `v0.3.0..HEAD` includes
  new opt-in candidate analyzers and calibration/reporting surfaces, not only
  release-maintenance changes.
- Bumped both gem version constants and the lockfile to `0.4.0`.
- Updated the README install example and release issue dry-run expectations to
  match `0.4.0`.
- Drafted `docs/releases/v0.4.0.md` as the release-note source for the next
  release checklist.

## 2026-07-03: v0.4.0 local release verification

Task: start the next four large tracker tasks, keep using agenticons, track
elapsed time, update `PROJECT_TRACKER.md`, and commit.

Scope boundaries:

- Verify the committed `0.4.0` release-prep head locally.
- Do not push, publish gems, create tags, create GitHub releases, or open the
  release checklist issue in this slice.
- Do not change analyzer behavior, thresholds, statuses, default-output
  policy, suppressions, or calibration targets.

Verification:

- `bundle exec rake` passed: 465 runs, 2055 assertions, 0 failures, 0 errors,
  2 skips.
- `bundle exec rubocop` passed: 196 files inspected, no offenses.
- `bin/check_dependency_direction` passed.
- `bin/check_sample_app_frozen` passed.
- `bundle exec ruby -Ilib -Itest test/metz_scan/release_metadata_test.rb`
  passed: 4 runs, 16 assertions, 0 failures, 0 errors.
- `bundle exec ruby -Ilib -Itest test/metz_scan/create_release_issue_test.rb`
  passed: 2 runs, 18 assertions, 0 failures, 0 errors.
- `bin/create_release_issue --dry-run` rendered `Release v0.4.0`.
- `bin/check_ci_parity` passed against a clean clone, including full suite,
  RuboCop, calibration smoke, dependency-direction guard, and sample-app
  freeze guard.

Decision:

- Local release readiness is green. The next step is to push the local commits,
  watch CI, then open or update the `Release v0.4.0` checklist issue only after
  remote CI is green.

## R1/R2 operation shape cops (2026-07-15)

- Added `Metz/OperationsTooManyPublicMethods` (app/services + app/operations; max 1
  public method excl. AllowedMethods/initialize) and `Metz/GodServiceClass` (*Service
  basename; same public-method limit). Shared `PublicApiMethods` collector +
  `FileClassifier.operation?`. Aligns with rails-audit `docs/application-operations.md`
  rules R1/R2 (enforce illegitimacy, not presence).
- Tests: cop unit tests + file classifier; `metz-scan rules` / `explain` show metadata.
- Not in this slice: R3/R4, concern cops, rails-audit presence-cop removal (sibling work).

## Application operations standard copy (2026-07-15)

- Added full `docs/application-operations.md` in this repo (independent of rails-audit;
  drift accepted; no gem/runtime dependency). README + R1/R2 cop comments point here.

## 2026-07-20: Dependabot-safe gemspec file discovery

Task: fix the Dependabot/Bundler gemspec-evaluation failure caused by CWD-relative
`spec.files` discovery in both gemspecs.

Decision/tradeoff: anchored `Dir.glob` and filesystem predicates to each
gemspec's own directory via `base: gem_root`/`File.join`, preserving relative
package paths and the entrypoint guards without reintroducing global `Dir.chdir`.
A root `gem build rubocop-metz/rubocop-metz.gemspec` may now be safe/correct;
that is preferred over fragile caller detection to preserve the former failure.

Verification: added a red regression test that loads both gemspecs by absolute
path from a temporary non-repo CWD; it failed on the old CWD-relative guards and
passes after the fix. Focused metadata test and focused RuboCop pass. Supported
builds (`gem build metz-scan.gemspec`; `cd rubocop-metz && gem build
rubocop-metz.gemspec`) pass, and built gem contents include each gem's library
entrypoint. Generated `.gem` artifacts were removed.

## 2026-07-20: Green-gate cleanup after local operation cops

Task: keep going after the Dependabot gemspec fix by clearing the two verified
clean-clone gate failures without widening product scope.

Changes: added `Metz/GodServiceClass` and `Metz/OperationsTooManyPublicMethods`
to the `metz-scan rules` registered-cop expectation; split
`bin/check_tracker_queue`'s action-word regex into an equivalent
`Regexp.new` form solely to satisfy line length.

Verification: red-focused rules test and focused RuboCop reproduced the two
failures before the edit; both passed after the edit. Broader verification is
recorded in the subagent report for this slice.

## 2026-07-20: Retire stale goal backlog

Task: remove the stale autonomous goal backlog and route bounded autonomous work
through the tracker.

Static authority proof: `.trk/STATE.md` is the current Goal/Next authority, and
`trk status --json` is the session-start command. The removed backlog still
routed agents toward released `0.5.1` work and `PROJECT_TRACKER.md`. Repository
search found no runtime parser or executor references.

Changes: deleted `.claude/guides/goal-backlog.md`; updated `AGENTS.md`, the
operator playbook, and the workspace docs test to route Codex/executor sessions
to `trk status --json` and `.trk/STATE.md`.

Verification: updated the focused workspace docs test red-first, then green;
searched for live `goal-backlog` references; ran tracker queue and Markdown
audit checks. The Markdown audit still reports pre-existing broken Demeter doc
links, left untouched by this slice.

Continuation: the earlier full-suite timeout did not reproduce. `bundle exec
rake test:fast` passed with 575 runs, 2680 assertions, and 2 skips; the verbose
slow group passed with 110 runs and 582 assertions; and verbose `bundle exec
rake` passed with 685 runs, 3262 assertions, 0 failures, 0 errors, and 2 skips.
The grouped checks exposed no hanging test, so no production or test workaround
was added.

## 2026-07-20: TestCallsPrivateMethod dogfooding

Task: dogfood the Tier 2 `MetzProject/TestCallsPrivateMethod` analyzer before any
rollout decision. Scope was judge-only; no analyzer thresholds, statuses,
suppressions, or production code changed.

Result: working-tree Rubydex runs on Mastodon, OpenFoodNetwork, and Forem found
13, 22, and 60 high-signal RSpec findings. Rails Action Pack, Active Record, and
Active Support found 9, 11, and 0 Minitest findings. Source spot checks matched
private production declarations across both frameworks. Keep the analyzer
candidate-only because Forem's 60-finding review queue is too large for default
output.

Artifacts: `docs/dogfooding/2026-07-20-test-calls-private-method.md` and the
tracker log record the completed round and the candidate-only decision.
