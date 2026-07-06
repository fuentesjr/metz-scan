# metz-scan

`metz-scan` is a Ruby CLI for finding Sandi-Metz-style design pressure in Ruby and Rails code.

## Why this exists

RuboCop is excellent at enforcing local style and correctness, but design smells often need more explanation than a terse lint message. `metz-scan` wraps a custom RuboCop plugin with reports that explain why a finding matters and what a developer can do next.

Example output:

```text
Metz/ViewsDeepNavigation
  Why it matters: Deep object-graph chains in views couple templates to the internal structure of every collaborator they touch, making refactors and test setup painful.
  Run `metz-scan explain Metz/ViewsDeepNavigation` for details.
```

The repo contains two gems:

- `metz-scan`: the user-facing CLI.
- `rubocop-metz`: the RuboCop plugin that provides the `Metz/*` cops.

## Install

`metz-scan` is currently published to GitHub Packages. Configure Bundler with a
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
  gem "metz-scan", "~> 0.4.0"
end
```

```bash
bundle install
bundle exec metz-scan --version
```

From this repository, `bin/check_published_gem VERSION` creates a clean
temporary consumer project and verifies a GitHub Packages install. Use it when
debugging package credentials, source configuration, or packaged runtime
behavior; failures include redacted Bundler output and credential hints.

Use `bin/check_ci_parity` before pushing release or workflow changes. It clones
the committed HEAD into a temp dir and runs the single-command CI phases
without local Bundler config or untracked files. If a phase fails, use the
printed `clean clone preserved at` path plus the `next action:` command to
reproduce that failed phase inside the preserved clone.

For local development:

```bash
git clone https://github.com/fuentesjr/metz-scan.git
cd metz-scan
gem install bundler -v 4.0.8
bundle install
```

## Quick Start

```bash
bundle exec metz-scan rules
bundle exec metz-scan explain Metz/DemeterTrainWreck
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

Project analyzers parse Ruby files only. They do not inspect ERB/HAML/SLIM
templates, and they avoid semantic claims that require resolving runtime types.
For example, `ServiceSoup` counts distinct constant-backed `.call` and
`.perform` service-call shapes but does not prove that a constant is truly a
service object. Seed and setup orchestrators are reported with lower confidence
and setup-specific triage language. See
[docs/project-analyzer-calibration.md](docs/project-analyzer-calibration.md) for
current calibration notes.

`RepeatedBranching` reports generic branch subjects such as `action`, `type`,
`value`, and `key.to_s` with lower confidence and `context required` triage.

- Use `--project-analyzers` to review those context-dependent findings.
- Default scan output keeps medium-confidence design-pressure findings.

### Analyzer Behavior Details

#### `MetzProject/DeepInheritanceTree`

- **Index:** Uses the optional Rubydex-backed project index. If that optional
  bundle group is unavailable, `--project-analyzers` still runs and this
  analyzer simply contributes no findings.
- **Triage:** Broad framework, Rails application, controller, job, service,
  serializer, policy, worker, exception, CLI, and abstract bases remain visible
  with lower confidence and `broad base` triage.

#### `MetzProject/PackageDependencyPressure`

- **Index:** Requires the optional project index and contributes no findings
  when the index is unavailable.
- **Scope:** Counts declarations under `app/` and `lib/` packages.
- **Ignored references:** Skips `spec/`, `test/`, `lib/tasks/`,
  `lib/seeders/`, `lib/seed_data/`, `lib/test_data/`, `lib/generators/`,
  nested seed paths, and nested `testing_support` paths.
- **Threshold:** Reports at least 12 referring files across at least
  5 packages.
- **Triage:** Broad shared dependencies such as configuration, settings, event
  registries, exception families, infrastructure hubs, conventional domain model
  surfaces, value objects, and protocol-manager surfaces are lower-confidence
  shared-dependency findings.
- **Metadata:** Includes a shared `reference_shape` summary so package- and
  namespace-pressure calibration can compare referring file counts, package
  counts, package roots, and package leafs consistently.

#### `MetzProject/NamespaceLeakPressure`

- **Index:** Requires the optional project index and contributes no findings
  when the index is unavailable.
- **Scope:** Reports deeply nested declarations such as
  `Billing::Ledger::PrivateFormatter` when references spread outside the home
  namespace into at least three files across three coarse packages.
- **Ignored references:** Skips references from the same namespace path, test
  roots, and setup/support paths such as nested seed and `testing_support`
  paths.
- **Triage:** Public constants, nested exception families, and framework or
  extension namespaces are lower-confidence shared-namespace findings.
- **Metadata:** Includes the same shared `reference_shape` summary used by
  `PackageDependencyPressure`.

#### `MetzProject/ImplicitContextPressure`

- **Runtime needs:** AST-only and candidate opt-in.
- **Scope:** Reports repeated Rails `CurrentAttributes`-style access such as
  `Current.account` or `Spree::Current.store`, plus literal
  `Thread.current[...]` key access such as `Thread.current[:redis]`.
