# LOG

## 2026-07-18T08:38Z log
Migrated from PROJECT_TRACKER.md (see git log -- PROJECT_TRACKER.md). v0.5.3 released and verified; testing-cops Tier 1 opt-in, Tier 2 TestCallsPrivateMethod landed. Full chronology stays in git history.

Parked issue boundaries (for bin/render_issue_comment_summary):
- #25 dogfood CI enforcement is trigger-gated. Reopen only when collaboration expands beyond owner plus Dependabot, when PRs regularly come from multiple people, or when CI-enforced dogfood drift becomes a deliberate policy goal.
- #27 DeepInheritanceTree remains parked. Reopen only with new misleading root-label evidence that is not already covered by current broad-root labels and downranking.
- #28 RepeatedBranching remains parked. Reopen only with new evidence that generic low/context-required branch-subject findings are still confusing or underexplained after the README and metadata improvements.

## 2026-07-20T00:51Z resolve dependabot-gemspec-evaluation
Outcome: Implemented CWD-independent gemspec file discovery with a non-repo-CWD regression test; focused test, dependency-direction check, focused lint, documented builds, and independent review passed. Full rake/rubocop remain blocked by pre-existing local operation-cop registry and tracker-script lint failures; no push.

## 2026-07-20T01:13Z resolve green-gate-regressions
Outcome: Restored green clean-clone gates by registering the two operation cops in RulesTest and splitting the tracker queue regex without changing semantics; full suite, RuboCop, guards, and dogfood pass; no push.

## 2026-07-20T01:34Z resolve docs-goal-backlog-retirement
Outcome: Deleted the stale 0.5.1 autonomous goal backlog and rerouted AGENTS, the operator playbook, and its focused test to trk status and .trk/STATE.md; static authority review and focused verification passed. Pre-existing Demeter documentation links remain for their own slice; no push.

## 2026-07-20T03:34Z log
2026-07-20 handoff: goal-backlog retirement is staged but uncommitted. Deleted .claude/guides/goal-backlog.md; routed AGENTS.md and operator playbook to trk status/.trk/STATE.md; updated agent workspace docs test; appended implementation note. Focused docs test, RuboCop, dependency direction, sample freeze, tracker queue, and dogfood passed. Markdown audit still reports the pre-existing two broken rubocop-metz/docs/demeter-design.md links. bundle exec rake timed out twice at 180s and 240s; hard-stop: diagnose before a third run or commit. main is pushed at 987d887 and CI run 29710718431 passed; do not push this slice.

## 2026-07-20T03:46Z resolve docs-goal-backlog-retirement
Outcome: Deleted the stale goal backlog and rerouted executor guidance to trk status/.trk/STATE.md; focused docs test, full rake (685 runs, 3262 assertions, 0 failures, 0 errors, 2 skips), RuboCop, dogfood, dependency-direction, sample-freeze, read-only, and tracker-queue checks pass. Individual slow-test diagnostics explained the earlier timeout uncertainty; no push.

## 2026-07-20T06:23Z log
2026-07-20 TestCallsPrivateMethod dogfood: Mastodon 13 findings/3 files, OpenFoodNetwork 22/3, Forem 60/5; reviewed calls matched private production declarations and no false-positive category appeared. Keep candidate-only; active calibration lacks a substantial Minitest target, and Discourse/Rails index runs exceeded bounded review windows. Next item remains open for Minitest evidence.

## 2026-07-20T15:21Z log
2026-07-20 TestCallsPrivateMethod dogfood complete: RSpec targets Mastodon 13, OpenFoodNetwork 22, Forem 60; Minitest targets Rails Action Pack 9, Active Record 11, Active Support 0. Source spot checks found no false-positive category. Keep candidate-only; next assess remaining testing-cops rollout and likely drop TestTooManyAssertions.

## 2026-07-20T15:33Z log
2026-07-20 rollout assessment: drop TestTooManyAssertions. RSpec/MultipleExpectations and Minitest/MultipleAssertions already provide configurable assertion-count checks; no Metz duplicate adds novel signal. Next: assess the next product slice before implementation.

## 2026-07-20T15:42Z log
--help

