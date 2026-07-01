# AGENTS

## OpenAI docs instruction

Always use the OpenAI developer documentation MCP server when working with the OpenAI API, ChatGPT Apps SDK, Codex, or related OpenAI platform features.

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
