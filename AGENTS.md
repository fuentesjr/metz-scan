# AGENTS

## OpenAI docs instruction

Always use the OpenAI developer documentation MCP server when working with the OpenAI API, ChatGPT Apps SDK, Codex, or related OpenAI platform features.

## Metz cop invariant

Metz cops that define `on_send` are expected to handle `csend` as well. This invariant is currently implemented by `RuboCop::Cop::Metz::Base`.
