# metz-scan

`metz-scan` is a Ruby CLI for finding Sandi-Metz-style design pressure in Ruby and Rails code.

## Why this exists

RuboCop is excellent at enforcing local style and correctness, but design smells often need more explanation than a terse lint message. `metz-scan` wraps a custom RuboCop plugin with reports that explain why a finding matters and what a developer can do next.

Example output:

```text
$ metz-scan scan app lib

Metz/MethodsTooLong
  Why it matters: Long methods hide multiple responsibilities and resist understanding at a glance.
  Run `metz-scan explain Metz/MethodsTooLong` for details.
  app/models/order.rb:12:3 Metz/MethodsTooLong: Method has too many lines. [7/5]

Summary
-------
Metz compliance: 62% (312/500 files clean)
435 offenses across 6 cops

By cop:
  Metz/MethodsTooLong                         333
  Metz/ControllersTooManyDirectCollaborators  58
  Metz/ClassesTooLong                         21
  Metz/DemeterTrainWreck                      13
  Metz/MethodsTooManyParameters               6
  Metz/ViewsDeepNavigation                    4

Most offenses:
  app/models/order.rb                   31
  app/models/account.rb                 24
  app/controllers/orders_controller.rb  19
  app/services/checkout.rb              15
  app/models/user.rb                    12
```

The compliance percentage is the share of inspected files with no `Metz/*`
rule offenses; advisory `MetzProject/*` project-analyzer findings never count
against it.

The repo contains two gems:

- `metz-scan`: the user-facing CLI.
- `rubocop-metz`: the RuboCop plugin that provides the `Metz/*` cops.

## How metz-scan compares

