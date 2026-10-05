---
name: metz-scan
description: "Run metz-scan as the end-of-task design check on Ruby or Rails projects. Use after changing Ruby code and before handing work back: scan, fix the Sandi-Metz-style design findings you introduced, rerun to confirm, and report what remains. Also covers the CLI commands, output formats, project analyzers, and CI use."
---

# Metz Scan

`metz-scan` reports Sandi-Metz-style design pressure in Ruby code. A finding
means "look here", not "defect". Prefix commands with `bundle exec` when the
project's `Gemfile` includes metz-scan; otherwise run `metz-scan` directly.
When neither works, say so in the handoff and leave the `Gemfile` unchanged.
Run from the project root so report paths match `git` paths.

## End-of-task check

Run this once, after your code changes are complete, not after every edit.

1. Save the before report and record `summary.offense_count`. The fixed
   directory survives shells that drop variables between commands.

   ```bash
   out="${TMPDIR:-/tmp}/metz-scan-check"
   mkdir -p "$out"
   bundle exec metz-scan scan . --format json > "$out/scan.json"
   ```

   Pass directories, not changed files: a file named directly is scanned even
   when the project excludes it, and cross-file analyzers see only the paths
   you pass. When the root is slow, pass the top-level directories that hold
   your changes, for example `app lib`.

2. Keep the findings in files you changed. `<base>` is the commit your task
   started from: `HEAD` while your work is uncommitted, otherwise the merge
   base of your branch and the default branch. `files[].path` is relative to
   where you ran; add `--relative` to `git diff` when that is not the
   repository root.

   ```bash
   git diff --name-only <base>
   git ls-files --others --exclude-standard
   ```

3. Decide which findings are yours. Every finding in a new file is yours. In
   an existing file, the rule depends on the cop.

   **Size and chain cops** (`Metz/MethodsTooLong`, `Metz/ClassesTooLong`,
   `Metz/MethodsTooManyParameters`, `Metz/DemeterTrainWreck`,
   `Metz/ViewsDeepNavigation`) report a count such as `[27/5]`, and overlap
   with your edit cannot tell yours from a pre-existing one, so the base scan
   decides. Scan the base commit from inside a worktree, so path-scoped cops
   match there too, passing the same paths as step 1:

   ```bash
   out="${TMPDIR:-/tmp}/metz-scan-check"
   base_dir="$(mktemp -d)/base"
   git worktree add --detach "$base_dir" <base>
   (cd "$base_dir" && BUNDLE_GEMFILE="$OLDPWD/Gemfile" \
     bundle exec metz-scan scan . --format json) > "$out/base.json"
   git worktree remove --force "$base_dir"
   ```

   Match findings on a key: path suffix, `cop_name`, `message`
   with every number removed, and an anchor from the source line at
   `location.start_line`. For the length and parameter cops the anchor is the
   method, class, or constant name on that line (`def name`,
   `define_method(:name)`, `class Name`, `Name = Struct.new`); for the chain
   cops it is the whole line with leading whitespace stripped. Read base lines
   with `git show <base>:<file>` and yours from the working tree. Pair findings
   that share a key in `start_line` order. An unpaired finding in your report
   is yours, including a chain you edited or a method or class you renamed.
   A paired finding is pre-existing even when it overlaps your edit: list it
   in the handoff as grew (`27/5` to `30/5`),
   shrank, or unchanged. When your edit grew a method-level finding
   (`Metz/MethodsTooLong`, `Metz/MethodsTooManyParameters`, or a chain cop),
   try once to reshape your own addition so it does not grow, for example a
   table entry instead of another branch; do not refactor code you did not
   change. Report a class that grew without acting on it.

   **Every other cop:** a finding is yours when either holds:

   - Its `location.start_line` through `location.last_line` overlaps lines
     you added or changed. In `git diff -U0 <base> -- <file>`, a hunk
     `@@ -a,b +c,d @@` covers new lines `c` through `c + d - 1`; an omitted
     `,d` means one line, and `d` of `0` means a pure deletion.
   - Its `message` names a method, class, parameter, or collaborator you
     added or changed. `Metz/GodServiceClass`,
     `Metz/OperationsTooManyPublicMethods`, and
     `Metz/ControllersTooManyDirectCollaborators` can anchor away from your
     edit, so check their messages.

   Other findings in a changed file are pre-existing: leave them and list
   them in the handoff. When unsure, match against the base scan on the key
   above; unpaired means yours.

4. Fix each finding that is yours. Read `why_it_matters` and
   `suggested_next_moves` on the offense when present, else in
   `guidance[cop_name]`; `metz-scan explain <cop>` adds the cop's
   configuration for `Metz/*` cops; `explain` rejects `MetzProject/*`. Fix
   the design problem, not the threshold: move behavior onto the object that
   owns the data; introduce a named query, presenter, or value object; replace
   parameters that travel together with one object; split a long method
   around named responsibilities; delegate instead of walking collaborators.
   When every fix makes the code harder to read, suppress instead (below).

