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
