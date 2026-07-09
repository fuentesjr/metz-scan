---
name: metz-scan
description: "Use when Codex needs to run, explain, or integrate metz-scan on Ruby or Rails projects: installing or invoking the CLI, choosing scan and project-analyzer commands, selecting text/JSON/SARIF/GitHub annotation output, interpreting design-pressure findings, using safe auto-fix, or handling optional Rubydex-backed project analyzers."
---

# Metz Scan

Use this skill to apply `metz-scan` as a consumer tool on Ruby and Rails
repositories. Keep maintainer-only workflows, release checks, calibration
artifacts, and project-tracker work out of this skill.

## Quick Workflow

1. Confirm the target is a Ruby project. Prefer `bundle exec metz-scan ...`
   when the project has a `Gemfile`.
2. Start read-only. Run `rules`, inspect project analyzer availability, then
   scan the narrowest useful paths.
3. Treat exit status `1` from `scan` as "findings were reported", not a
   crash. Treat higher exits or command errors as invocation/environment
   failures.
4. Summarize findings as design pressure for human review. Do not present them
   as proof of a defect.
5. Use auto-fix only after a dry run and only when the user asked for edits.

## Core Commands

List rules:

```bash
bundle exec metz-scan rules
bundle exec metz-scan rules --json
```

List project analyzers and rollout status:

```bash
bundle exec metz-scan project-analyzers
bundle exec metz-scan project-analyzers --json
```

Scan likely application paths:

```bash
bundle exec metz-scan scan app lib --format text
bundle exec metz-scan scan . --format json
bundle exec metz-scan scan . --format sarif
bundle exec metz-scan scan . --format gh-annotations
```

Text `scan` and `report` outputs end with a `Summary` scorecard: Metz compliance
is the share of inspected files with no `Metz/*` rule offenses, and advisory
`MetzProject/*` findings do not make a file unclean. The scorecard also rolls up
total offenses, per-cop counts, and the files with the most offenses. JSON
summary data includes `clean_file_count`, `files_with_offenses`, and
`offenses_by_cop`.

Include the full opt-in project-analyzer set:

```bash
bundle exec metz-scan scan . --project-analyzers --format text
bundle exec metz-scan scan . --project-analyzers --format json
```

Re-render a saved JSON report:

```bash
bundle exec metz-scan scan . --format json > tmp/metz-scan.json
bundle exec metz-scan report tmp/metz-scan.json --format text
```

Preview safe corrections before applying them:

```bash
bundle exec metz-scan scan . --auto-fix --dry-run
bundle exec metz-scan scan . --auto-fix
```

## Choosing Project Analyzer Mode

Default `scan` output reports regular Metz findings plus project-analyzer
findings that satisfy the default-output policy.

Use `--project-analyzers` when the user wants broader design review,
calibration-style evidence, candidate analyzer output, lower-confidence
findings, or project-wide relationship signals. Explain that candidate and
opt-in findings are advisory and require context.

Optional Rubydex-backed indexing is opportunistic. Normal scans do not require
Rubydex. With `--project-analyzers`, index-backed analyzers may report no
findings when the optional bundle group is unavailable. Do not install optional
Rubydex dependencies unless the user explicitly wants fuller project-index
coverage.

Default scan mode reads only file-scope settings from the target `.rubocop.yml`.
It can run even when the target declares external RuboCop extensions through
`plugins:`, `require:`, or `inherit_gem:` that are not installed in the current
bundle. `--all-cops` delegates to RuboCop's complete project configuration, so
missing target extension gems are environment/setup errors: install the gem in
the bundle used to run `metz-scan`, or use the default Metz-only scan.

`Metz/TestReachesPrivate`, `Metz/TestAssertsOnInternals`, and
`Metz/TestStubsSubject` are opt-in testing-discipline cops. They are listed by
`rules` and `explain`, but default `scan` output does not include them unless
the project explicitly enables them and runs through an opt-in path such as
`--all-cops`.

If an `inherit_gem:` target isn't installed, its file-scope `Exclude` can't be
read, so default mode prints a one-line `metz-scan: note:` warning to stderr
naming the gem instead of silently skipping that exclude.

## Output Selection

- Use `--format text` for human review in chat or terminal.
- Use `--format json` for machine processing or follow-up filtering.
- Use `--format sarif` for code-scanning upload workflows.
- Use `--format gh-annotations` in GitHub Actions so findings appear inline on
  pull requests.

Example GitHub Actions step:

```yaml
- name: Run metz-scan annotations
  run: bundle exec metz-scan scan . --format gh-annotations
```

## Reporting Findings

When summarizing results:

- Group by rule or project analyzer.
- Include severity/confidence/triage context when present.
- Quote the command and target paths used.
- Distinguish default-output findings from `--project-analyzers` opt-in
  findings.
- Recommend concrete review next steps rather than automatic refactors.

Avoid app-specific suppressions or threshold changes unless the user asks to
change this tool's own analyzer implementation.
