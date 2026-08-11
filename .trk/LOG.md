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
