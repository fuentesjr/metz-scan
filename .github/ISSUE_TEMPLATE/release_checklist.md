---
name: Release checklist
about: Track a metz-scan and rubocop-metz release
title: "Release vX.Y.Z"
labels: release
assignees: ""
---

Tracking issue generated from `RELEASE_CHECKLIST.md`.

Versions:

- `metz-scan`: `X.Y.Z`
- `rubocop-metz`: `X.Y.Z`

## Verification

- [ ] Run the full test suite.

```bash
bundle exec rake
```

- [ ] Run RuboCop.

```bash
bundle exec rubocop
```

- [ ] Run repo guard scripts.

```bash
bin/check_dependency_direction
bin/check_sample_app_frozen
```

- [ ] Confirm CI is green on GitHub.

```bash
gh run list --repo fuentesjr/metz-scan --branch main --limit 5
```

## Package Metadata

- [ ] Confirm both versions are the intended release version.

```bash
ruby -Ilib -e 'require "metz_scan/version"; puts MetzScan::VERSION'
ruby -Irubocop-metz/lib -e 'require "rubocop/metz/version"; puts RuboCop::Metz::VERSION'
```

- [ ] Confirm gemspec metadata builds without warnings.

```bash
gem build metz-scan.gemspec
cd rubocop-metz && gem build rubocop-metz.gemspec && cd ..
```

- [ ] Inspect the built gem contents.

```bash
gem specification ./metz-scan-*.gem files
gem specification ./rubocop-metz/rubocop-metz-*.gem files
```

## Smoke Tests

- [ ] Run CLI help from the repo.

```bash
bundle exec metz-scan --help
bundle exec metz-scan rules
bundle exec metz-scan explain Metz/DemeterTrainWreck
```

- [ ] Run a scan against the sample fixture.

These commands are expected to exit nonzero when findings are reported; confirm
that the output is well-formed for each format.

```bash
bundle exec metz-scan scan test/fixtures/service_soup_app --project-analyzers --format text
bundle exec metz-scan scan test/fixtures/service_soup_app --project-analyzers --format json
bundle exec metz-scan scan test/fixtures/service_soup_app --project-analyzers --format sarif
bundle exec metz-scan scan test/fixtures/service_soup_app --project-analyzers --format gh-annotations
```

- [ ] Confirm dry-run auto-fix does not modify files.

```bash
git diff --quiet
bundle exec metz-scan scan test/fixtures/sample_app --auto-fix --dry-run
git diff --quiet
```

## Source Tag and GitHub Release

- [ ] Confirm the release tag does not already exist.

```bash
git fetch --tags
git tag --list "vX.Y.Z"
```

- [ ] Create and push an annotated tag for the commit being published.

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

- [ ] Create a GitHub Release with package links and the green CI run.

```bash
gh release create vX.Y.Z \
  --repo fuentesjr/metz-scan \
  --title "vX.Y.Z" \
  --notes-file /path/to/release-notes.md
```

## Publish Decision

- [ ] Confirm this is the version you want to publish publicly.
- [ ] Confirm you are authenticated to GitHub Packages.

GitHub Packages' RubyGems registry needs a token with `write:packages`.
Use the token already managed by `gh`; if it is missing that scope, refresh it
first. These commands write the token to `~/.gem/credentials` and do not print
it.

```bash
gh auth status
gh auth refresh -h github.com -s write:packages
GITHUB_PACKAGES_TOKEN="$(gh auth token)"
mkdir -p ~/.gem
printf -- "---\n:github: Bearer ${GITHUB_PACKAGES_TOKEN}\n" > ~/.gem/credentials
chmod 0600 ~/.gem/credentials
unset GITHUB_PACKAGES_TOKEN
```

- [ ] Publish `rubocop-metz` first to GitHub Packages.

```bash
gem push --key github \
  --host https://rubygems.pkg.github.com/fuentesjr \
  rubocop-metz/rubocop-metz-*.gem
```

- [ ] Publish `metz-scan` after `rubocop-metz` is available in GitHub Packages.

```bash
gem push --key github \
  --host https://rubygems.pkg.github.com/fuentesjr \
  metz-scan-*.gem
```

- [ ] Confirm both packages are visible under the repository or account packages.

```bash
gh api /users/fuentesjr/packages/rubygems/rubocop-metz --jq .html_url
gh api /users/fuentesjr/packages/rubygems/metz-scan --jq .html_url
```

## Cleanup

- [ ] Remove generated gem files after publishing or testing.

```bash
rm -f metz-scan-*.gem rubocop-metz/rubocop-metz-*.gem
```
