# Contributing

Thanks for helping improve `metz-scan` and `rubocop-metz`.

## Report a bug

Open a [bug report](https://github.com/fuentesjr/metz-scan/issues/new?template=bug_report.md)
when something fails, misreports, or surprises you. Include what you expected,
what you observed, a minimal repro if you have one, and your Ruby / gem
versions.

**Exit code note:** `metz-scan scan` exits `1` when it reports findings. That
means design pressure was found, not that the CLI crashed. Higher exit codes
are real failures.

## Propose a feature

Open a [feature request](https://github.com/fuentesjr/metz-scan/issues/new?template=feature_request.md)
when a workflow or rule would help real Ruby/Rails design review. Describe the
problem first, then the shape of a useful change.

## Security

Do not file public issues for vulnerabilities. See [SECURITY.md](SECURITY.md).

## Development setup

Requirements: Ruby `>= 3.3`, Bundler `4.0.8`.

```bash
git clone https://github.com/fuentesjr/metz-scan.git
cd metz-scan
gem install bundler -v 4.0.8
bundle install
bundle exec rake
bundle exec rubocop
```

Before pushing release or workflow changes, run `bin/check_ci_parity`. On
failure it prints a `clean clone preserved at` path and a `next action:`
command to reproduce the failed phase without local-only state. Full local
checks and build steps are in the README
[Contributing / Development](README.md#contributing--development) section.

## Maintainer coordination (optional)

External contributors can ignore this. Maintainers and coding agents coordinate
via [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md), and the `.trk/` work
tracker (`trk status --json`). Design-decision records live under
`docs/ddrs/`; longer working papers under `docs/maintainers/`.