- **Threshold:** Requires the same ambient context in at least three files
  across at least two coarse packages.
- **Ignored calls:** Skips lifecycle calls such as `Current.reset`,
  `Spree::Current.reset`, and `Current.set(...)`; dynamic `Thread.current` keys
  stay out of scope.
- **Metadata:** Distinguishes root vs namespaced `Current` receivers,
  thread-local keys, and whether the repeated access includes writes.

#### `MetzProject/RepeatedQueryCriteria`

- **Runtime needs:** AST-only and candidate opt-in.
- **Scope:** Reports simple constant-receiver or constant-root scope-chain hash
  criteria with at least two literal keys.
- **Included query shapes:** Positive `where` filters, negative `where.not`
  filters, and finder lookups such as `find_by`, `find_or_initialize_by`, or
  `find_or_create_by`.
- **Examples:** `Order.where(account_id: ..., status: ...)`,
  `Order.active.where.not(account_id: ..., status: ...)`, and
  `Post.find_by(topic_id: ..., post_number: ...)`.
- **Threshold:** Requires the same receiver, query method, and key set in at
  least three files across at least two coarse packages.
- **Out of scope:** Dynamic SQL strings, single-key lookups, dynamic scope
  chains, non-constant receivers, dynamic hashes, bang finders, and broader
  relation APIs.
- **Metadata:** Distinguishes polymorphic, compound-association,
  association-scoped, and generic hash-criteria repeats; records query method,
  query operation, and whether the receiver is a constant or scope chain.
- **Current calibration:** Active fixtures contain 15 findings: 6 positive
  `where` filters and 9 `find_by` lookups. No repeated `where.not` finding
  appears in active fixtures at the current threshold.
- **Quality read:** 12 useful manual-review prompts and 3 mechanical or
  expected lookups, so the analyzer stays candidate-only while
  membership-table lookups and business-named lookup concepts remain separate
  in calibration.

#### `MetzProject/SubclassOverridePressure`

- **Index:** Requires the optional project index and remains candidate opt-in.
- **Scope:** Reports base classes whose known descendants override the same
  base-declared method in at least six subclasses.
- **Triage:** Framework, Rails application, controller, job, service,
  serializer, policy, worker, exception, CLI, and abstract bases use the same
  broad-root vocabulary as `DeepInheritanceTree` and are lower-confidence
  `broad base` findings.
- **Metadata:** Records whether the base method is abstract, empty,
  default-valued, or concrete, and whether descendant overrides call `super`.
  Repeated override families are triaged as broad-root, abstract-hook,
  cooperative, replacement, or unclassified override pressure with
  category-specific report language and next steps.

Project analyzer output includes status, confidence, triage severity, and triage
summary metadata. Default output includes only explicitly eligible, validated,
medium-confidence design-pressure findings; `--project-analyzers` includes
candidates, validated opt-in-only analyzers, and lower-confidence findings too.
Text output shows a project-analyzer summary before rule blocks, including
aggregate analyzer, confidence, severity, and category counts for opt-in
high-volume runs; JSON and SARIF output include machine-readable
project-analyzer metadata, and GitHub annotations append the same triage context
to the annotation message. Calibration evidence summaries from
`bin/check_project_analyzer_calibration` also include a readiness/backlog section
that records the current analyzer disposition, evidence boundary, next useful
task, and explicit not-next boundary without changing scan output. Pass
`--baseline-file docs/calibration/project_analyzer_baseline.yml` to compare a
full active-manifest calibration run with the last checked-in active-manifest
baseline. Filtered `--analyzer` reruns need a matching filtered baseline; see
[docs/project-analyzer-calibration.md](docs/project-analyzer-calibration.md) for
examples. Use `--print-baseline` to preview a compact refreshed baseline on
standard output without writing calibration artifacts.

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

## Requirements

- Ruby `>= 3.3`
- Bundler `4.0.8`
- A working compiler toolchain may be needed by transitive native gems on some platforms.

If your shell resolves to macOS system Ruby, switch to a Ruby `>= 3.3` before running Bundler.

## Contributing / Development

Before starting autonomous repo work, read [PROJECT_TRACKER.md](PROJECT_TRACKER.md)
for the current local direction, next queue, parked work, and the reason this
repo tracks agent coordination locally instead of only in GitHub Projects or
issues.

For durable code-level design exceptions, write a lightweight Design Decision
Record before finalizing the exception. See
[docs/design-decision-records.md](docs/design-decision-records.md).

Run the local checks:

```bash
bin/check_dogfood
bundle exec rake
bundle exec rubocop
bin/check_dependency_direction
bin/check_sample_app_frozen
```

`bin/check_dogfood` runs `metz-scan` against this repository with
`--project-analyzers` enabled and requires the optional `rubydex` bundle group.
It accepts zero project-analyzer findings. It fails if any
non-project-analyzer offense appears or if a project-analyzer finding appears.

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
