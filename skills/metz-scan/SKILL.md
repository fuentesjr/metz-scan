---
name: metz-scan
description: "Run metz-scan as the end-of-task design check on Ruby or Rails projects. Use after changing Ruby code and before handing work back: scan, fix the Sandi-Metz-style design findings you introduced, rerun to confirm, and report what remains. Also covers the CLI commands, output formats, project analyzers, and CI use."
---

# Metz Scan

`metz-scan` reports Sandi-Metz-style design pressure in Ruby code: long
methods and classes, long parameter lists, controllers with many
collaborators, Demeter chains, god service classes, and cross-file patterns
such as repeated branching. A finding means "look here", not "defect". The
procedure below is for a coding agent finishing a task; the reference
sections serve anyone running the CLI. When the project's `Gemfile` includes
metz-scan, prefix every command with `bundle exec`; otherwise run `metz-scan`
directly. When neither works, say so in the handoff and leave the `Gemfile`
unchanged. Run from the project root so report paths match `git` paths.

## End-of-task check

Run this once, after your code changes are complete and before you hand work
back. Do not run it after every edit: the rules judge finished shape, and
mid-edit findings push you into premature micro-refactors.

1. Scan the project and save the report as the before report. The commands
   use a fixed directory because your shell may not keep variables between
   commands. Record `summary.offense_count` for the handoff.

   ```bash
   out="${TMPDIR:-/tmp}/metz-scan-check"
   mkdir -p "$out"
   bundle exec metz-scan scan . --format json > "$out/scan.json"
   ```

   Pass directories, not a list of changed files: directories honor the
   project's `Exclude` scope, a file passed by name is scanned even when the
   project excludes it, and cross-file analyzers only see the paths you pass.
   When the root is slow, pass the top-level directories that hold your
   changes, for example `app lib`.

2. Keep the findings in files you changed. `<base>` is the commit your task
   started from: `HEAD` while your work is uncommitted, otherwise the merge
   base of your branch and the default branch.

   ```bash
   git diff --name-only <base>
   git ls-files --others --exclude-standard
   ```

   `files[].path` in the report is relative to the directory you ran from;
   when that is not the repository root, add `--relative` to `git diff`.

3. Decide which of those findings are yours. Every finding in a new file is
   yours. In an existing file, the rule depends on the cop.

   The length, parameter, and chain cops (`Metz/MethodsTooLong`,
   `Metz/ClassesTooLong`, `Metz/MethodsTooManyParameters`,
   `Metz/DemeterTrainWreck`, `Metz/ViewsDeepNavigation`) report a count such
   as `[27/5]` and name no method. The length cops span the whole method or
   class, so any edit inside overlaps them; the parameter and chain cops sit
   on the line you change when you touch them. Either way, overlap cannot
   tell your finding from a pre-existing one, so the base scan decides. Scan
   the base commit with the same paths as step 1: `"$base_dir"` for `.`, or
   `"$base_dir/app" "$base_dir/lib"` when step 1 passed `app lib`.

   ```bash
   out="${TMPDIR:-/tmp}/metz-scan-check"
   base_dir="$(mktemp -d)/base"
   git worktree add --detach "$base_dir" <base>
   bundle exec metz-scan scan "$base_dir" --format json > "$out/base.json"
   git worktree remove --force "$base_dir"
   ```

   Match findings on a key, ignoring the numbers: path suffix, `cop_name`,
   `message` with every number removed, and an anchor read from the source
   line at `location.start_line`. For the length and parameter cops the
   anchor is the method, class, or constant name on that line (`def name`,
   `define_method(:name)`, `class Name`, `Name = Struct.new`), so editing
   the body or the parameters keeps the key. For the chain cops it is the
   whole line with leading whitespace stripped. Base-scan paths are absolute
   under `$base_dir`; strip that prefix, then read the line with
   `git show <base>:<file>` for a base finding and from your working tree
   for yours. When several findings share a key, pair them in `start_line`
   order. An unpaired finding in your report is yours. A paired finding is
   pre-existing even when it overlaps your edit: leave it and list it in the
   handoff as grew (`27/5` to `30/5`), shrank, or unchanged. A chain you
   edited, or a method or class you renamed, pairs with nothing and counts
   as yours.

   For every other cop, a finding is yours when either holds:

   - Its `location.start_line` through `location.last_line` overlaps lines
     you added or changed. `git diff -U0 <base> -- <file>` prints each change
     as `@@ -a,b +c,d @@`; the new lines are `c` through `c + d - 1`. An
     omitted `,d` means one line; `d` of `0` means lines were only deleted.
   - Its `message` names a method, class, parameter, or collaborator you
     added or changed. `Metz/GodServiceClass` and
     `Metz/OperationsTooManyPublicMethods` anchor on the class name, and
     `Metz/ControllersTooManyDirectCollaborators` anchors on the first
     collaborator in the method, so their location may miss your edit; their
     messages list the methods or collaborators.

   Every other finding in a changed file is pre-existing: leave it and list
   it in the handoff. When you cannot tell, match it against the base scan
   with the key above; an unpaired finding is yours.

