# STATE

## Goal
v0.5.3 is released on rubygems.org and GitHub Packages; all four exit criteria met. Active direction is testing-discipline cops: Tier 1 three cops and Tier 2 TestCallsPrivateMethod remain opt-in after dogfood; TestTooManyAssertions is dropped because community cops cover it. Assess the next product slice before implementation; do not promote candidates, change thresholds, or add suppressions without new generic evidence. 1.0.0 remains reserved.

## Dispatched

## Next
1. Define and measure a generic operation-role classifier on a new fixed sample before revisiting OperationDirectoryDensity; do not implement path-based density.

## Backlog
- issue-25-dogfood-ci — Parked: dogfood CI enforcement is trigger-gated; reopen only when collaboration expands beyond owner+Dependabot or CI-enforced dogfood becomes deliberate policy (2026-07-18T08:38Z)
- issue-27-deep-inheritance — Parked: DeepInheritanceTree; reopen only with new misleading root-label evidence not already covered by broad-root labels and downranking (2026-07-18T08:38Z)
- issue-28-repeated-branching — Parked: RepeatedBranching; reopen only with new evidence that generic low/context-required findings remain underexplained after README/metadata improvements (2026-07-18T08:38Z)
- fixture-coverage-sweeps — Parked as a class: reopen an individual fixture only when a defect shows that exact missing fixture would have caught it (2026-07-18T08:38Z)
- analyzer-threshold-policy — Do not change analyzer thresholds or promote candidates to default without new generic evidence (2026-07-18T08:38Z)
