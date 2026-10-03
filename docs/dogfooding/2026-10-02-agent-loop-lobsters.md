# Agent-loop round: lobsters (2026-10-02)

First round of the agent-loop variant in `.claude/skills/dogfood-round/SKILL.md`.
It judges how a coding agent uses metz-scan on a real task, not only what the
tool prints.

## Setup

- Tool: current `main` at `ff37682`, run through a wrapper that sets
  `BUNDLE_GEMFILE` to this repo's Gemfile.
- Target: a throwaway copy of `tmp/project-analyzer-calibration/apps/lobsters`
  at `4b78f3d7` (no `.rubocop.yml`). `skills/metz-scan/SKILL.md` was installed
  under `.claude/skills/` and excluded through `.git/info/exclude`.
- Agent: one Claude Sonnet subagent. It was not shown the rubric.
- Task: extend the anti-brigading URL check in `Story#check_not_brigading`
  (`app/models/story.rb`) to SourceHut tickets and gitea.com issues and pulls.
  The method was already a `Metz/MethodsTooLong` offender at 27/5.

## What the agent did

It replaced the `||` chain of `url.match?` calls with a frozen
`BRIGADING_URL_PATTERNS` array and added the two patterns. It then ran the
end-of-task check, tried splitting the method into two helpers, saw two findings
replace one, reverted the split, and handed off. It ran `scan app lib --format
json` three times, every time after its edit was complete.

Ground truth from `git diff` and a before/after scan of `app lib`:

| Finding in `app/models/story.rb` | Before | After |
|---|---|---|
| `Metz/MethodsTooLong` on `check_not_brigading` | 27/5 | 18/5 |
| `Metz/ClassesTooLong` on `Story` | 1095/100 | 1098/100 |
| Total `offense_count` | 435 | 435 |

## Rubric

| Criterion | Result | Evidence |
|---|---|---|
| Scanned at the end, not mid-task | Pass | Three scans, all inside the skill's fix-and-rescan loop. |
| Attributed findings correctly | Pass, by judgment | It called both findings pre-existing, which is right. It took no base scan, so the claim was unverified, and the skill's own rules would have called both findings its own (see F1). |
| Fixed rather than gamed | Pass | It rejected a split that only moved lines, as the skill's "harder to read" stop says. |
| Suppressed only with a reason | Not exercised | No suppressions were added. |
| Wrote the handoff section | Pass | Command, counts, pre-existing findings, and no suppressions. |

## Findings

**F1. The skill's attribution rules misattribute a pre-existing finding in
touched code.** Both findings above overlap changed lines, so step 3's overlap
rule calls them the agent's. The documented fallback, which compares the base
scan on path, `cop_name`, and `message`, does the same: the size is in the
message (`[27/5]` becomes `[18/5]`), so the improved finding looks new. A
before/after compare on those keys reproduced this. An agent that follows the
skill literally would try to fix a 1098-line class to finish a two-pattern
change. The agent here ignored the rule and was right, but it could not tell
that it had improved the method.

**F2. JSON size did not reach the agent's context in this round.** The agent
saved each report to a file and printed only `summary.offense_count` and the
`story.rb` findings with Python. Each report was 315,400 bytes. The largest
metz-scan cost in context was reading the skill, 12,000 bytes. Lobsters has no
config `Exclude`, so the suppression ledger was empty and its size went
untested.

## Decision this feeds

`--changed-since` as specified in Next filters by changed file, which does not
address F1: the misattribution happens inside a changed file. The narrower fix
is attribution that ignores the `[n/max]` size when matching a base finding and
reports whether a touched pre-existing finding got larger or smaller. Whether
that belongs in the skill text or the CLI is an owner decision. This round used
one vendor; Next asked for two.
