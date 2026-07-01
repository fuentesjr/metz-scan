# Sandi Metz project-analyzer candidates

Last updated: 2026-07-01.

This note records a read-only research pass for project-level analyzer ideas
grounded in Sandi Metz's OOP teaching. It excludes analyzers already
implemented or already under active consideration: `ServiceSoup`,
`RepeatedBranching`, `DeepInheritanceTree`, `PackageDependencyPressure`,
`NamespaceLeakPressure`, `ImplicitContextPressure`, `DeadCodeCandidates`, and broad
unstable-abstraction/concern heuristics.

## Implemented from this list

### `NamespaceLeakPressure`

Implemented as `MetzProject/NamespaceLeakPressure` candidate output. It reports
deeply nested declarations whose references spread outside the home namespace
into multiple coarse packages. It remains behind `--project-analyzers` until
real-project calibration proves the signal is sparse and reviewable.

### `ImplicitContextPressure`

Implemented as `MetzProject/ImplicitContextPressure` candidate output. The
first slice is AST-only and detects repeated Rails `CurrentAttributes`-style
access, such as `Current.account`, across multiple files and coarse packages.
It remains behind `--project-analyzers`; `Thread.current`, class variables,
singleton-style global access, and broader calibration are future scope.

## Candidate shortlist

### 1. `SubclassOverridePressure`

- Teaching fit: Sandi's public OOP material favors composition when broad
  inheritance starts hiding coupling.
- Source grounding:
  - Ruby Rogues POODR interview:
    https://topenddevs.com/podcasts/ruby-rogues/episodes/087-rr-book-club-practical-object-oriented-design-in-ruby-with-sandi-metz
  - RubyConf 2017 keynote:
    https://www.youtube.com/watch?v=VzWLGMtXflg
- Signal: a base class or module with several descendants where the same
  hook/template methods are overridden repeatedly, especially when subclasses
  rely on `super` chains.
- Required data: descendant graph plus method/override metadata. The current
  index does not expose this yet, so this needs an index extension.
- Likely false positives: framework base classes, STI, intentionally shared
  template-method patterns.
- Project-level: yes.
- Smallest viable fixture: an abstract base with three subclasses overriding
  the same `perform` or `build_client` hook.
- Feasibility: medium-low.

### 2. `RepeatedQueryCriteria`

- Teaching fit: this is an inference from tell-don't-ask and dependency
  isolation: repeated queries suggest callers know too much about retrieval
  rules and object state.
- Source grounding:
  - InformIT chapter on Managing Dependencies:
    https://www.informit.com/articles/article.aspx?p=1946176&seqNum=2
  - Ruby Rogues POODR interview:
    https://topenddevs.com/podcasts/ruby-rogues/episodes/087-rr-book-club-practical-object-oriented-design-in-ruby-with-sandi-metz
- Signal: the same `where`/scope/filter predicate fingerprint repeated across
  multiple files, suggesting a named query, policy object, or small collaborator
  should own that rule.
- Required data: AST collection over Ruby files. No project index is required
  for the first slice.
- Likely false positives: common admin filters, pagination/sorting chains,
  intentionally duplicated one-off lookups.
- Project-level: yes.
- Smallest viable fixture: the same multi-key query copied into a controller,
  a job, and a service.
- Feasibility: medium.

## Exclusions

- `ServiceSoup`, `RepeatedBranching`, `DeepInheritanceTree`,
  `PackageDependencyPressure`, `NamespaceLeakPressure`, and
  `ImplicitContextPressure` are already
  implemented or actively in scope.
- Callback-workflow analyzers are adjacent to existing design notes and were
  not treated as newly discovered candidates.
- Concern heuristics and raw inheritance-depth ideas overlap with already
  considered analyzer tracks.
