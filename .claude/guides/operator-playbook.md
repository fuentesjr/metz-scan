# Operator playbook (executor models — Claude or OpenAI)

How an executor model (Claude Opus/Sonnet/Haiku, or a GPT/Codex session) uses
this workspace safely. Read this, then `CLAUDE.md` (the canonical shared brief,
whichever harness you run in), then `trk status --json` / `.trk/STATE.md` — in
that order — before touching code.

Harness note: Claude Code auto-discovers the repo skills from
`.claude/skills/`; Codex discovers the same skills through the
`.agents/skills` symlink and reads `AGENTS.md` for its entrypoint. "Use the
X skill" below means invoke it however your harness does (slash command,
`$`-mention, or reading the SKILL.md directly and following it).

## The contract

You are operating in a repo where the checks are stronger than you are. Do not
outsmart them; drive by them. Every gate here was added because a specific
failure happened. If a check fails, the check is right until proven otherwise
in a preserved clean clone.

## Session start (every session, ~5 minutes)

1. Run `trk status --json` and read `.trk/STATE.md` (Goal, Next, Backlog). Your
   task must map to a Next item, a filed issue, or an explicit user instruction.
   If it maps only to parked backlog, stop and tell the user — do not proceed.
2. Check `origin/main` CI: `gh run list --repo fuentesjr/metz-scan --branch main --limit 3`.
   Red main = your task changes to triaging the red run (standing rule).
3. Confirm a clean working tree (`git status`). Leftover changes are a signal
   to stop and ask, not to absorb.

## Pick the narrowest applicable skill — never freelance a workflow

| Situation | Use |
| --- | --- |
| Any change ready to verify/commit | the `land-slice` skill |
| Anything involving versions, tags, gem push | the `release` skill |
| Evaluating scan output on real codebases | the `dogfood-round` skill |
| Just solved something that took >1 attempt | the `extract-approach` skill |
| Executing a backlog goal | `.claude/guides/goal-backlog.md`, top item first |

The skills encode ordering (e.g. commit BEFORE `bin/check_ci_parity`, publish
`rubocop-metz` BEFORE `metz-scan`). Reordering steps because they "seem
independent" is the classic cheap-model failure here.

## Verification is the work

- Run the focused test file first (fast feedback), full gauntlet only when the
  change is complete. Command shapes are in CLAUDE.md "Commands".
- Red-green is mandatory for behavior changes: show the test failing for the
  right reason before the fix. If you cannot make it fail, you do not
  understand the bug yet — investigate, don't widen the change.
- Never loosen an assertion to make a test pass. Exact-output fixtures are
  exact on purpose. The correct move is updating the fixture file and saying
  so in the commit.
- When output text changes, expect a *cluster* of failures (exact fixtures +
  README freshness tests). Fix the cluster as a set; a lone green subset is
  not done.

## Hard stops — ask the user, do not proceed

- `gem push`, `git tag`, `gh release create`, filing/closing GitHub issues.
- Any edit that changes analyzer thresholds, analyzer status
  (candidate/validated/default), default-output policy, or adds suppressions.
- Adding/upgrading a dependency (including "just" a dev dependency).
- Editing `test/fixtures/sample_app/` (frozen fixture) unless the task
  explicitly requires it.
- Two failed attempts at the same problem. Stop and report: what you tried,
  what happened, best hypothesis, recommended next move. Do not try a third
  variation.

## Known traps, with the correct reaction

| Symptom | Correct reaction |
| --- | --- |
| `bin/check_ci_parity` fails but local suite is green | cd into the printed `clean clone preserved at` path, run the printed `next action:` command there. Cause is usually the optional `rubydex` group or an untracked file. Never "fix" by editing the parity script. |
| `check_sample_app_frozen` fails | You (or a subagent) touched the frozen fixture. Revert it, or if intended, regenerate `.frozen.sha256` in the same commit. |
| `check_tracker_queue` fails | Rewrite the top `.trk/STATE.md` Next items to be actionable — do not delete the check or pad with fake tasks. |
| `metz-scan scan` exits 1 | Findings were reported. Not an error. Exit >1 is an error. |
| `check_dogfood` fails after a cop edit | This repo now offends its own cop. Fix the repo code or reconsider the cop change; never add a suppression. |
| Tests can't find `rubocop/metz` | Missing load paths — use `-Ilib -Itest -Irubocop-metz/lib -Irubocop-metz/test`. |
| Scanning a fixture app prints nothing | Repo `.rubocop.yml` excludes fixture trees; copy the fixture to a mktemp dir first. |

## Committing

- One slice = one commit = code + tests + docs + tracker update together.
- Tracker-only commits are forbidden (exception: user-approved direction
  changes).
- Commit message shape follows history: imperative, ≤72-char subject, issue
  refs like `Fix #34: ...` (see `git log --oneline -20`).
- Push only after `bin/check_ci_parity` passes on the committed HEAD, and only
  if the user authorized pushing.

## Writing quality (enforced at review)

- No defensive `rescue`/nil-guards beyond what the code path needs.
- No comments restating code; comments explain why or cite a DDR/issue.
- No new abstraction without three concrete uses; the codebase prefers many
  small single-purpose files (see `lib/metz_scan/commands/scan/`) — follow
  that shape rather than inventing a new layer.
- Match double-quoted strings and `# frozen_string_literal: true` headers
  (RuboCop enforces both).

## When the task is bigger than you

If the task requires a design decision (new output policy, adoption path,
threshold philosophy) or spans analyzer behavior + policy + docs at once:
produce a short written proposal with options and stop. Escalating to the user
or a stronger model with a crisp decision request is success, not failure.
