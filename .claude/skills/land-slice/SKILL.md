---
name: land-slice
description: "Finish, verify, and commit a work slice in metz-scan: run the verification gauntlet in the right order, update .trk/ via trk correctly, satisfy the fixture/docs freshness gates, and gate the push on bin/check_ci_parity. Use whenever a code change is ready to commit, or when tests are failing after an edit and you need to know which gate you tripped."
---

# Land a slice

A "slice" is this repo's unit of work: one bounded change, verified, committed
together with its tracker update. This skill encodes the order of operations
and the gates that most often surprise agents.

## Preconditions

- `origin/main` CI must be green before starting new work (standing rule in
  `CLAUDE.md`). Check with
  `gh run list --repo fuentesjr/metz-scan --branch main --limit 3`.
- The change should map to a Next item, a filed issue, or an explicit user
  request. If it touches a parked area (analyzer thresholds, statuses,
  suppressions, calibration targets, coverage sweeps), stop and ask the user.

## Verification gauntlet (run in this order — cheap first)

```bash
# 1. Focused tests for what you changed (fastest signal)
bundle exec ruby -Ilib -Itest -Irubocop-metz/lib -Irubocop-metz/test test/path/to_test.rb

# 2. Lint — the repo lints itself with its own cops; bin/check_dogfood catches
#    cop changes that make this repo's own code offend
bundle exec rubocop
bin/check_dogfood        # needs the optional rubydex bundle group locally

# 3. Full suite
bundle exec rake         # or rake test:fast first, then test:slow

# 4. Repo guards
bin/check_dependency_direction
bin/check_sample_app_frozen
bin/check_read_only_commands
bin/check_tracker_queue

# 5. Commit the slice, THEN parity-check the committed HEAD, THEN push
git add -A && git commit
bin/check_ci_parity
git push
```

`bin/check_ci_parity` clones the *committed HEAD* into a temp dir — it does not
see uncommitted changes. Commit first, parity-check, push. Parity now runs a
deliberate CI subset by default: docs-freshness tests for docs-only commits,
`rake test:fast` for code commits — a real subset of CI, not a full mirror.
Remote CI stays the full-suite backstop; set `CI_PARITY_FULL=1` to force the
full local suite (do this before a release prep, per the `release` skill). If
a phase fails it prints `clean clone preserved at <dir>` and a `next action:`
command; reproduce there, not in your checkout (the failure is usually a
local-only environment assumption such as the rubydex group or an untracked
file).

## Gates that break in clusters (know these before editing)

- **Changed any CLI output text?** Expect exact-output fixture failures in
  `test/fixtures/project_analyzers/text.txt`,
  `test/fixtures/check_rubydex_drift/*.{txt,json}`,
  `test/fixtures/scan_text_renderer_project_analyzer/*.txt`, plus README
  freshness failures (`test/metz_scan/readme_*_test.rb`). Update fixtures and
  docs deliberately as one set. Never loosen an exact assertion to a regex.
- **Touched `test/fixtures/sample_app/`?** Regenerate
  `test/fixtures/sample_app/.frozen.sha256`: one `sha256 path` line per file,
  `__SELF__` for the manifest itself (format in `bin/check_sample_app_frozen`).
  This fixture is frozen on purpose — only change it when the slice demands it.
- **Added/changed a cop with `on_send`?** It must include
  `RuboCop::Cop::Metz::OnSendCsendBridge` (safe-navigation invariant; see
  `rubocop-metz/test/rubocop/cop/metz/on_send_csend_bridge_test.rb`).
- **Added a read-only maintenance command?** Add it to the
  `bin/check_read_only_commands` guard list and the README's read-only section
  (`test/metz_scan/read_only_command_docs_test.rb` pins the two together).
- **Anything under `rubocop-metz/lib/`?** It must not mention
  `MetzScan`/`metz_scan` in any casing (`bin/check_dependency_direction`).

## Tracker update (same commit as the work)

Update `.trk/` through the `trk` CLI:

- `trk goal` / `trk next` / `trk backlog` for current state changes.
- `trk log` for completed work, decisions, and surprising findings.
- Keep the top Next items actionable (`bin/check_tracker_queue` enforces this —
  parked/watch-only wording like "monitor", "keep", "defer" without an action
  verb fails).

Never commit a tracker-only change unless it is a deliberate direction change.
If the slice needs more durable detail than STATE should carry, add a short
section to `docs/maintainers/implementation-notes.md` (task, scope boundaries, decisions,
verification) — match the existing entries' shape and brevity.

## Red-green discipline

For behavior changes and bug fixes, write the failing test first and confirm it
fails for the right reason. Recent examples of the expected shape: `d041d51`
(#33 default-scan excludes) and `16824db` (#34 collaborator counting) — each
carries regression tests derived from a concrete observed defect. Do not add
tests beyond the behavior change: coverage sweeps are parked as a class.

## After landing

If the problem solved was non-trivial (more than one failed approach, a
non-obvious root cause, or a new reusable technique), use the
`extract-approach` skill to capture it.
