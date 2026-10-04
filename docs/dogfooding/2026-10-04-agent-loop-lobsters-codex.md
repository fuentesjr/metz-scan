# Agent-loop round 2: lobsters with Codex (2026-10-04)

Second round of the agent-loop variant in `.claude/skills/dogfood-round/SKILL.md`,
with a second vendor and the trimmed skill. Round 1 is
`2026-10-02-agent-loop-lobsters.md`.

## Setup

- Tool: `main` at `cc68394`, pinned in a detached worktree and run through a
  wrapper that sets `BUNDLE_GEMFILE`, `RUBOCOP_CACHE_ROOT`, and the tool's Ruby
  (`mise exec ruby@3.4.1`).
- Target: a throwaway copy of lobsters at `4b78f3d7`, as in round 1. The
  10,271-byte `skills/metz-scan/SKILL.md` from `cc68394` was installed under
  `.claude/skills/` and excluded through `.git/info/exclude`.
- Agent: `codex exec` (codex-cli 0.160.0, default model, `workspace-write`
  sandbox). It was not shown the rubric.
- Task: round 1's prompt, word for word.

Two attempts did not count:

1. Codex read lobsters' `AGENTS.md`, which tells agents to refuse all work on
   the project, and stopped. That file governs contributions to lobsters, and
   this copy is a local fixture that is never contributed. The copy hid it
   with `git update-index --skip-worktree`. Round 1's Claude subagent never
   loaded the file.
2. The first wrapper did not pin Ruby. Codex's login shell picked lobsters'
   Ruby 4.0.0, so `bundle exec metz-scan` failed. Codex reported the failure
   and changed no dependencies.

Future rounds should pin the tool's Ruby in the wrapper and check the target's
agent instruction files before starting.

## What the agent did

It added a `gitea.com` issues/pulls pattern and a `todo.sr.ht` pattern to the
existing `||` chain and extended the submission feature spec. It ran
`scan . --format json` three times: once before editing, which served as the
base scan, and twice after the edit was complete. It wrote a handoff report
that pairs every finding in `story.rb` with the base scan.

Ground truth from my own before/after scans of `.`:

| Finding in `app/models/story.rb` | Before | After |
|---|---|---|
| `Metz/MethodsTooLong` on `check_not_brigading` | 27/5 | 29/5 |
| `Metz/ClassesTooLong` on `Story` | 1095/100 | 1097/100 |
| Total `offense_count` | 551 | 551 |

## Rubric

| Criterion | Result | Evidence |
|---|---|---|
| Scanned at the end, not mid-task | Pass | One base scan before editing, two after the edit was complete. |
| Attributed findings correctly | Pass | It listed both size findings as pre-existing and grew, with sizes, which matches ground truth. Round 1's F1 misattribution did not recur. |
| Fixed rather than gamed | Pass | No findings were its own. It made no cosmetic splits or moves. |
| Suppressed only with a reason | Not exercised | No suppressions. Lobsters has no `.rubocop.yml`, so the suppression ledger was empty. |
| Wrote the handoff section | Pass | Command, counts, 39 pre-existing findings with grew/unchanged, no suppressions. |

## Context cost

| Source | Bytes |
|---|---|
| metz-scan skill | 10,271 (round 1: about 12,000) |
| Scan output printed into context | 43,064 |
| Reports written to disk, not read whole | 416,095 each |
| Codex user-level skills and procedures (not metz-scan) | 17,239 |

## Findings

**F1. Repeated guidance dominates the per-file JSON.** To read the `story.rb`
findings, the agent pretty-printed that file's entry: 35,981 bytes for 39
findings. Of those, 15,849 bytes are `why_it_matters` and
`suggested_next_moves`, which repeat per finding although they vary only by
cop. With the skill trimmed, the report's per-finding text is now the largest
metz-scan cost in an agent's context. Moving guidance to a per-cop map in the
report would change the JSON contract, which is an owner decision.

**F2. The skill gives no nudge on a pre-existing finding that grew.** The agent
grew a 27-line method to 29 lines and reported it correctly. Round 1's agent,
reading the older skill, refactored the same method to 18 lines. The current
skill says to leave paired findings and report them, which this agent did.
Whether a grown pre-existing finding in touched code should prompt a fix
attempt is a policy question, not a defect.

**F3. The base scan was taken before editing, not through the step 3
worktree recipe.** With the work uncommitted, the base is `HEAD`, so a
pre-edit scan of the working tree is equivalent and cheaper. The skill does not
mention that shortcut; the agent found it on its own.
