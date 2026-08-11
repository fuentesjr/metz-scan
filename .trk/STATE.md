# STATE

## Goal
v0.5.3 is released on rubygems.org and GitHub Packages; all four exit criteria met. Active direction is testing-discipline cops: Tier 1 three cops and Tier 2 TestCallsPrivateMethod remain opt-in after dogfood; TestTooManyAssertions is dropped because community cops cover it. Assess the next product slice before implementation; do not promote candidates, change thresholds, or add suppressions without new generic evidence. 1.0.0 remains reserved.

## Dispatched

## Next
1. Revisit the operation-role classifier only with a larger fixed sample that includes generic reverse-call and service-DSL facts; do not implement path-based density.
2. Docs pass: revisit the README project-analyzer narrative now that RuboCop 1.89 ships native opt-in cross-file indexing (`AllCops/UseProjectIndex` + rubydex, experimental). Position metz-scan's project analyzers relative to upstream (what ours adds: descendants/reference queries, method visibility, NullBackend degradation, calibration pipeline) rather than implying cross-file analysis is unique to metz-scan. Docs-freshness tests pin README content — update deliberately, don't loosen.

## Backlog
- fixture-coverage-sweeps — Parked as a class: reopen an individual fixture only when a defect shows that exact missing fixture would have caught it (2026-07-18T08:38Z)
- analyzer-threshold-policy — Do not change analyzer thresholds or promote candidates to default without new generic evidence (2026-07-18T08:38Z)
- rubocop-native-project-index-migration — Watch: RuboCop 1.89 injects a rubydex Rubydex::Graph into every cop (plugins included) via public Cop::Base#project_index (base.rb:44, runner.rb:501) plus a ProjectIndexHelp mixin (constant resolution, ancestry checks, result-cache invalidation) — the infrastructure MetzScan::ProjectIndex built CLI-side. Migrating index-backed analyzers (inheritance_descendants, package_dependency_pressure, namespace_leak_pressure, subclass_override_pressure) into real index-aware Metz cops would delete bespoke infrastructure and make findings first-class offenses (all formatters, LSP, disable comments). Deliberately deferred: upstream API is marked experimental and is one release old; scan runner's --force-default-config keeps UseProjectIndex off (would need explicit plumbing); calibration pipeline assumes the CLI-side model. Revisit when the experimental label drops or after ~2 releases of API stability; meanwhile shape new index-backed analyzer work to be migration-friendly. Architecture decision — user sign-off required before migrating. (2026-08-11T01:17Z)
