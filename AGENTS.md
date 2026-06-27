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
