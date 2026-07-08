# Decision: Scope-Only RuboCop Config Loading

**Date:** 2026-07-08
**Author:** Codex
**Status:** Accepted

## Context / The Issue

Default `metz-scan scan` runs only `Metz/*` cops with stock Metz tuning, but it
still needs the target project's file scope so `AllCops: Exclude` and
`Metz/*: Exclude` keep working. RuboCop's normal `ConfigStore` path resolves
that scope by loading the whole project config. In RuboCop 1.88.0, that also
eagerly loads `plugins:`, `require:`, and `inherit_gem:` entries.

That made default mode crash on real targets whose `.rubocop.yml` references
RuboCop extension gems that are not in the bundle used to run `metz-scan`.

## Decision

Default mode will use a scope-only config loader for target-file discovery and
post-scan per-cop scope filtering. The loader parses RuboCop YAML with
`RuboCop::ConfigLoader.load_yaml_configuration`, preserves only Include/Exclude
scope data needed by `RuboCop::TargetFinder` and Metz cops, and skips plugin
and require integration.

`--all-cops` continues to use RuboCop's normal complete project-config loading.

## Rationale & Justification

The preferred product behavior is to keep honoring target file scope without
requiring users to install every target RuboCop extension just to run the
Metz-only default scan. RuboCop 1.88.0 does not expose a supported API that
resolves file scope while suppressing extension loading, so using the raw YAML
loader is the narrowest internal API exception.

The fallback alternative was to catch the plugin `LoadError`, warn, and scan
without honoring project scope. That would avoid the crash but would quietly
weaken the #33/#37 file-scope contract unless every user noticed the warning.

## Consequences / Impact

- Default scans can run against projects that declare absent RuboCop extension
  gems while still honoring local `AllCops: Exclude` and `Metz/*: Exclude`.
- Missing external config loaded through an absent `inherit_gem` cannot
  contribute scope because its files are unavailable; installed inherited
  configs are parsed scope-only.
- Future RuboCop upgrades must recheck the internal calls used here:
  `ConfigLoader.load_yaml_configuration`, `ConfigLoader.merge`, and
  `ConfigLoader.merge_with_default`.