4. Fix each finding that is yours. Read its `why_it_matters` and
   `suggested_next_moves` first. For a `Metz/*` cop, `metz-scan explain <cop>`
   prints the same guidance with the cop's configuration; `explain` does not
   accept `MetzProject/*` analyzers. Aim each fix at the design problem
   the finding describes, not at the threshold: move behavior onto the object
   that owns the data, introduce a named query, presenter, or value object,
   replace a parameter list with one object when the parameters travel
   together, split a long method around named responsibilities, and delegate
   instead of walking collaborators. When every fix you can see makes the
   code harder to read, stop and apply the suppression rules below instead of
   forcing a change.

5. Rerun the scan with the same paths and write the after report to a new
   file so the before report survives.

   ```bash
   out="${TMPDIR:-/tmp}/metz-scan-check"
   bundle exec metz-scan scan . --format json > "$out/after.json"
   ```

   A finding is fixed when nothing in the after report matches it on the
   step 3 key and you added no suppression for it; a size finding that is
   still present but smaller is not fixed. A suppressed finding moves to the
   report's `suppressions` list instead of disappearing. Repeat steps 4 and 5
   until none of your findings remain, then run the project's test suite; a
   design fix that breaks a test is not done.

6. Hand off with a short metz-scan section: the scan command and
   `summary.offense_count` before and after your fixes; each finding you
   fixed (cop, `path:line`, design move); each pre-existing finding you left
   in a changed file, with grew, shrank, or unchanged for a size finding;
   each suppression you added, with its reason; and any finding of yours you
   could not fix, and why.

## Changes that are not fixes

These satisfy the scanner without improving the design. Do not make them,
even when they make a finding disappear:

- Moving code to a path the scan does not cover: an excluded directory, a
  non-Ruby file such as an ERB template, or a directory you add to `Exclude`.
- Renaming a `*Service` class, or moving an operation out of `app/services`
  or `app/operations`, so a name-scoped or path-scoped cop stops matching.
- Splitting a method into helpers named after position (`step_1`,
  `build_part_2`, `do_build`, `build_impl`) or at an arbitrary line.
- Moving methods into a mixin, concern, or helper module that only the
  original class includes, leaving the same collaborators and public surface.
- Making public methods private to lower a public-method count while callers
  still reach them with `send`.
- Hiding a Demeter chain behind local variables, `tap`, `then`, or `send`
  while the caller still walks the same object graph.
- Raising `Max`, adding `AllowedMethods`, or setting `Enabled: false` in
  `.rubocop.yml`. The default scan ignores these settings, so these edits
  change nothing.

## Suppressions

Suppress a finding only after a genuine fix attempt, when the finding is
wrong for this code or every fix makes the code harder to read. Write the
reason at the suppression site and cover the smallest span that works:
inline on the line the finding reports, or around a block closed with
`# rubocop:enable Metz/<Cop>`.

```ruby
def build(row) # rubocop:disable Metz/MethodsTooLong -- mirrors vendor schema
```

In `.rubocop.yml`, use a per-cop `Exclude` with the reason above the entry:

```yaml
Metz/ClassesTooLong:
  Exclude:
    # Generated from the vendor schema; regenerated on every schema change.
    - "app/models/vendor_schema.rb"
```

Do not disable a cop for a whole file, add application code to
`AllCops: Exclude`, or suppress without a reason. The default scan lists every
finding an inline directive or a per-cop `Exclude` hid, with its reason or
`reason_status: missing`, so a suppression you add shows up in the after
report. Report every suppression in the handoff. When the same reason recurs, ask the human whether to add a
per-cop `Exclude` instead of repeating it.

## Reading a report

- Stdout holds the report; stderr holds `metz-scan: note:` lines and errors.
- Exit status `0` means no findings and `1` means findings reported.
  Exit status `64` is a usage error (missing path, unknown option, invalid
  format): fix the command and rerun. Exit status `2` means RuboCop failed,
  including on an invalid project `.rubocop.yml`; read the stderr line, fix
  the config or environment, and rerun. It is never a finding.
