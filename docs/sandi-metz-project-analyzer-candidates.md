# Sandi Metz project-analyzer candidates

Last updated: 2026-07-02.

This note records a read-only research pass for project-level analyzer ideas
grounded in Sandi Metz's OOP teaching. It excludes analyzers already
implemented or already under active consideration: `ServiceSoup`,
`RepeatedBranching`, `DeepInheritanceTree`, `PackageDependencyPressure`,
`NamespaceLeakPressure`, `ImplicitContextPressure`,
`RepeatedQueryCriteria`, `SubclassOverridePressure`, `DeadCodeCandidates`, and
broad unstable-abstraction or concern heuristics.

## Implemented from this list

### `NamespaceLeakPressure`

Implemented as `MetzProject/NamespaceLeakPressure` candidate output. It reports
deeply nested declarations whose references spread outside the home namespace
into multiple coarse packages. It remains behind `--project-analyzers` until
real-project calibration proves the signal is sparse and reviewable.

### `ImplicitContextPressure`

Implemented as `MetzProject/ImplicitContextPressure` candidate output. The
first slice is AST-only and detects repeated Rails `CurrentAttributes`-style
access, such as `Current.account` or `Spree::Current.store`, across multiple
files and coarse packages. It classifies root vs namespaced `Current` access
and whether the repeated access includes writes. It remains behind
`--project-analyzers`;
`Thread.current`, class variables, singleton-style global access, and broader
calibration are future scope.

### `RepeatedQueryCriteria`

Implemented as `MetzProject/RepeatedQueryCriteria` candidate output. The first
slice is AST-only and detects repeated constant-receiver `where` hash criteria,
such as `Order.where(account_id: ..., status: ...)`, across multiple files and
coarse packages. It classifies polymorphic, compound-association,
association-scoped, and generic hash-criteria repeats. It remains behind
`--project-analyzers`; dynamic SQL strings, scope-chain fingerprints, and
broader query/filter forms are future scope.

### `SubclassOverridePressure`

Implemented as `MetzProject/SubclassOverridePressure` candidate output. The
first slice is index-backed and detects base classes whose known descendants
override the same base-declared method in at least six subclasses. It now
records conservative base-method body facts and descendant `super` usage so
override families can be classified as broad-root, abstract-hook, cooperative,
replacement, or unclassified signals with category-specific report language.
It remains behind `--project-analyzers`; narrower calibration of deliberate
framework extension points and any future confidence or severity weighting are
future scope.

## Candidate shortlist

No active shortlist item remains from this research pass.

## Exclusions

- `ServiceSoup`, `RepeatedBranching`, `DeepInheritanceTree`,
  `PackageDependencyPressure`, `NamespaceLeakPressure`, and
  `ImplicitContextPressure`, `RepeatedQueryCriteria`, and
  `SubclassOverridePressure` are already
  implemented or actively in scope.
- Callback-workflow analyzers are adjacent to existing design notes and were
  not treated as newly discovered candidates.
- Concern heuristics and raw inheritance-depth ideas overlap with already
  considered analyzer tracks.