`metz-scan` is a modern take on the question [`sandi_meter`](https://github.com/makaroni4/sandi_meter)
popularized: how well does this code follow Sandi Metz's rules? `sandi_meter` was
the prior art here, and metz-scan carries the same headline idea — a compliance
scorecard — forward with a wider, more current toolset:

- **All four classic rules, plus more.** Class and method size, parameter count,
  and controller collaborators, plus Law-of-Demeter chains (`DemeterTrainWreck`)
  and deep view navigation (`ViewsDeepNavigation`).
- **Correct on modern Ruby.** Default scans analyze at your project's
  `TargetRubyVersion`, so Ruby 3.x syntax (endless methods, anonymous argument
  forwarding, pattern matching) is parsed, not flagged as a syntax error.
- **Project-level design pressure, not just per-file rules.** Eight opt-in
  project analyzers surface service soup, repeated branching, deep inheritance,
  and other cross-file smells.
- **CI-native.** Text, JSON, SARIF (GitHub code scanning), and GitHub
  annotations, with an exit code of `1` reserved for "findings reported."
- **RuboCop-native.** Built as a RuboCop plugin that honors your project's
  `Include`/`Exclude` scope, so it slots into an existing pipeline.
- **Self-explaining.** `metz-scan explain <cop>` and `metz-scan rules` describe
  each rule and why it matters.

`metz-scan` measures design pressure only. It is not a security or correctness
auditor — pair it with brakeman or a full audit pipeline for those concerns.

When an application operation (“service object”) is legitimate vs procedural abuse,
and how that is enforced (including `Metz/OperationsTooManyPublicMethods` and
`Metz/GodServiceClass`), see
[`docs/application-operations.md`](docs/application-operations.md). That document is
maintained in full in this repo so metz-scan has no hard dependency on rails-audit.

## Install

```bash
gem install metz-scan
```

Or add it to your Gemfile:

```ruby
gem "metz-scan", "~> 0.5.3"
```

```bash
bundle install
bundle exec metz-scan --version
```

`metz-scan` depends on `rubocop-metz` (the RuboCop plugin providing the
`Metz/*` cops); Bundler resolves a compatible version automatically.

Also available on GitHub Packages if you need package-registry provenance
alongside rubygems.org — see [GitHub Packages install](#github-packages-install)
below for the auth setup.

## Quick Start

From the project you added `metz-scan` to, list the rules, explain a cop, and
scan your code:

```bash
bundle exec metz-scan rules
bundle exec metz-scan explain Metz/DemeterTrainWreck
bundle exec metz-scan scan app lib
```

`scan` exits `1` when it reports findings — that is the tool working, not a
crash (higher exit codes are real failures).

Text `scan` output ends with a `Summary` scorecard. The compliance percentage
is the share of inspected files with no `Metz/*` rule offenses; advisory
`MetzProject/*` project-analyzer findings do not make a file unclean. The same
summary also reports total offenses across cops, per-cop counts, and the five
files with the most reported offenses. Clean scans print `No offenses found.`

To see a guaranteed finding on a bundled fixture, run this from a checkout of
this repository (the `test/fixtures` path exists only in the repo):

```bash
fixture_dir="$(mktemp -d)"
cp -R test/fixtures/service_soup_app "$fixture_dir/service_soup_app"
bundle exec metz-scan scan "$fixture_dir/service_soup_app" --project-analyzers --format text || true
rm -rf "$fixture_dir"
```

The service-soup fixture intentionally contains a project-analyzer finding. The
copy keeps the scan target outside this repository's fixture exclusions, so the
scan command prints findings and exits nonzero.

## Usage

List the available Metz cops:

```bash
bundle exec metz-scan rules
bundle exec metz-scan rules --json
```

List the available project analyzers and their rollout status:

```bash
bundle exec metz-scan project-analyzers
bundle exec metz-scan project-analyzers --json
```

Explain a cop:

```bash
bundle exec metz-scan explain Metz/ViewsDeepNavigation
```

Scan paths:

```bash
bundle exec metz-scan scan app/models app/controllers
bundle exec metz-scan scan . --format json
bundle exec metz-scan scan . --format sarif
bundle exec metz-scan scan . --format gh-annotations
```

`--format json` adds an additive `summary` object to the report —
`clean_file_count`, `files_with_offenses`, and `offenses_by_cop` (a cop → count
map) alongside the existing fields — so tools can consume the compliance
scorecard without parsing the text output.

By default, `scan` runs the RuboCop-backed `Metz/*` cops only, plus
project-analyzer findings that satisfy the default-output policy: the analyzer
is explicitly default-output eligible, the analyzer is validated, and the
individual finding is medium-confidence design pressure. Use `--all-cops` to
run the full stock RuboCop suite as well. Use `--project-analyzers` to include
the full opt-in project-analyzer set, including validated opt-in-only analyzers,
candidates, and lower-confidence findings:

```bash
bundle exec metz-scan scan . --all-cops
bundle exec metz-scan scan . --project-analyzers
bundle exec metz-scan scan . --project-analyzers --format json
bundle exec metz-scan scan . --project-analyzers --format sarif
```

In default mode, `scan` reports stock Metz opinion on your project: it honors
your project's file *scope* — both `AllCops: Exclude` and per-cop
`Metz/*: Exclude` lists — but uses stock Metz cop configuration for thresholds,
severity, and opt-in status, so a project cannot weaken a Metz cop and get a
rosier report. This is why the length cops (`Metz/MethodsTooLong`,
`Metz/ClassesTooLong`) can be scoped off test trees with a per-cop `Exclude`
while still applying to production code. `--all-cops` runs the full stock
RuboCop suite under your complete project configuration instead.

`Metz/TestReachesPrivate`, `Metz/TestAssertsOnInternals`, and
`Metz/TestStubsSubject` are opt-in testing-discipline cops. They are listed by
`rules` and `explain`, but they are not included in default scan output until
separate dogfooding earns that promotion.

Default mode reads only file-scope settings from the target `.rubocop.yml`, so
it does not require external RuboCop extensions declared with `plugins:`,
`require:`, or `inherit_gem:`. `--all-cops` uses RuboCop's complete project
configuration; if a target extension gem is missing, install that gem in the
bundle you use to run `metz-scan` or run the default Metz-only scan.

If an `inherit_gem:` entry names a gem that isn't installed in the bundle
running `metz-scan`, that gem's file-scope `Exclude` cannot be read, so it is
not applied — default mode prints a one-line `metz-scan: note:` warning to
stderr naming the gem instead of silently dropping the exclude. Install the
gem (or run `--all-cops`, which uses your complete project configuration) to
have that scope honored.

Current project analyzer status:

| Analyzer | Status | Default scan | Expected findings |
| --- | --- | --- | --- |
| `MetzProject/ServiceSoup` | Validated | Yes | Methods that coordinate at least three distinct service constants, such as `ValidateOrder.call(...)`, `CapturePayment.new(...).call`, or `FetchMessages.new(...).perform`. |
| `MetzProject/RepeatedBranching` | Validated | Yes | Repeated `case` expressions with the same lexical decision and branch-value set, or repeated `if`/`elsif` predicate chains with the same receiver and predicate set, across distinct Ruby files. |
| `MetzProject/DeepInheritanceTree` | Validated | No | Indexed base classes or modules with at least three known descendants, when the optional Rubydex-backed project index is available. |
| `MetzProject/PackageDependencyPressure` | Candidate | No | Indexed namespaced classes or modules referenced from several files across multiple coarse packages outside their declaration package. |
| `MetzProject/NamespaceLeakPressure` | Candidate | No | Indexed deeply nested classes or modules referenced from multiple files across packages outside their home namespace. |
| `MetzProject/ImplicitContextPressure` | Candidate | No | Repeated `Current.*`, namespaced `Current`, or literal `Thread.current[...]` ambient context access across files and coarse packages. |
| `MetzProject/RepeatedQueryCriteria` | Candidate | No | Repeated constant-receiver or constant-root scope-chain hash criteria in `where`, `where.not`, or finder calls across files and coarse packages. Current fixture evidence is `where` plus `find_by`; `where.not` is supported and test-covered but not yet active-fixture evidenced. |
| `MetzProject/SubclassOverridePressure` | Candidate | No | Indexed base classes whose descendants repeatedly override the same method. |
| `MetzProject/TestCallsPrivateMethod` | Candidate | No | Test calls to private or protected methods confirmed by the optional Rubydex-backed project index; this is the index-confirmed form of `Metz/TestReachesPrivate`. |

Project analyzers parse Ruby files only and avoid semantic claims that require
resolving runtime types (they do not inspect ERB/HAML/SLIM templates). Default
scan output includes only findings from analyzers that are default-output
eligible, validated, and medium-confidence; pass `--project-analyzers` for the
complete opt-in set, including candidate analyzers and lower-confidence
findings. `MetzProject/TestCallsPrivateMethod` needs a scan path set that
includes tests, such as `metz-scan scan . --project-analyzers`; scanning only
`app lib` yields zero findings for that analyzer by design. See
[docs/project-analyzer-calibration.md](docs/project-analyzer-calibration.md)
for per-analyzer scope, thresholds, triage rules, and calibration evidence.

Run safe auto-correction or preview it first:

```bash
bundle exec metz-scan scan . --auto-fix --dry-run
bundle exec metz-scan scan . --auto-fix
```

Use `--format gh-annotations` in GitHub Actions to emit workflow command
annotations that appear inline on pull requests:

```yaml
- name: Run metz-scan annotations
  run: bundle exec metz-scan scan . --format gh-annotations
```

Re-render a saved JSON report:

```bash
bundle exec metz-scan scan . --format json > tmp/metz-scan.json
bundle exec metz-scan report tmp/metz-scan.json --format text
```

Use the RuboCop plugin directly:

```bash
bundle exec rubocop --plugin rubocop-metz
```

## Experimental project index

`metz-scan` has an optional Rubydex-backed project index for evaluating
project-level design analysis. Normal scans do not require it; `scan
--project-analyzers` uses it opportunistically for index-backed analyzers when
the optional bundle group is available.

Enable the optional bundle group and run the spike:

```bash
bundle config set --local with rubydex
bundle install
bundle exec ruby script/rubydex_spike.rb
```

The script indexes Ruby files, prints declaration/document counts, reports known
`Minitest::Test` descendants, lists `RuboCop::Cop::Metz` declarations, and
counts references to `RuboCop::Cop::Metz::OnSendCsendBridge`.

See [docs/rubydex-spike.md](docs/rubydex-spike.md) for current results and
feasibility notes.

For common questions and adoption guidance, see [docs/faq.md](docs/faq.md).
For agent-oriented consumer guidance, see
[skills/metz-scan/SKILL.md](skills/metz-scan/SKILL.md). For release checks,
see [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## Configuration

Configure `rubocop-metz` in `.rubocop.yml`.

```yaml
plugins:
  - rubocop-metz

Metz/MethodsTooLong:
  Max: 5

Metz/DemeterTrainWreck:
  Max: 4
```

| Setting | Where | Notes |
| --- | --- | --- |
| Enabled cops | `.rubocop.yml` | Standard RuboCop plugin configuration. |
| Output format | `metz-scan scan --format text\|json\|sarif\|gh-annotations` | `text` is for humans; `json`/`sarif` are for tools; `gh-annotations` emits GitHub Actions workflow annotations. |
| Auto-fix safety | `--auto-fix`, `--unsafe`, `--dry-run` | Safe fixes use RuboCop `-a`; unsafe fixes use RuboCop `-A`. |
| Environment variables | N/A | `metz-scan` does not require environment variables. |

## GitHub Packages install

`metz-scan` is also published to GitHub Packages, for consumers who want a
package-registry install alongside rubygems.org. Configure Bundler with a
GitHub token that can read packages, then add the GitHub Packages source to your
Gemfile:

```bash
gh auth refresh -h github.com -s read:packages
GITHUB_PACKAGES_TOKEN="$(gh auth token)"
bundle config set --global https://rubygems.pkg.github.com/fuentesjr \
  "fuentesjr:${GITHUB_PACKAGES_TOKEN}"
unset GITHUB_PACKAGES_TOKEN
```

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/fuentesjr" do
  gem "metz-scan", "~> 0.5.3"
end
```

```bash
bundle install
bundle exec metz-scan --version
```

## Requirements

- Ruby `>= 3.3`
- Bundler `4.0.8`
- A working compiler toolchain may be needed by transitive native gems on some platforms.

If your shell resolves to macOS system Ruby, switch to a Ruby `>= 3.3` before running Bundler.

## Contributing / Development

Before starting autonomous repo work, run `trk status --json` (see [AGENTS.md](AGENTS.md))
for the current local direction, next queue, parked work, and the reason this
repo tracks agent coordination locally instead of only in GitHub Projects or
issues.

For durable code-level design exceptions, write a lightweight Design Decision
Record before finalizing the exception. See
[docs/design-decision-records.md](docs/design-decision-records.md).

Clone the repo and install dependencies:

```bash
git clone https://github.com/fuentesjr/metz-scan.git
cd metz-scan
gem install bundler -v 4.0.8
bundle install
```

Run the local checks:

```bash
bin/check_dogfood
bundle exec rake
bundle exec rubocop
bin/check_dependency_direction
bin/check_sample_app_frozen
bin/check_ci_parity
```

`bin/check_dogfood` runs `metz-scan` against this repository with
`--project-analyzers` enabled and requires the optional `rubydex` bundle group.
It accepts zero project-analyzer findings. It fails if any
non-project-analyzer offense appears or if a project-analyzer finding appears.

Use `bin/check_ci_parity` before pushing release or workflow changes. It clones
the committed HEAD into a temp dir and runs the single-command CI phases
without local Bundler config or untracked files. If a phase fails, use the
printed `clean clone preserved at` path plus the `next action:` command to
reproduce that failed phase inside the preserved clone.

From this repository, `bin/check_published_gem VERSION` creates a clean
temporary consumer project and verifies a GitHub Packages install. Use it when
debugging package credentials, source configuration, or packaged runtime
behavior; failures include redacted Bundler output and credential hints.

Use `bin/check_read_only_commands` for maintenance commands that must leave
tracked files unchanged. The guard runs each command with `BUNDLE_FROZEN=1`,
fails if tracked files are dirty before or after a command, and currently covers
these read-only checks:

```bash
bundle exec ruby bin/check_project_analyzer_calibration --text --no-write test/fixtures/sample_app
bundle exec ruby bin/check_project_analyzer_calibration --print-baseline --baseline-label sample-app-preview --analyzer MetzProject/RepeatedBranching test/fixtures/sample_app
bin/check_rubydex_drift --allow-missing-rubydex --text test/fixtures/sample_app
bin/render_issue_comment_summary 27
```

Add future read-only maintenance commands to that guard instead of creating a
one-off wrapper.

Build both gems:

```bash
gem build metz-scan.gemspec
cd rubocop-metz && gem build rubocop-metz.gemspec && cd ..
```

File bugs and feature work in GitHub issues: <https://github.com/fuentesjr/metz-scan/issues>

## License

MIT. See [LICENSE](LICENSE).
