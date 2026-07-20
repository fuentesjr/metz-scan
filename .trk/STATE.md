# STATE

## Goal
v0.5.3 is released on rubygems.org and GitHub Packages; all four exit criteria met. Active direction is testing-discipline cops (docs/design/testing-cops.md): Tier 1 three cops stay opt-in after dogfood; Tier 2 TestCallsPrivateMethod landed as candidate/opt-in. Next product work is dogfood that analyzer then assess remaining rollout. Do not promote candidates to default output, change thresholds, or add app-specific suppressions without new generic evidence. 1.0.0 remains reserved.

## Dispatched

## Next
1. Assess remaining testing-cops rollout after that dogfood: TestTooManyAssertions is a weak candidate (likely drop per spec §10). Do not start a cop before its dogfooding evidence.

## Backlog
- issue-25-dogfood-ci — Parked: dogfood CI enforcement is trigger-gated; reopen only when collaboration expands beyond owner+Dependabot or CI-enforced dogfood becomes deliberate policy (2026-07-18T08:38Z)
- issue-27-deep-inheritance — Parked: DeepInheritanceTree; reopen only with new misleading root-label evidence not already covered by broad-root labels and downranking (2026-07-18T08:38Z)
- issue-28-repeated-branching — Parked: RepeatedBranching; reopen only with new evidence that generic low/context-required findings remain underexplained after README/metadata improvements (2026-07-18T08:38Z)
- fixture-coverage-sweeps — Parked as a class: reopen an individual fixture only when a defect shows that exact missing fixture would have caught it (2026-07-18T08:38Z)
- analyzer-threshold-policy — Do not change analyzer thresholds or promote candidates to default without new generic evidence (2026-07-18T08:38Z)
- test-too-many-assertions — Weak remaining testing-cop candidate; likely drop per docs/design/testing-cops.md §10 (2026-07-18T08:38Z)
