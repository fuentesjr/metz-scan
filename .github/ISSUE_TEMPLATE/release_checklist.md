---
name: Release checklist
about: Track a metz-scan and rubocop-metz release
title: "Release vX.Y.Z"
labels: release
assignees: ""
---

Tracking issue generated from `RELEASE_CHECKLIST.md`.

Preview the generated issue locally without GitHub access:

```bash
bin/create_release_issue --dry-run
```

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

- [ ] Run the read-only maintenance command guard.

```bash
bin/check_read_only_commands
```

- [ ] Run calibration artifact smoke against the sample app.

```bash
bundle exec ruby bin/check_project_analyzer_calibration --text --no-write test/fixtures/sample_app
```

- [ ] Run the GitHub annotations smoke that CI uses.

```bash
fixture_dir="$(mktemp -d)"
cp -R test/fixtures/service_soup_app "$fixture_dir/service_soup_app"
set +e
bundle exec metz-scan scan "$fixture_dir/service_soup_app" \
  --project-analyzers \
  --format gh-annotations > /tmp/metz-gh-annotations.out
status=$?
set -e
rm -rf "$fixture_dir"
cat /tmp/metz-gh-annotations.out
test "$status" -eq 1
grep -q '^::warning file=.*MetzProject/ServiceSoup' /tmp/metz-gh-annotations.out
```

- [ ] Run the CI-parity check. It clones the committed HEAD into a temp dir
  without local bundler config or untracked files and runs the single-command
  CI steps there, so local-only environment assumptions fail before a push. It
  also runs tracker hygiene before Bundler work and preserves the clean clone
  path when a phase fails. On failure, use the printed
  `clean clone preserved at` path and `next action:` command to reproduce the
  failed phase in that clone.

```bash
bin/check_ci_parity
```

- [ ] Inspect recent CI runs on GitHub.

```bash
gh run list --repo fuentesjr/metz-scan --branch main --limit 5
```

## Package Metadata

- [ ] Confirm both versions are the intended release version.

```bash
ruby -Ilib -e 'require "metz_scan/version"; puts MetzScan::VERSION'
ruby -Irubocop-metz/lib -e 'require "rubocop/metz/version"; puts RuboCop::Metz::VERSION'
```

- [ ] Run release metadata and release issue smoke tests.

```bash
bundle exec ruby -Ilib -Itest test/metz_scan/release_metadata_test.rb
bundle exec ruby -Ilib -Itest test/metz_scan/create_release_issue_test.rb
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
bundle exec metz-scan project-analyzers
bundle exec metz-scan explain Metz/DemeterTrainWreck
```

- [ ] Run a scan against the sample fixture.

These commands are expected to exit nonzero when findings are reported; confirm
that the output is well-formed for each format. Copy the fixture outside this
repository first because the repo RuboCop config excludes this fixture tree.

```bash
fixture_dir="$(mktemp -d)"
cp -R test/fixtures/service_soup_app "$fixture_dir/service_soup_app"
bundle exec metz-scan scan "$fixture_dir/service_soup_app" --format text
bundle exec metz-scan scan "$fixture_dir/service_soup_app" --project-analyzers --format text
bundle exec metz-scan scan "$fixture_dir/service_soup_app" --project-analyzers --format json
bundle exec metz-scan scan "$fixture_dir/service_soup_app" --project-analyzers --format sarif
bundle exec metz-scan scan "$fixture_dir/service_soup_app" --project-analyzers --format gh-annotations
rm -rf "$fixture_dir"
```

- [ ] Confirm dry-run auto-fix does not modify files.

```bash
git diff --quiet
autofix_dir="$(mktemp -d)"
cp -R test/fixtures/service_soup_app "$autofix_dir/service_soup_app"
bundle exec metz-scan scan "$autofix_dir/service_soup_app" --auto-fix --dry-run
diff -qr test/fixtures/service_soup_app "$autofix_dir/service_soup_app"
git diff --quiet
rm -rf "$autofix_dir"
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

## Post-Publish Smoke Test

- [ ] Run the published-gem smoke check; it creates a clean temporary consumer
  project outside this checkout.

```bash
bin/check_published_gem X.Y.Z
```

## Cleanup

- [ ] Remove generated gem files after publishing or testing.

```bash
rm -f metz-scan-*.gem rubocop-metz/rubocop-metz-*.gem
```
