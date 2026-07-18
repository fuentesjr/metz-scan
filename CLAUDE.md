# Claude Code project notes

Orient from `trk status --json` / `.trk/STATE.md` first — they hold the current
goal, Next steps, and backlog (including parked work). Work tracking is written
through the `trk` CLI; see `AGENTS.md`. Standing process rules below still
govern slice discipline. Run `bin/check_ci_parity` before any push.

Repo skills (canonical in `.claude/skills/`, mirrored for OpenAI/Codex via the
`.agents/skills` symlink): `land-slice` (finish + verify + commit a slice),
`release` (GitHub Packages release runbook), `dogfood-round` (qualitative
dogfooding rubric), `extract-approach` (write a learning note after a
non-trivial fix). Executor models of any vendor: read
`.claude/guides/operator-playbook.md` before doing anything. This file is the
canonical shared brief for all agents; `AGENTS.md` is the OpenAI/Codex
entrypoint and points back here.

## Architecture (facts)

Two gems in one repo, strict dependency direction:

- `rubocop-metz/` — RuboCop plugin providing `Metz/*` cops
  (`rubocop-metz/lib/rubocop/cop/metz/`). Standalone; must never reference
  `MetzScan`/`metz_scan` (only its gemspec may). Enforced by
  `bin/check_dependency_direction`.
- `lib/metz_scan/` — the `metz-scan` CLI wrapper. Depends on `rubocop-metz`
  via `"~> #{MetzScan::VERSION}"` in `metz-scan.gemspec:31`, so version bumps
  auto-carry the pin.

Key paths:

- `lib/metz_scan/cli.rb` dispatches to `lib/metz_scan/commands/{scan,report,rules,explain,project_analyzers}.rb`.
- `lib/metz_scan/commands/scan/runner.rb` — default scan is Metz-only: it asks
  RuboCop for target files using the *project's* config (honoring
  `AllCops: Exclude`, per #33), then runs those files with
  `--force-default-config --only Metz`. `--all-cops` runs the full stock suite.
- Project analyzers live in `lib/metz_scan/analyzers/`. Two classes:
  AST-only (`service_soup.rb`, `repeated_branching.rb`,
  `implicit_context_pressure.rb`, `repeated_query_criteria.rb`) and
  Rubydex-index-backed (`inheritance_descendants.rb`,
  `package_dependency_pressure.rb`, `namespace_leak_pressure.rb`,
  `subclass_override_pressure.rb`) via `lib/metz_scan/project_index.rb`
  (`RubydexBackend` when the optional `rubydex` bundle group is installed,
  `NullBackend` otherwise — index-backed analyzers then silently contribute
  zero findings).
- Calibration pipeline: `lib/metz_scan/calibration/`, driven by
  `bin/check_project_analyzer_calibration`, with the tracked target manifest
  and baseline in `docs/calibration/project_analyzer_{targets,baseline}.yml`.
- Output renderers (text/json/sarif/gh-annotations) under
  `lib/metz_scan/commands/scan/*_renderer.rb`.

## Commands

```bash
bundle exec rake              # full suite (~546 runs as of 0.5.1)
bundle exec rake test:fast    # groups defined in test/support/test_file_groups.rb
bundle exec rake test:slow    # subprocess/integration tests
bundle exec rubocop           # repo lints itself with its own plugin
bin/check_ci_parity           # pre-push gate: runs a deliberate CI subset in a clean clone of the
                               # committed HEAD (docs-freshness tests for docs-only commits, `rake
                               # test:fast` for code commits); CI_PARITY_FULL=1 forces the full suite
