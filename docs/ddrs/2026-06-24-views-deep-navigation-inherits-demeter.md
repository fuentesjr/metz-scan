# Decision: Use Inheritance for View Deep Navigation

**Date:** 2026-06-24
**Author:** Codex
**Status:** Accepted

## Context / The Issue

`RuboCop::Cop::Metz::ViewsDeepNavigation` flags deep object-graph traversal in
Rails view templates. Its behavior is intentionally a narrower version of
`RuboCop::Cop::Metz::DemeterTrainWreck`: it uses the same send-chain walker,
same value-object inference, and same safe-navigation handling, while changing
the file scope, message, and threshold.

The design rule under pressure is "prefer composition over inheritance." This
rule is a useful default because broad inheritance trees can hide coupling.
Here, however, the view-specific cop is not merely sharing unrelated helper
methods. It is specializing the Demeter cop's algorithm for a narrower target
surface.

## Decision

We will keep `ViewsDeepNavigation` as a subclass of `DemeterTrainWreck`.

## Rationale & Justification

This is a bounded inheritance use where the subclass is a true specialization
of the parent behavior. A deep navigation chain in a view is still a Demeter
train wreck; the view cop changes the reporting context, not the underlying
analysis model.

The main benefits are:

- the chain-walking algorithm stays single-sourced;
- safe-navigation behavior remains identical to `DemeterTrainWreck`;
- value-object false-positive avoidance remains identical;
- the subclass only overrides the parts that differ: file relevance, message,
  and max threshold;
- RuboCop already models cops as classes with inherited dispatch behavior.

The main trade-off is coupling. Changes to `DemeterTrainWreck` can affect
`ViewsDeepNavigation`, so maintainers must treat the parent algorithm as shared
behavior and keep view-specific tests in place.

Composition was considered. It would require extracting the chain walker and
type-inference interaction behind a new object or module. That may become the
right design if more cops reuse the same algorithm, but doing it now would
expose more internal surface area for one concrete specialization.

## Consequences / Impact

Short term, `ViewsDeepNavigation` stays compact and continues to inherit
`DemeterTrainWreck` behavior directly.

Long term, changes to `DemeterTrainWreck` must consider both normal Ruby files
and view-template scans. The inheritance should be revisited if:

- another cop needs the same chain-walking algorithm;
- the view-specific behavior diverges beyond file scope, message, and
  threshold;
- tests become brittle because the parent class exposes too much behavior to
  the subclass;
- a narrow composed chain-analysis object emerges with a smaller public
  interface than inheritance provides today.
