# metz-scan

`metz-scan` is a mono-repo with two deliverables:

- `metz-scan`: a CLI for running Metz-oriented design checks and reports.
- `rubocop-metz`: a RuboCop plugin that provides Metz cops.

## Requirements

- Ruby `>= 3.3`
- Bundler

## Setup

```bash
bundle install
```

## Usage

Run the CLI:

```bash
bundle exec metz-scan scan .
bundle exec metz-scan scan . --auto-fix
bundle exec metz-scan explain Metz/DemeterTrainWreck
```

Run RuboCop with the plugin:

```bash
bundle exec rubocop
```

## Test, Lint, and Repo Checks

Tests:

```bash
bundle exec rake
```

Lint:

```bash
bundle exec rubocop
```

Repo checks:

```bash
bin/check_dependency_direction
bin/check_sample_app_frozen
```

## Build

Build the CLI gem from the repo root:

```bash
gem build metz-scan.gemspec
```

Build the RuboCop plugin gem:

```bash
cd rubocop-metz && gem build rubocop-metz.gemspec
```
