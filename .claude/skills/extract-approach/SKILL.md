---
name: extract-approach
description: "After solving a non-trivial problem in this repo, capture the transferable approach as a short learning note under docs/approaches/. Use when a fix required more than one attempt, a non-obvious root cause, a technique future agents would re-derive expensively, or when the user says 'write this up' / 'capture this'."
---

# Extract the approach

Turn a solved problem into a note a future (possibly cheaper) agent can apply
without re-deriving it. The note captures the *approach* — the diagnostic path
and the generalizable technique — not a diary of the session.

## Trigger test (all answers checkable — skip the note if none apply)

Write a note only if at least one is true:

1. The first attempted fix was wrong or incomplete (≥2 distinct approaches
   tried).
2. The root cause was in a different file/layer than the symptom (e.g. #33:
   symptom was redmine `Lint/Syntax` noise; cause was `--force-default-config`
   in `lib/metz_scan/commands/scan/runner.rb`).
3. The solution used a technique not already documented in CLAUDE.md, a skill,
   or an existing `docs/approaches/` note.
4. Diagnosis took more tool calls than the fix itself.

If the learning is "this repo has gate X" and CLAUDE.md doesn't mention gate X,
update CLAUDE.md instead of writing a note — CLAUDE.md is loaded every session,
notes are not.

## Write the note

Path: `docs/approaches/YYYY-MM-DD-<kebab-slug>.md` (create the directory on
first use). Hard cap: 40 lines. Template:

```markdown
# <One-line statement of the problem class>

Solved: YYYY-MM-DD, commit `<hash>`, issue #<n> if any.

## Symptom
<What was observable, exactly. Error text, wrong output, failing check name.>

## Root cause
<file:line and the mechanism, one short paragraph.>

## Approach that worked
<Numbered diagnostic/fix steps, each concrete enough to re-execute.>

## Dead ends (only if any)
<Approach tried → why it failed, one line each.>

## Reusable rule
<One sentence a future agent should apply when they see this symptom class.>
```

Rules:

- Facts only in Symptom/Root cause; the recommendation lives in Reusable rule.
- Cite files as `path:line` and commits by hash — no "the runner" shorthand.
- No restating what the diff shows; link the commit instead.

## Land it

- Commit the note **with the slice that solved the problem** (or the very next
  slice) — never as a standalone docs commit; the tracker standing rule
  forbids docs-only churn.
- If the note's Reusable rule contradicts or extends CLAUDE.md's "Failure
  modes" section, update that section in the same commit and keep the note as
  the detailed record.
- Before writing, `ls docs/approaches/` and grep for the symptom — extend an
  existing note rather than duplicating it.