## 2026-07-20T16:15Z log
2026-07-20 assessment: rejected test_depends_on_unowned_return as too semantic for current AST/index surfaces; rejected R3 trivial CRUD and R4 fat operation body as false-positive/overlap risks. Next bounded slice is a fixed-sample precision study for operation directory density.

## 2026-07-20T16:15Z log
Correction: a help probe earlier created an inert '--help' tracker log entry; it changed no goal, next item, dispatch, or backlog state.

## 2026-07-20T16:18Z log
2026-07-20 fixed-sample operation-role study: 48 service files across Forem, Foreman, Chatwoot, Discourse, OpenFoodNetwork, and Mastodon classified as 16 operations, 8 adapters/integrations, 9 queries/readers, 1 presenter/serializer, 11 utilities/value objects, and 3 infrastructure/framework files. app/services is a mixed bucket; path-based OperationDirectoryDensity is not defensible. Defer P2 implementation.

## 2026-07-20T21:59Z log
2026-07-20: Measured a generic operation-role shape classifier on a fixed 42-file sample across nine existing calibration targets. One public entry + side-effect + two receiver roots produced 9 TP, 1 FP, 1 FN, 31 TN (90.0% precision/recall; 95.2% accuracy). AddressGeocoder was the adapter false positive; Discourse UpcomingChanges::Track was the Service::Base DSL false negative. Keep OperationDirectoryDensity deferred; no production code, thresholds, statuses, suppressions, or new targets changed.

