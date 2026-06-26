# Sandi Metz project-analyzer candidates

Last updated: 2026-06-26.

This note records a read-only research pass for project-level analyzer ideas
grounded in Sandi Metz's OOP teaching. It excludes analyzers already
implemented or already under active consideration: `ServiceSoup`,
`RepeatedBranching`, `DeepInheritanceTree`, `PackageDependencyPressure`,
`DeadCodeCandidates`, and broad unstable-abstraction/concern heuristics.

## Candidate shortlist

### 1. `NamespaceLeakPressure`

- Teaching fit: Sandi's dependency-management guidance is about keeping
  dependencies explicit, isolated, and not smuggling class knowledge across
  boundaries.
- Source grounding:
  - InformIT chapter on Managing Dependencies:
    https://www.informit.com/articles/article.aspx?p=1946176&seqNum=2
  - Ruby Rogues POODR interview:
    https://topenddevs.com/podcasts/ruby-rogues/episodes/087-rr-book-club-practical-object-oriented-design-in-ruby-with-sandi-metz
- Signal: flag nested declarations whose constants are referenced outside
  their home namespace or package, especially when the same internal constant
  leaks into two or more distinct packages or layers.
- Required data: declarations, constant references, and namespace/package
  grouping. This is feasible with the current `ProjectIndex`.
- Likely false positives: intentionally public namespaced APIs, engine
  boundaries, value-object namespaces, generated scaffolding.
- Project-level: yes.
- Smallest viable fixture: `Billing::Ledger::PrivateFormatter` referenced by
  both a controller and a job outside `Billing::Ledger`.
- Feasibility: high.

### 2. `ImplicitContextPressure`

- Teaching fit: dependency isolation plus message-passing: systems are easier
  to reason about when dependencies are explicit rather than ambient.
- Source grounding:
  - InformIT chapter on Managing Dependencies:
    https://www.informit.com/articles/article.aspx?p=1946176&seqNum=2
  - Ruby Rogues POODR interview:
    https://topenddevs.com/podcasts/ruby-rogues/episodes/087-rr-book-club-practical-object-oriented-design-in-ruby-with-sandi-metz
- Signal: repeated reliance on shared ambient context or mutable process/request
  state across multiple files or layers, such as `Current`, `Thread.current`,
  class variables, or singleton-style global access.
- Required data: AST-level collection across files. A first slice does not need
  the project index.
- Likely false positives: legitimate Rails `CurrentAttributes`, request-scoped
  context, cache/configuration glue, instrumentation.
- Project-level: yes.
- Smallest viable fixture: a controller writes `Current.account`, and a job and
  service read `Current.account`.
- Feasibility: medium-high.

### 3. `SubclassOverridePressure`

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

### 4. `RepeatedQueryCriteria`

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

- `ServiceSoup`, `RepeatedBranching`, `DeepInheritanceTree`, and
  `PackageDependencyPressure` are already implemented or actively in scope.
- Callback-workflow analyzers are adjacent to existing design notes and were
  not treated as newly discovered candidates.
- Concern heuristics and raw inheritance-depth ideas overlap with already
  considered analyzer tracks.
