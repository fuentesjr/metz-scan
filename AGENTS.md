# AGENTS

Entrypoint for OpenAI/Codex sessions (and any non-Claude agent) working in
this repo. Claude Code sessions load `CLAUDE.md` automatically and can skip
the first section.

## Orientation — read these next, in order

1. `CLAUDE.md` — despite the name, this is the **canonical shared workspace
   brief for every agent**: architecture, commands, invariants, failure modes,
   quality bar, escalation rules, and review criteria live there, once. Do not
   duplicate its content here; if it conflicts with this file, `CLAUDE.md`
   wins except for the OpenAI-specific sections below.
2. `PROJECT_TRACKER.md` — current direction, Next Queue, parked work, standing
   rules. Orient here before deciding any work. Run `bin/check_ci_parity`
   before any push.
3. `.claude/guides/operator-playbook.md` — mandatory for executor models
   before touching code (session-start ritual, hard stops, trap table).

Repo skills follow the open Agent Skills standard and are discoverable at
`.agents/skills` (a symlink to the canonical `.claude/skills`): `land-slice`
(verify + commit a slice), `release` (GitHub Packages runbook),
`dogfood-round` (output-quality rubric), `extract-approach` (learning notes).
Goal backlog for bounded autonomous runs: `.claude/guides/goal-backlog.md` —
paste a goal's text as your prompt.

## OpenAI docs instruction

Always use the OpenAI developer documentation MCP server when working with the
OpenAI API, ChatGPT Apps SDK, Codex, or related OpenAI platform features.

## Metz cop safe-navigation invariant

Metz cops that define `on_send` are expected to handle `csend` the same way.
Metz cops should include `RuboCop::Cop::Metz::OnSendCsendBridge` directly.

## Project analyzer calibration fixtures

Use `tmp/project-analyzer-calibration/apps` as the active home for project
analyzer calibration fixtures. Treat `/private/tmp` calibration paths as
historical notes only unless the user explicitly asks to restore or compare old
artifacts.

## Completion summaries

When the user asks for a "detailed and comprehensive summary," summarize the
completed work with clear sections, concrete evidence, and enough detail for a
future agent to resume without re-discovering context.

For autonomous repo work, include commit hash and message, tasks completed, key
implementation changes, agenticons used if any, calibration or evidence results
when relevant, tests and validation results, review findings, docs or notes updated,
residual risks or deferred work, working-tree status, and whether anything was
pushed.
