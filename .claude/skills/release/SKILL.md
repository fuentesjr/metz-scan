---
name: release
description: "Run a metz-scan/rubocop-metz release to GitHub Packages and rubygems.org: version-target prep commit, verification, tag, GitHub Release, ordered gem publish, post-publish smoke, and record-keeping. Use when the user asks to prepare, cut, or publish a release, or to verify one. Publishing and tagging always require explicit user authorization."
---

# Release runbook (GitHub Packages and rubygems.org)

This wraps `RELEASE_CHECKLIST.md` with the decisions and pitfalls the checklist
does not spell out. The checklist's commands are canonical — follow it
step-by-step; this skill tells you what to decide, in what order, and where
agents have gone wrong before.

**Hard boundary:** creating the tag, cutting the GitHub Release, and every
`gem push` require explicit user authorization in this session. Prep and
verification do not. rubygems.org is a standing release target: after the
GitHub Packages publish and smoke check, the owner pushes both gems there by
hand, in the same order.

## Phase 1 — choose the version (a decision, not a mechanical bump)

- Patch (`0.5.0` → `0.5.1`): pure defect fixes, no default-behavior change.
- Minor: any default-behavior change or new user-visible surface. Precedent:
  #31 changed default scan output, forcing `0.5.0` instead of `0.4.1`
  (`docs/maintainers/implementation-notes.md` 2026-07-05).
- Do not use `1.0.0`; it remains reserved (`.trk/STATE.md` goal).

## Phase 2 — prep commit (one commit, shape of `3ec8f29`)

Touch exactly these surfaces:

1. `lib/metz_scan/version.rb` and `rubocop-metz/lib/rubocop/metz/version.rb`.
2. `Gemfile.lock` — run `bundle install`; the gemspec pin
   `"~> #{MetzScan::VERSION}"` (the `add_dependency "rubocop-metz"` line in
   `metz-scan.gemspec`) carries the PATH constraint automatically. Do not
   hand-edit the lockfile.
3. Release-issue dry-run expectations: `test/metz_scan/create_release_issue_test.rb`
   pins the version string (`release_metadata_test.rb` compares the gemspecs
   and needs no edit).
4. `docs/releases/vX.Y.Z.md` — release notes draft; model on
   `docs/releases/v0.6.0.md` (issue-centric, upgrade notes only if behavior
   changed; Release Links cover GitHub Packages and rubygems.org). Add it to
   `docs/releases/README.md`.
5. README install example only if the current `~>` constraint no longer
   resolves to the new version (it pins `~> 0.6.0` as of `0.6.0`).
6. `.trk/` update via `trk log` / `trk goal` as needed for the prep
   (orchestrator only; see `AGENTS.md`).

Then run the full gauntlet from the `land-slice` skill, including
`CI_PARITY_FULL=1 bin/check_ci_parity` (parity now runs a reduced subset by
default; force the full suite for a release prep) on the committed prep. Main is branch-protected
(required `test` check), so push the prep as a branch and merge it via PR, only
when the user authorized pushing. Then wait for the green main push run on the
merge commit before asking to tag. Verify with
`gh run list --repo fuentesjr/metz-scan --branch main --limit 3`.

## Phase 3 — tag, GitHub Release, publish (authorization required)

Ask the user for release authorization, then follow
`RELEASE_CHECKLIST.md` sections "Source Tag and GitHub Release" and
"Publish Decision" exactly. Non-obvious constraints:

- Tag the merge commit of the prep PR after its main push run is green (as
  done for v0.6.0), not a later checkpoint commit.
- rubygems.org publishing is done by the owner by hand; agent `gem push` to
  rubygems.org is permission-blocked.
- **Publish order matters:** `rubocop-metz` first, then `metz-scan` — the
  wrapper's dependency must be resolvable at push time.
- Credentials: use the `gh`-managed token with `write:packages` scope, written
  to `~/.gem/credentials` per the checklist. Never echo the token.
- `gem build` both gems fresh; inspect with `gem specification ... files`.

## Phase 4 — post-publish verification (never skip)

```bash
bin/check_published_gem X.Y.Z
```

This builds a clean temporary consumer project resolving from GitHub Packages
and must PASS. When a release carries a specific fix, spot-check the fix is
live in the consumer output (precedent: confirming the `Controller method`
label for #34 in `0.5.1`). Then:

- Comment release links on the issues the release carries, and close them if
  still open (issue writes need user approval — batch the ask with the publish
  authorization).
- `rm -f metz-scan-*.gem rubocop-metz/rubocop-metz-*.gem`.
- Record completion: `trk log` for the release plus a short
  `docs/maintainers/implementation-notes.md` entry (shape of "2026-07-06: v0.5.1 release
  completion"). This record commit is real project work, not tracker churn.

## Known failure modes

- `check_ci_parity` red on prep almost always means the version-pinned test
  listed in Phase 2 step 3 was missed.
- Publishing `metz-scan` before `rubocop-metz` is visible → consumer resolution
  failure; `bin/check_published_gem` catches it, fix by waiting/republishing in
  order.
- `bin/check_published_gem` failures include redacted Bundler output and
  credential hints — read them before touching credentials.
- Tag already exists (`git tag --list vX.Y.Z` non-empty): stop and ask; never
  move or delete a published tag.