bin/check_dependency_direction
bin/check_sample_app_frozen   # SHA-256 freeze gate on test/fixtures/sample_app
bin/check_read_only_commands  # runs read-only maintenance cmds under BUNDLE_FROZEN=1, fails on dirty tree
bin/check_tracker_queue       # fails if top-3 .trk/STATE.md Next items are all parked/watch-only
bin/check_dogfood             # metz-scan on this repo; requires rubydex group; zero findings required
```

Focused single test file (Rakefile load paths at `Rakefile:7`):

```bash
bundle exec ruby -Ilib -Itest -Irubocop-metz/lib -Irubocop-metz/test path/to_test.rb
```

Ruby >= 3.3, Bundler 4.0.8. CI is `.github/workflows/ci.yml`; `check_ci_parity`
replicates every single-command step plus tracker hygiene, but scales the
"tests" step to the commits being pushed (docs-only vs code) rather than
always running the full suite — remote CI stays the full-suite backstop; set
`CI_PARITY_FULL=1` to force the full local suite (do this before a release).

## Invariants and conventions (violating these fails a check or a review)

- Any Metz cop defining `on_send` must include
  `RuboCop::Cop::Metz::OnSendCsendBridge` so `csend` (`&.`) is handled
  identically. Existing cops show the pattern.
- `test/fixtures/sample_app/` is frozen: every file's SHA-256 is pinned in
  `.frozen.sha256`. Changing the fixture is a deliberate act — update the
  manifest in the same commit or `check_sample_app_frozen` fails CI.
- Docs are test-enforced. `test/metz_scan/readme_project_analyzer_status_test.rb`,
  `readme_workflow_docs_test.rb`, `read_only_command_docs_test.rb`, and
  `metz_scan_skill_test.rb` pin README/skill content to actual behavior. If you
  change CLI output, analyzer status, or workflow commands, expect to update
  README.md and `skills/metz-scan/SKILL.md` too.
- Exact-output fixtures under `test/fixtures/` (e.g.
  `project_analyzers/text.txt`, `check_rubydex_drift/*.txt`) pin CLI text/JSON
  byte-for-byte. Output changes require deliberate fixture updates, never
  loosened assertions.
- Never write a test that assumes the `rubydex` group is installed — CI does
  not install it. Use the `test/support/missing_rubydex.rb` pattern for both
  paths.
- New read-only maintenance commands go into the `bin/check_read_only_commands`
  guard list (and its docs), not one-off wrappers.
- `.rubocop.yml` is ERB and excludes all `test/fixtures/*` app trees. To scan a
  fixture app manually, copy it outside the repo first (mktemp pattern in
  RELEASE_CHECKLIST.md and CI).
- `scan` exit 1 means "findings reported", not a crash. Higher exits are real
  failures.
- Version bumps touch both `lib/metz_scan/version.rb` and
  `rubocop-metz/lib/rubocop/metz/version.rb`, plus `Gemfile.lock`;
  release-issue dry-run expectations in tests pin the version string.
- Durable code-level design exceptions get a DDR under `docs/ddrs/` with a
  nearby code comment referencing it (see `docs/design-decision-records.md`).

## Quality bar (definition of done for a slice)

1. Behavior changes and bug fixes are red-green: a test that fails for the
   right reason precedes the fix (see `16824db` / `d041d51` for shape).
2. `bundle exec rake`, `bundle exec rubocop`, and the guard scripts pass.
3. `bin/check_ci_parity` passes on the committed HEAD before pushing.
4. `.trk/` updated via `trk` in the same commit as the work (never
   tracker-only commits, except deliberate direction changes).
5. Docs updated when behavior changed (the freshness tests will tell you).
6. No coverage sweeps: test hardening is declared done. New tests accompany
   behavior changes or defects only.

## Failure modes to expect

- `check_ci_parity` failing while local tests pass = a local-only environment
  assumption (usually the optional `rubydex` bundler group or an untracked
  file). Use the printed `clean clone preserved at` path and `next action:`
  command to reproduce inside the preserved clone.
- Editing anything under `test/fixtures/sample_app/` without regenerating
  `.frozen.sha256` → CI failure.
- Changing scan output text at all → several exact-fixture tests plus README
  freshness tests fail together. That is the system working; update them as a
  set.
- `bin/check_dogfood` failing after a cop change usually means this repo's own
  code now offends the changed cop — fix the code or reconsider the cop change;
  do not add suppressions.

## Escalation — stop and ask the user before

- Publishing gems, creating tags, cutting GitHub Releases (explicit release
  authorization is a standing rule; see `implementation-notes.md`).
- Filing or closing GitHub issues (issue creation was permission-blocked by
  policy on 2026-07-05; drafts need user approval).
- Changing analyzer thresholds, statuses, default-output policy, or promoting
  candidate analyzers — all explicitly parked in `.trk/STATE.md` backlog.
- Adding app-specific suppressions or new calibration targets (parked).
- Adding dependencies (Sorbet was evaluated and rejected in
  `docs/spikes/sorbet-issue-26.md`; don't relitigate without new evidence).
- Starting a new slice while `origin/main` CI is red — triage the red run
  first instead.

## PR / diff review criteria

Check, in order: (1) dependency direction — nothing under `rubocop-metz/lib/`
mentions the wrapper; (2) `on_send` cops include `OnSendCsendBridge`;
(3) sample-app freeze manifest consistent with fixture edits; (4) exact-output
fixtures updated deliberately, not assertions loosened; (5) README/skill
freshness tests still meaningful (docs match new behavior, not weakened to
pass); (6) `.trk/` updated with the slice and Next still actionable;
(7) scope matches a Next item or filed issue — flag parked-area changes;
(8) no defensive rescue/nil-guard slop, no comments restating code, no new
abstractions without three concrete uses; (9) tests exercise observable CLI or
analyzer behavior, not implementation internals.

## Delegating to Codex (openai-codex plugin)

Work is delegated via the `codex:codex-rescue` agent + `codex-companion.mjs`.
Upstream bug to defend against: openai/codex-plugin-cc#432 (root-cause class
in #222) — a foreground companion run wrapped in a harness background shell
gets reaped when the subagent exits, killing the companion before it writes a
terminal status. The job record wedges at `running` forever even though the
Codex turn usually completes server-side and the work lands on disk.

Protocol:

- Dispatch the rescue subagent in the FOREGROUND (`run_in_background: false`)
  as a thin forwarder: one companion `task` call, return the task ID, no
  waiting or polling inside the subagent. Never satisfy "background" with a
  harness background shell around a foreground companion run; ask for the
  companion's own `--background` mode explicitly as belt-and-suspenders.
- Poll `status <task-id>` from the main session with a bounded loop (the
  #31/#32-scale tasks ran ~34m; poll every 5-8m, cap around 60-90m).
- If status seems stuck at `running`, check three signals before concluding
  anything: (1) job log mtime (path is in status output; live runs append
  regularly), (2) recorded worker pid liveness (`kill -0 <pid>`), (3) the job
  JSON under the plugin's `state/<workspace>/jobs/<task-id>.json` — a missing
  `request` key means a foreground run and exactly the #432 wedge (healthy
  background jobs always store `request`).
- Recovery for a wedged record: verify the deliverable in the working tree
  directly (run tests, inspect the diff) — never trust status output alone —
  then clear the stale record with `codex-companion.mjs cancel <task-id>`.
  The Codex session ID in status output stays valid for later `--resume`.
- Independent review is mandatory regardless: rerun the focused tests and
  read the full diff before updating the tracker or committing.
- Tell Codex to use agenticons for helper investigations and the required
  reviewer, and to leave committing/pushing to the orchestrating session.