5. Rerun with the same paths into a new file:

   ```bash
   out="${TMPDIR:-/tmp}/metz-scan-check"
   bundle exec metz-scan scan . --format json > "$out/after.json"
   ```

   A finding is fixed when nothing in the after report matches its step 3
   key and you did not suppress it; a smaller size finding is not fixed.
   Suppressed findings move to the report's `suppressions` list. Repeat
   steps 4 and 5 until none of yours remain, then run the project's tests;
   a design fix that breaks a test is not done.

6. Hand off with a metz-scan section: the scan command; `offense_count`
   before and after; each finding you fixed (cop, `path:line`, design move);
   each pre-existing finding you left in a changed file (grew, shrank, or
   unchanged for size findings); each suppression you added, with its reason;
   and any finding of yours you could not fix, and why.

## Changes that are not fixes

Do not make these, even when a finding disappears:

- Moving code where the scan does not look: an excluded directory, a
  non-Ruby file such as an ERB template, or a directory you add to
  `AllCops: Exclude`.
- Renaming a `*Service` class, or moving an operation out of `app/services`
  or `app/operations`, so a name- or path-scoped cop stops matching.
- Splitting a method into position-named helpers (`step_1`, `build_part_2`,
  `do_build`, `build_impl`) or at an arbitrary line.
- Moving methods into a mixin, concern, or helper module only the original
  class includes, leaving the same collaborators and public surface.
- Making public methods private while callers still reach them with `send`.
- Hiding a Demeter chain behind locals, `tap`, `then`, or `send` while the
  caller still walks the same object graph.
- Raising `Max` or adding `AllowedMethods`: the default scan ignores them.
- Setting `Enabled: false`: the default scan records every hidden finding in
  the suppression ledger, so it is a suppression, not a fix.

## Suppressions

Suppress only after a genuine fix attempt, when the finding is wrong for this
code or every fix reads worse. Write the reason at the site and cover the
smallest span: inline on the reported line, or a block closed with
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

Never disable a cop for a whole file, add application code to
`AllCops: Exclude`, or suppress without a reason. The report's
`suppressions` ledger lists each finding an inline directive, a per-cop
`Exclude`, or `Enabled: false` hid, with its `reason` or
`reason_status: missing`. Report every suppression in the handoff; when the
same reason recurs, ask the human whether to add a per-cop `Exclude`.

## Exit status and output

- `0` no findings; `1` findings reported. Exit status `64` is a usage error
  (missing path, unknown option, invalid format): fix the command. `2` means
  RuboCop failed, for example on an invalid `.rubocop.yml`: read stderr, fix
  the config or environment, rerun. Neither is a finding.
- Stdout holds the report; stderr holds `metz-scan: note:` lines and errors.
  A note about an uninstalled `inherit_gem` means that gem's `Exclude` was
  skipped; do not install it.
- Suppressed findings do not count toward `offense_count` or the exit status.
- `Lint/Syntax` means RuboCop could not parse the file at its detected Ruby
  version; set `AllCops: TargetRubyVersion` or fix the syntax.

## Scope

The default scan runs only `Metz/*` cops at stock thresholds. From the
project's `.rubocop.yml` it reads only file scope (`AllCops: Exclude`,
per-cop `Include`/`Exclude`), `Enabled: false` for `Metz/*` cops and the
`Metz` department, and `AllCops: TargetRubyVersion`. `--all-cops` runs the
full RuboCop suite under the project config and needs the project's
extension gems.

It also runs the default project analyzers `MetzProject/RepeatedBranching`
and `MetzProject/ServiceSoup`; treat their findings like any cop finding.
`--project-analyzers` adds advisory findings: keep them out of the fix loop
unless the task asks for a broader design review. Some analyzers need the
optional Rubydex bundle group and report nothing without it; do not install
Rubydex unless the human asks.

## Other commands

```bash
bundle exec metz-scan rules --json
bundle exec metz-scan explain Metz/MethodsTooLong
bundle exec metz-scan project-analyzers
bundle exec metz-scan scan . --project-analyzers --format json
bundle exec metz-scan scan app lib --format text
bundle exec metz-scan report "${TMPDIR:-/tmp}/metz-scan-check/scan.json" --format text
bundle exec metz-scan scan . --format sarif
bundle exec metz-scan scan . --format gh-annotations
bundle exec metz-scan scan . --all-cops --auto-fix --dry-run
```

`--format sarif` is for code-scanning upload. `--format gh-annotations`
shows findings inline on GitHub pull requests; exit status `1` fails the
step unless the workflow sets `continue-on-error`. No `Metz/*` cop
autocorrects, so `--auto-fix` matters only with `--all-cops`; `--unsafe`
adds unsafe corrections, and `--dry-run` prints the diff and restores the
files, which are rewritten during the run. Preview before applying.
