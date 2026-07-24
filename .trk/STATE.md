# STATE

## Goal
v0.5.3 is released on rubygems.org and GitHub Packages; all four exit criteria met. Active direction is testing-discipline cops: Tier 1 three cops and Tier 2 TestCallsPrivateMethod remain opt-in after dogfood; TestTooManyAssertions is dropped because community cops cover it. Assess the next product slice before implementation; do not promote candidates, change thresholds, or add suppressions without new generic evidence. 1.0.0 remains reserved.

## Dispatched

## Next
1. Revisit the operation-role classifier only with a larger fixed sample that includes generic reverse-call and service-DSL facts; do not implement path-based density.

## Backlog
- fixture-coverage-sweeps — Parked as a class: reopen an individual fixture only when a defect shows that exact missing fixture would have caught it (2026-07-18T08:38Z)
- analyzer-threshold-policy — Do not change analyzer thresholds or promote candidates to default without new generic evidence (2026-07-18T08:38Z)