## 2026-07-24T13:45Z log
Professionalism sprint: public-surface polish (badges, CONTRIBUTING/SECURITY, issue templates, docs/maintainers relocation, GitHub topics; closed #25/#27/#28 earlier). Uncommitted work landing now.

## 2026-07-24T13:45Z log
Dropped backlog slugs for closed issues #25/#27/#28 (reopen bars live in issue comments + LOG parking notes).

## 2026-08-11T01:17Z log
Reviewed RuboCop 1.89 (metaredux post + gem source): native opt-in rubydex project index via Cop::Base#project_index, experimental. Verified rubocop-metz compatible with 1.89 in sandbox and rubydex 0.2.8 API-compatible. Queued upgrade + README positioning slices; parked cop-migration watch item as rubocop-native-project-index-migration.

## 2026-08-11T01:29Z resolve rubocop-1-89
Outcome: RuboCop 1.89.0 landed: Gemfile.lock + 4 Layout/MultilineMethodCallIndentation fixes; rake/rubocop/dogfood/guards green; no suppressions

## 2026-08-11T01:29Z log
Upgrade RuboCop 1.88.2 → 1.89.0 (lockfile only pin already ~> 1.80). Fixed 4 Layout/MultilineMethodCallIndentation offenses in inheritance_descendants, namespace_leak_pressure, package_dependency_pressure, method_declarations — no suppressions. Verified: bundle exec rake (685 runs), bundle exec rubocop clean, bin/check_dogfood PASS, guards green. Transitive: json 2.20→2.21.2, parser 3.3.11.1→3.3.12.0.

## 2026-08-11T02:44Z log
CI_PARITY_FULL env leak: nested check_ci_parity meta-test failed under full override because child inherited CI_PARITY_FULL. Fixed by unsetting it in CLEAN_BUNDLER_ENV (clone mirrors CI) and test ci_env (fixture isolation).

## 2026-08-24T23:33Z log
Fix #41: Dependabot bundler updater failed gemspec eval because the packaged-files entrypoint raise fired in Dependabot's sparse temp tree (version.rb only). Removed the raise from both gemspecs; kept __dir__+base: packaging; added gemspec_dependabot_eval_test sparse-tree regression.

## 2026-09-03T23:40Z log
Upgrade RuboCop 1.89.0 → 1.90.0 (lockfile only; gemspec pin already ~> 1.80). Confirmed against installed 1.90: only 3 Style/DirectiveScope offenses (disable/enable pairs around one statement). Autocorrected to disable-next in type_inference.rb, views_deep_navigation.rb, and type_inference_test.rb; kept the UselessMethodDefinition justification. No Style/DirectiveScope config disable, no cop behavior change. bundle update rubocop left rubocop-metz (~> 0.5.3) intact (Dependabot #43 rewrote it to =). rubydex 0.4.0 pin unchanged. Not a redesign.

## 2026-09-03T23:40Z resolve rubocop-1-90
Outcome: RuboCop 1.90.0 landed: Gemfile.lock + 3 Style/DirectiveScope disable-next conversions; no suppressions. Supersedes Dependabot #43.

## 2026-09-15T22:38Z log
Bump optional rubydex group ~> 0.4.0 → ~> 0.4.1 (Gemfile + Gemfile.lock DEPENDENCIES pin; lock already at 0.4.1 with x86_64-linux platform). No adapter change — configure_for_workspace unchanged. Supersedes Dependabot #46 (which rewrote rubocop-metz to =). CI still omits BUNDLE_WITH=rubydex.

## 2026-09-16T23:59Z log
Upgrade RuboCop 1.90.0 → 1.91.0 (lockfile only; gemspec pin already ~> 1.80). bundle update rubocop --conservative: only rubocop moved; json 2.21.2 and parallel 2.1.0 left in place (plain bundle update rubocop also pulls json 3.0.2 / parallel 2.2.0, but 1.91 still accepts json >= 2.3 and parallel >= 1.10). rubocop-metz (~> 0.5.3) intact (Dependabot #48 rewrote it to =). Installed 1.91.0 reported 0 offenses; no style edits, no suppressions, no cop behavior change.

## 2026-09-16T23:59Z resolve rubocop-1-91
Outcome: RuboCop 1.91.0 landed lockfile-only; rubocop-metz ~> pin preserved. Supersedes Dependabot #48.

## 2026-10-01T15:32Z log
Agent-facing direction (owner, 2026-10-01): the main use is now a coding agent writes Ruby, then runs metz-scan at END of task (not continuously), scoped to what it changed, fixes its own findings, reruns to confirm. Rewrote skills/metz-scan/SKILL.md from scratch around that loop (Fable draft via planner; claims verified by running the CLI in scratch projects; doc-reviewer pass applied). Owner rule: inline `rubocop:disable Metz/*` and `.rubocop.yml` Excludes need a written justification comment at the site and are reported in the handoff. Verified facts behind the queued slices: (1) usage errors (no PATH, missing path, bad option, bad --format) exit 1 like findings; only RuboCop runner failure exits 2 (lib/metz_scan/commands/scan.rb). (2) A file passed to scan by name bypasses AllCops: Exclude; directory scans honor it; project analyzers only see passed paths (RepeatedBranching is cross-file). (3) Inline disables (with or without `-- reason`) hide findings; default scan ignores `Max` in .rubocop.yml but honors per-cop Exclude. (4) JSON offenses already carry why_it_matters, fix_safety, suggested_next_moves; no Metz cop autocorrects. Tool-side options weighed (Fable): suppression ledger = deterministic, zero false positives, recommended first; --changed-since only if dogfooding shows agents mis-scope; split heuristics parked. Feature and contract slices follow AOP spec-test separation: a separate session on a different model writes spec tests, owner approves, then implement.

## 2026-10-01T15:49Z log
Docs drift slice (Next 1) landed, docs only. Verified in a scratch project outside the repo (RuboCop 1.91.0, 8-line method vs stock Metz/MethodsTooLong Max 5): default scan ignores project Max (raised and lowered), Enabled: false, Enabled: true on opt-in cops, department Metz: Enabled: false, AllCops: DisabledByDefault, a nested-directory Enabled: false, and Severity (JSON stays refactor), all with no stderr warning; it honors AllCops: Exclude, per-cop Exclude (exact path and test/**/* glob), and inline disables. --all-cops and plain rubocop with plugins: [rubocop-metz] honor Max, Enabled, and Severity. Intended design per DDR 2026-07-08, so no code finding; the silent ignore (no warning) is a UX gap, not fixed. Rewrote README Configuration (file scope + TargetRubyVersion read by default; other cop settings only under --all-cops or plain rubocop), docs/faq.md threshold and suppression advice, SKILL.md suppression bullets, and added a current-behavior note to the historical metz_scan_design.md example. README:66 now says nine project analyzers, two in default output. Unverified, code-inferred: AllowedReceivers ignored in default scan (same --force-default-config path); per-cop Include can only narrow stock scope in default mode; under --all-cops a project per-cop Exclude replaces a cop's stock Exclude (doc-reviewer observed it for DemeterTrainWreck spec/**), not documented.

## 2026-10-02T00:32Z log
Fixed default scan ignoring top-level inherit_mode: merge for per-cop Exclude (owner-reported 2026-10-01; queued as Next 1 on spec/suppression-ledger in 9bf0e42, not yet on main, so no Next item is closed here). Root cause: ProjectConfigScope::ConfigLoader#scope_hash and #inherited_scope_hash merged with RuboCop::ConfigLoader.merge(a, b), which calls ConfigLoaderResolver#merge without inherit_mode:, so should_union? never saw the inheriting file's inherit_mode and the local per-cop Exclude replaced the inherited one. Fix calls ConfigLoaderResolver#merge with inherit_mode: set to the inheriting file's top-level inherit_mode, for both local-over-inherited and sibling inherit_from merges, matching resolve_inheritance. Verified parity with rubocop for 1-level, 2-level chain (mode in leaf), siblings, and no-inherit_mode cases. Remaining gaps parked as scope-loader-inherit-mode-gaps.

## 2026-10-01T23:58Z log
Suppression ledger contract approved by owner (Option 1, hidden findings). Supersedes the Next-item sketch. Records = one per finding a suppression hid in this scan; default scan only (JSON key absent under --all-cops/--auto-fix); exit code, offense_count and compliance unaffected. JSON: top-level suppressions array (always present in default mode) sorted by path/line/column/cop_name, fields cop_name, path, line, column, message, suppressed_by (inline_disable|config_exclude), reason, reason_status (present|missing|unchecked), directive {line}, config {path, line, pattern}. Text: 'Suppressed findings: N, M without a reason' section between offense blocks and Summary, omitted when empty. SARIF/gh-annotations unchanged. Inline: only real comment directives (not synthetic opt-in coverage), innermost covering directive's -- reason, empty -- = missing. Exclude: the applied per-cop entry mapped to its source file; reason from entry trailing comment, comment block above entry, Exclude: trailing comment, comment block above Exclude: (first wins); ERB configs read rendered text with config.line null; unlocatable entries (YAML alias) = unchecked. Inline+Exclude = one config_exclude record. MetzProject/* and AllCops Exclude out. Spec tests (red, uncommitted at time of writing): test/metz_scan/commands/scan_suppression_ledger_test.rb on branch spec/suppression-ledger. Spec-session derivations not owner-worded: reason phrases 'reason: X' / 'no reason' / 'reason not checked', config line omitted from text when null, ', 0 without a reason' always printed, unchecked excluded from the without-reason count.

## 2026-10-02T00:00Z log
Owner approved the spec-session text wordings for the suppression ledger: reason phrases 'reason: X' / 'no reason' / 'reason not checked'; config line omitted from text when null; ', N without a reason' always printed (including 0); unchecked entries excluded from that count. RuboCop 1.91 push/pop/todo-next directives are out of scope until dogfooding shows them in use.

## 2026-10-02T04:04Z log
Suppression ledger (Next 1) implemented to the 21 owner-pinned spec tests (unchanged; red 21/21 -> green). Owner decisions this session: design option C (single RuboCop pass with --display-suppressed in default mode only, plus Exclude provenance tracked inside the existing ProjectConfigScope loader by raw-entry object identity) over a second --ignore-disable-comments pass (+1.5s cold on this repo, no Exclude coverage); rubocop pin ~> 1.80 -> ~> 1.90 (--display-suppressed, Offense#justification, DirectiveRange first ship in 1.90; reviewer confirmed against unpacked 1.90.0). SuppressionLedger replaces ProjectCopScope.honor: config Exclude wins over inline, synthetic -Infinity directive ranges credit nothing, suppressed offenses never reach files/offense_count/exit code; invalid project config falls back to no config scoping but still strips inline-suppressed offenses (new red-green test in scan_error_test.rb). Regexp Exclude entries report their /regexp/ text, reason unchecked (red-green test). Reviewer parity probe: hidden-offense sets identical to HEAD on 14 projects. Warm scan time unchanged (~3.2s). Self-scan now lists 114 config_exclude records, all no reason, line null (ERB .rubocop.yml test-tree excludes). Known, documented: per-cop Include narrowing hides findings with no record; inherit_mode merge duplicate pattern credits the base file; ERB configs are re-rendered by the locator.

## 2026-10-02T16:58Z log
docs: maintainer-doc drift pass (2026-10-02 doc review) — orient with `trk status` (--json omits goal and Next); CLAUDE.md lists TestCallsPrivateMethod as index-backed, renderers and docs-enforcing tests corrected; land-slice/release push only when authorized, tracker writes are the orchestrator's; release skill drops the stale gemspec line number and version-pin list; playbook commit style is Conventional Commits.

## 2026-10-03T00:37Z log
Pre-merge Fable review: playbook commit style corrected; issue refs go in the body, and the trailing (#NN) on older subjects is the PR number GitHub adds on squash-merge.
## 2026-10-02T16:25Z log
Agent-loop dogfood round 1 (Claude Sonnet, lobsters, current main): agent passed scan-at-end, fixed-not-gamed, handoff; no suppressions. F1: skill step 3 overlap rule and message-based base compare both misattribute pre-existing findings in touched code (method 27/5 -> 18/5, class 1095 -> 1098). F2: JSON size did not reach agent context (filtered with Python); skill text was the largest cost. Owner decisions: fix F1 in skill text, then a Codex round; --changed-since demoted to backlog because it filters by file and does not address F1. Added the agent-loop variant to the dogfood-round skill.

## 2026-10-03T00:37Z log
Pre-merge Fable review: dogfood-round agent variant now says the throwaway target copy lives outside this repo; .rubocop.yml excludes tmp/, so an in-repo copy scans zero files.
## 2026-10-02T17:10Z log
F1 fixed in skills/metz-scan/SKILL.md step 3 (skill text only): for the size cops (MethodsTooLong, ClassesTooLong, MethodsTooManyParameters, DemeterTrainWreck, ViewsDeepNavigation) the base scan decides, matching on path suffix + cop_name + message with numbers removed + the start_line source line; paired findings are pre-existing and reported as grew/shrank/unchanged. Base scan uses step 1's paths; every block using $out defines it; step 5's fixed test uses the same key. Matching design from a Fable advisor consult, checked against the cop message formats. Skill test pins the new wording.

## 2026-10-03T00:37Z log
Pre-merge Fable review of F1 step 3: the parameter and chain cops locate on the line the agent edits, so a whole-line key made a trimmed parameter list or edited chain look new. Key anchor is now the method, class, or constant name for the length and parameter cops (chain cops keep the stripped line), base-scan path prefix stripping is explicit, and the rename/edited-chain gap is stated.
## 2026-10-02T16:16Z log
Usage errors now exit 64 (sysexits EX_USAGE) across the whole CLI (owner chose 64 and whole-CLI scope 2026-10-02): scan, report, explain, rules, bare/unknown subcommand. Exit 1 stays findings, 2 RuboCop failure. Spec tests written first by a Sonnet worker. Also fixes rules --bogus crashing with an uncaught OptionParser::InvalidOption. Report usage-error tests moved to report_validation_test.rb (mirrors scan_validation_test.rb) to keep ReportTest under Metz/ClassesTooLong. Dropped backlog scope-loader-ruby-version-file (could not reproduce).

## 2026-10-02T17:08Z log
Exit-64 contract completed on fix/usage-error-exit-code: explain and project-analyzers now exit 64 on an invalid option (explain previously stack-traced, project-analyzers exited 1), and scan validates --format under --auto-fix instead of silently ignoring it. Gaps found in the 2026-10-02 doc review; spec tests written first by a separate model (Sonnet), fix by Opus; Fable advisor recommended finishing here rather than narrowing the PR claim.

## 2026-10-03T00:26Z log
Pre-merge Fable review follow-up on fix/usage-error-exit-code: removed the unreachable CLI stub_subcommand (the last literal exit 1 outside findings; every listed subcommand has a handler) and listed invalid report JSON among README's exit-64 cases.
