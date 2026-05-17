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
bundle exec metz-scan scan spec/fixtures/sample_app --format text || true
```

The sample app intentionally contains violations, so the scan command prints findings and exits nonzero.

## Usage

List the available Metz cops:

```bash
bundle exec metz-scan rules
bundle exec metz-scan rules --json
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
```

Run safe auto-correction or preview it first:

```bash
bundle exec metz-scan scan . --auto-fix --dry-run
bundle exec metz-scan scan . --auto-fix
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

For the release checklist, see [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

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
| Output format | `metz-scan scan --format text\|json\|sarif` | `text` is for humans; `json` and `sarif` are for tools. |
| Auto-fix safety | `--auto-fix`, `--unsafe`, `--dry-run` | Safe fixes use RuboCop `-a`; unsafe fixes use RuboCop `-A`. |
| Environment variables | N/A | `metz-scan` does not require environment variables. |

## Requirements

- Ruby `>= 3.3`
- Bundler `4.0.8`
- A working compiler toolchain may be needed by transitive native gems on some platforms.

If your shell resolves to macOS system Ruby, switch to a Ruby `>= 3.3` before running Bundler.

## Contributing / Development

Run the local checks:

```bash
bundle exec rake
bundle exec rubocop
bin/check_dependency_direction
bin/check_sample_app_frozen
```

Build both gems:

```bash
gem build metz-scan.gemspec
cd rubocop-metz && gem build rubocop-metz.gemspec && cd ..
```

File bugs and feature work in GitHub issues: https://github.com/fuentesjr/metz-scan/issues

## License

MIT. See [LICENSE](LICENSE).