- JSON: `files[].path` and `files[].offenses[]` with `cop_name`, `message`,
  `location` (`start_line`, `last_line`, `column`), `why_it_matters`,
  `fix_safety`, and `suggested_next_moves`; `summary` with `offense_count`,
  `offenses_by_cop`, `clean_file_count`, and `files_with_offenses`.
- JSON `suppressions[]` lists findings an inline directive or a per-cop
  `Exclude` hid, with `cop_name`, `path`, `line`, `column`, `message`,
  `suppressed_by` (`inline_disable` or `config_exclude`), `reason`,
  `reason_status` (`present`, `missing`, or `unchecked`), `directive`
  (`line`), and `config` (`path`, `line`, `pattern`); exactly one of
  `directive` and `config` is non-null. They do not count toward
  `offense_count` or the exit status. Text output lists them under
  `Suppressed findings: N, M without a reason` before the `Summary`.
  A per-cop `Include` that narrows a cop also hides findings, without a
  record. Regexp `Exclude` entries are reported with their `/regexp/` text and
  reason `unchecked`. When the same `Exclude` pattern appears in a base and an
  inheriting config (`inherit_mode: merge`), the base file's entry is credited.
- Text output ends with a `Summary` scorecard: Metz compliance is the share
  of inspected files with no `Metz/*` offense, and `MetzProject/*` findings
  do not make a file unclean.
- `Lint/Syntax` offenses mean RuboCop could not parse the file at the Ruby
  version it detected; set `AllCops: TargetRubyVersion` or fix the syntax.

## Scope and configuration

- The default scan runs only `Metz/*` cops with stock thresholds and reads
  only file scope and `AllCops: TargetRubyVersion` from the project's
  `.rubocop.yml`; file scope is `AllCops: Exclude` and per-cop `Include` and
  `Exclude`. It runs without the project's RuboCop extension gems; when
  `.rubocop.yml` inherits from a gem that is not installed, it prints a
  `metz-scan: note:` line and skips that gem's scope.
- `--all-cops` runs the full RuboCop suite under the complete project
  configuration and needs the project's extension gems in the bundle.
- `Metz/TestReachesPrivate`, `Metz/TestAssertsOnInternals`, and
  `Metz/TestStubsSubject` are opt-in: `rules` lists them, but they appear in
  a scan only when the project enables them and you use an opt-in path such
  as `--all-cops`.

## Project analyzers

The default scan includes the validated default-output analyzers
`MetzProject/RepeatedBranching` and `MetzProject/ServiceSoup`; they look
across the files you pass, and their findings go through the end-of-task
check like any cop finding. `--project-analyzers` adds the other validated
and candidate analyzers, plus default-analyzer findings outside the default
output bar (validated, medium confidence, design pressure).
Treat those added findings as advisory: keep them out of the fix loop and use
them when the task asks for a broader design review.

```bash
bundle exec metz-scan project-analyzers
bundle exec metz-scan scan . --project-analyzers --format json
```

`MetzProject/DeepInheritanceTree`, `MetzProject/PackageDependencyPressure`,
`MetzProject/NamespaceLeakPressure`, `MetzProject/SubclassOverridePressure`,
and `MetzProject/TestCallsPrivateMethod` need the optional Rubydex bundle
group; without it they report nothing. Do not install Rubydex unless the
human asks for that coverage.

## Other commands and formats

```bash
bundle exec metz-scan rules --json
bundle exec metz-scan explain Metz/MethodsTooLong
bundle exec metz-scan scan app lib --format text
out="${TMPDIR:-/tmp}/metz-scan-check"
bundle exec metz-scan report "$out/scan.json" --format text
bundle exec metz-scan scan . --format sarif
bundle exec metz-scan scan . --format gh-annotations
bundle exec metz-scan scan . --all-cops --auto-fix --dry-run
```

Use `--format text` for humans, `--format json` for filtering, `--format
sarif` for code-scanning upload, and `--format gh-annotations` in GitHub
Actions so findings appear inline on pull requests, where exit status `1`
fails the step unless the workflow sets `continue-on-error`.

No `Metz/*` cop autocorrects, so `--auto-fix` only matters with `--all-cops`:
it applies RuboCop's safe corrections, `--unsafe` adds the unsafe ones, and
`--dry-run` prints the diff and restores the original files afterward;
files are rewritten during the run. Preview before applying.
