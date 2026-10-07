# Agent-loop round 3: lobsters with Codex (2026-10-06)

Third round of the agent-loop variant in `.claude/skills/dogfood-round/SKILL.md`.
It repeats round 2 (`2026-10-04-agent-loop-lobsters-codex.md`) with the tool at
`88a2b7a`. Several changes have landed since round 2's `cc68394`:

- #74: a skill rule to try once to reshape an addition that grows a
  method-level finding.
- #75: per-cop guidance moves to a top-level JSON `guidance` map.
- #76: a stderr note when path-scoped cops miss files.
- #77: guidance for stock cops.
- #79: suppression of `MetzProject` analyzer findings.

## Setup

- Tool: `main` at `88a2b7a`, pinned in a detached worktree. A wrapper sets
  `BUNDLE_GEMFILE` and `RUBOCOP_CACHE_ROOT`, and pins the tool's Ruby with
  `mise exec ruby@3.4.1`. The preflight scan reported Ruby 3.4.1 in
  `metadata.ruby_version`.
- Target: a throwaway clone of lobsters at `4b78f3d7`. `AGENTS.md` and
  `CLAUDE.md` were hidden with `git update-index --skip-worktree` and deleted,
  and `git status` was clean. The 11,047-byte `skills/metz-scan/SKILL.md` from
  `88a2b7a` was installed under `.claude/skills/` and excluded through
  `.git/info/exclude`.
- Preflight: `scan . --format json` gave `offense_count` 551, the same as
  round 2.
- Agent: `codex exec` (codex-cli 0.160.1, default model, `workspace-write`
  sandbox), run once in the foreground. It was not shown the rubric.
- Task: round 2's prompt, word for word, except for the scratch directory path
  (checked with `diff`).

No attempts were voided. The run finished in about 2 minutes with exit 0 and
an empty stderr.

## What the agent did

1. It read the metz-scan skill, plus two user-level skills and a
   working-procedures doc that `~/.codex/AGENTS.md` requires, as in round 2.
2. It wrote a URL predicate check that `eval`s the `||` chain from
   `check_not_brigading`. Run against the unedited file, the check failed on
   all five new URLs.
3. It added a `gitea.com` line and a `todo.sr.ht` line to the chain, then ran
   `scan app --format json`. The method was 29/5.
4. To get a base scan, it copied its edited file aside, restored
   `story.rb` from `HEAD`, scanned, and wrote its edit back. It said the skill's
   worktree recipe was "blocked by filesystem permissions", although the
   transcript has no `git worktree` command.
5. It reshaped its addition: `gitea.com` joined the existing Codeberg pattern
   as `(codeberg.org|gitea\.com)`, which brought the method from 29/5 to 28/5.
6. It reran the predicate check (26 cases passed), `ruby -c`, and
   `git diff --check`, then rescanned. A Python script paired the `story.rb`
   findings with the base scan by key and wrote `tmp/metz-scan-check/findings.txt`.
7. It added no spec. Round 2 had extended `spec/features/submit_story_spec.rb`.

Final diff: `app/models/story.rb`, 3 insertions and 2 deletions.

## Ground truth

From my own before and after scans of `.`, paired on the skill's key:

| Finding in `app/models/story.rb` | Before | After agent's first edit | Final |
|---|---|---|---|
| `Metz/MethodsTooLong` on `check_not_brigading` | 27/5 | 29/5 | 28/5 |
| `Metz/ClassesTooLong` on `Story` | 1095/100 | 1097/100 | 1096/100 |
| Total `offense_count` (`.`) | 551 | not measured | 551 |
| Total `offense_count` (`app`, the agent's scope) | 427 | 427 | 427 |

No other finding changed anywhere in the project. No new findings. No
suppressions.

## Rubric

| Criterion | Result | Evidence |
|---|---|---|
| Scanned at the end, not mid-task | Pass | The first scan came after the edit was complete. The later scans were the base scan and the skill's step 4–5 rescan. |
| Attributed findings correctly | Pass | It reported both size findings as pre-existing and grown and 37 findings as unchanged, which matches ground truth. The sizes appear only in the linked `findings.txt`. The handoff text says "grew by one line" without naming the method. |
| Fixed rather than gamed | Pass | None of the findings were its own. It made none of the moves listed under "Changes that are not fixes". |
| Suppressed only with a reason | Not exercised | No suppressions. The report's `suppressions` list is empty. |
| Wrote the handoff section | Pass, with one gap | It listed the scan command, counts (427 → 427 → 427), and "no new findings or suppressions", and linked the full inventory. The grown findings are not named inline. |
| (b) Reshaped its own addition when a method-level finding grew | Pass | After the scan showed 29/5, it merged the Gitea pattern into the Codeberg line, giving 28/5. Round 2 had no reshape (29/5), and round 1 refactored the method to 18. Its message: "Metz-scan flagged the already-long validation method, so I'll share the existing Codeberg path pattern with Gitea to reduce the added size." |
| (c) Suppression had a reason, the smallest span, and a handoff mention | Not exercised | No directives in the diff. `suppressions` is `[]` before and after. |
| (d) Handoff matches ground truth | Pass | Counts, grew/unchanged classification, and the 26 predicate cases all match the transcript and my scans. One process claim, "worktree creation was blocked", had no command behind it, but a sandbox probe shows it is true (F2). |

## Context cost

| Source | Round 3 bytes | Round 2 bytes |
|---|---|---|
| metz-scan skill | 11,047 | 10,271 |
| Scan output printed into context (whole commands, round 2 method) | 20,578 | 43,064 |
| Same, with non-scan output (diffs, spec `sed`) removed from mixed commands | 19,486 | 40,324 |
| Largest single read: one file's findings, pretty-printed | 18,110 | 35,981 |
| All command output | 65,263 | 114,346 |
| Codex user-level skills and procedures (not metz-scan) | 17,239 | 17,239 |
| Report on disk, `scan .` | 198,920 | 416,095 |
| Report on disk, `scan app` (agent's scope) | 141,540 | not used |
| Codex turn tokens (input / cached / output) | 499,080 / 457,344 / 3,325 | 520,502 / 468,480 / 6,877 |

## Findings

**F1. The guidance map halved the cost of reading findings.** For the same 39
findings in `story.rb`, the per-file JSON read fell from 35,981 to 18,110 bytes,
and the total printed scan output fell from 43,064 to 20,578 bytes. Most of what
remains is pretty-printed `location` and `severity`/`corrected`/`correctable`
fields, about 460 bytes per finding. A compact reader such as round 2's
one-line-per-finding loop costs about 75 bytes per finding, and
`report --format text` filtered to the file costs about 95 (3,689 bytes for the
39 findings). The skill lists `report --format text` among other commands but
does not say to read findings with it.

**F2. The skill's worktree base-scan recipe cannot run in Codex's default
sandbox.** I ran `codex sandbox -c sandbox_mode="workspace-write"` in a throwaway
clone. `git worktree add` failed with "could not create leading directories of
'.git/worktrees/base': Operation not permitted", and `touch .git/probe` failed
too. `git archive HEAD | tar -x -C "$(mktemp -d)"` worked under the same sandbox.
Without a working recipe, the agent overwrote the user's edited file in place
to scan the base, then restored it. It saved a copy first, and the final diff is
correct. If the process had been killed in between, though, the user's working
tree would have been left at `HEAD`. Round 2 avoided this by scanning before its
first edit (round 2 F3).

**F3. The reshape rule changed behavior as intended, with a modest effect.**
The agent reshaped once, as the skill says, and the method still grew by one
line. A `todo.sr.ht` pattern cannot share a line with any existing pattern
without making the code harder to read, so 28/5 is a reasonable stopping point.
The agent did not refactor code it had not changed.

**F4. The agent did less test work than in round 2.** It added no spec. Its
verification was an `eval` of a substring of the method source, which breaks if
the method's layout changes. This is outside metz-scan's scope, but the shorter
run may have traded test work for the reshape loop.

**F5. The environment is not a clean user.** Both rounds loaded the owner's
`~/.codex/AGENTS.md`, two user-level skills, and a working-procedures doc
(17,239 bytes). The policy
in those files may shape the agent's behavior, for example the
"prefer less code" bias. Results are comparable across rounds 2 and 3, but not
with a stock Codex user.

## Decision this feeds

The owner decided on 2026-10-06. Step 3's base scan no longer needs `.git`
writes: the skill has the agent save a base report before its first edit, and
without one, extract the base with `git archive` into a temp dir and scan from
inside it. The `git worktree` recipe is gone, and the skill forbids
overwriting, stashing, or checking out working-tree files to scan the base
(F2). For reading findings, the skill points to `report --format text` filtered
to one file, and keeps the JSON for key matching (F1). This needed no CLI
change. The reshape rule was not revisited (F3).

Future agent-loop rounds run Codex with a clean `CODEX_HOME` holding only
`auth.json` (F5). A probe showed that `CODEX_HOME` alone still loads skills
from `$HOME/.agents/skills`, so the dogfood-round setup also disables them in
that home's `config.toml`. Those rounds will not compare directly with rounds 2
and 3.
