# Design: Metz testing-discipline cops

Status: **design proposal, not yet implemented.** Post-release roadmap
(see `PROJECT_TRACKER.md` "Path to rubygems.org"). This document is the
specification and evidence bar; implementation is deliberately deferred until
after the first public release so it does not expand the surface being
stabilized for v1.

Last updated: 2026-07-07.

Decisions locked by the requesting session:

- **Frameworks:** Minitest **and** RSpec from day one, via framework-neutral
  rule definitions with per-framework matchers.
- **Scope:** the statically-detectable smell subset (AST-only) **plus**
  Rubydex-index-backed visibility rules.
- **Sequencing:** spec now; implement cop-by-cop after release, dogfooding each
  before it becomes default output.

## 1. Motivation: an identity gap

`rubocop-metz` ships six cops — `ClassesTooLong`, `MethodsTooLong`,
`DemeterTrainWreck`, `MethodsTooManyParameters`,
`ControllersTooManyDirectCollaborators`, `ViewsDeepNavigation`. Every one
targets a **design** smell (size, coupling, fan-out). None encodes Sandi
Metz's **testing** discipline, even though *Magic Tricks of Testing* and POODR
ch. 9 are as central to her teaching as her object-design rules. For a
Metz-branded linter that is a real gap.

It is not, however, an oversight of the "just add the cops" kind. The design
cops are framework-agnostic and apply to any Ruby file (which is why
`DemeterTrainWreck` already fires on test code). Testing cops are a distinct,
harder category because most of Sandi's testing rules are **not statically
detectable** from a single file's AST. The spec has to start from what *is*
detectable, not from the book's taxonomy — otherwise we ship cops that
hallucinate.

## 2. The governing constraint: detectability

Sandi's rules are defined by **message origin and type** — incoming query,
incoming command, outgoing query, outgoing command, self-sent. A RuboCop cop
sees one file's AST. It cannot generally know whether `foo.bar` is a query to a
collaborator it doesn't own or an incoming message under test, nor whether the
method under test is `private` (that visibility lives in the production class,
a different file). Mapping her rules to detectability:

| Sandi rule | Detectable from generic AST? | Path |
| --- | --- | --- |
| Don't test private methods | Partially | `send(:sym)` literal in a test is a single-file signal; privacy confirmed only with the index |
| Don't assert on internal state | Yes | `instance_variable_get/_set`, asserting on `@ivar` |
| Don't over-mock; don't stub the subject under test | Yes | count doubles; detect stubbing the SUT |
| One assertion of concern per test | Yes | assertion count per test case |
| Don't test outgoing *query* messages | No | needs query-vs-incoming classification |
| Do assert outgoing *commands* are sent | No | detecting a *missing* expectation is infeasible |
| Don't test self-sent messages | No | needs visibility/semantic info |

The bottom three rows are **non-goals** (§7): we will not attempt to encode
rules we cannot detect without hallucinating. The tool's only lever toward the
visibility-dependent rows is the optional **Rubydex index** already used by the
project-index analyzers — that is Tier 2.

This mirrors the evidence bar the tracker already sets for generic classifier
behavior: *generic, non-app-specific facts must separate a real smell from a
false positive before the cop is trusted.*

## 3. Design principles

1. **Detectability-first.** A rule is a candidate only if generic AST facts (or
   generic index facts) can flag it without app-specific knowledge and without
   a false-positive flood. If it can't, it is a non-goal, documented as such.
2. **Framework-neutral rules, pluggable matchers.** Each cop expresses its rule
   against an abstraction ("am I in a test case?", "what are the assertion /
   double / expectation sends here?"). A shared `TestFrameworks` support module
   supplies Minitest and RSpec matchers. Rule logic never branches on framework
   inline.
3. **Self-scoping via `Include`.** Each cop's `config/default.yml` entry carries
   `Include` globs for test paths, exactly as `ControllersTooManyDirect­Collaborators`
   scopes to `app/controllers`. Testing cops never fire on app code; design
   cops keep firing on tests. The two families are orthogonal.
4. **Earn default output.** New cops ship implemented and `Enabled`, but their
   promotion to *default scan output* is a separate, calibrated decision per the
   default-output-policy escalation rule. Each cop stays evidence-gated (opt-in
   or generous threshold) until real-repo dogfooding proves a sparse,
   reviewable signal — same discipline as the project analyzers.
5. **Reuse the existing cop conventions.** `extend ::Metz::CopMetadata`
   (`why_it_matters` / `fix_safety` / `suggested_next_moves`), an `MSG`
   constant, and — for every `on_send` cop — `include OnSendCsendBridge` so
   `&.` is handled identically (a repo invariant).
6. **Dependency direction preserved.** All new code lives under `rubocop-metz/`
   and must never reference `MetzScan`/`metz_scan`.

## 4. Framework handling

A shared support module (proposed `RuboCop::Cop::Metz::TestFrameworks`) answers
three questions so cops stay framework-neutral:

- **Is this a test file?** Path matches the cop's `Include` globs, or filename
  is `*_test.rb` / `*_spec.rb`.
- **Am I inside a test case?**
  - Minitest: a `def test_*` method, or a block passed to `test "..."`
    (ActiveSupport::TestCase).
  - RSpec: an `it` / `specify` / `example` block (inside `describe` / `context`).
- **What are the assertion / expectation / double sends?**
  - Minitest assertions: `assert*`, `refute*`; doubles: `Minitest::Mock.new`,
    `.expect`, `stub`.
  - RSpec expectations: `expect(...)`, `is_expected`, legacy `should`; doubles:
    `double`, `instance_double`, `spy`, `allow(...).to receive`,
    `expect(...).to receive`.

Each cop consumes this abstraction; adding a third framework later means
extending the module, not touching the cops.

## 5. Cop catalog

Each entry: the Sandi principle, detection strategy, per-framework specifics,
false-positive analysis, and default-output stance. Names are proposals.

### Tier 1 — AST-only (no index required)

#### `Metz/TestReachesPrivate`
- **Principle:** test the interface, not the implementation.
- **Detects:** `send` / `__send__` / `public_send` with a **literal** symbol or
  string first argument, inside a test case — the canonical "reach past the
  public interface" move. AST alone cannot confirm the target is private, so
  Tier 1 flags literal `send` in tests at **low confidence** (opt-in); Tier 2
  (`TestCallsPrivateMethod`) confirms privacy via the index.
- **FP risk:** legitimate metaprogramming, dynamic dispatch of *public* methods,
  frameworks that require `send`. Mitigation: literal-arg only; low confidence;
  `AllowedReceivers`/`AllowedMethods` config escape hatch.
- **`on_send`** → include `OnSendCsendBridge`.

#### `Metz/TestAssertsOnInternals`
- **Principle:** don't bind tests to implementation state.
- **Detects:** `instance_variable_get` / `instance_variable_set` on the subject,
  and assertions whose target is an `@ivar` read of the SUT.
- **FP risk:** low. Occasional legitimate legacy-state assertions →
  `AllowedMethods`.

#### `Metz/TestStubsSubject`
- **Principle:** don't mock the object you are testing; minimize doubles.
- **Detects (high signal):** stubbing/mocking the subject under test —
  `allow(subject).to receive`, `expect(sut).to receive`, or Minitest `sut.stub`
  where the receiver is the case's subject. Optionally a companion
  `Metz/TestTooManyDoubles` counts doubles per case above a `Max` (noisier,
  candidate-only).
- **FP risk:** identifying "the subject" heuristically (named `subject`, the
  `described_class` instance, or the receiver most-asserted-on). Ship
  conservative: only flag the unambiguous cases.

#### `Metz/TestTooManyAssertions`  *(candidate — weakest Sandi tie)*
- **Principle:** sparse, focused tests ("test one thing"). Closer to
  Meszaros/xUnit than to Sandi specifically; included as a candidate, not a
  headline cop.
- **Detects:** assertion/expectation count per test case exceeds a generous
  `Max`.
- **FP risk:** legitimately multi-fact tests. Generous default, opt-in.

### Tier 2 — Rubydex-index-backed (cross-file visibility)

These follow the existing index-backed pattern: `RubydexBackend` when the
optional `rubydex` bundle group is present, `NullBackend` (zero findings)
otherwise. **Never** write a test assuming the index is installed — use the
`test/support/missing_rubydex.rb` pattern for both paths.

#### `Metz/TestCallsPrivateMethod`
- **Principle:** don't test private methods (the confirmed form of
  `TestReachesPrivate`).
- **Detects:** a test invokes a method that the index resolves as `private` /
  `protected` on the corresponding production class. High signal, low FP.
- **Dependency:** index only; contributes zero findings under `NullBackend`.

#### `Metz/TestDependsOnUnownedReturn`  *(speculative — needs research)*
- **Principle:** don't test outgoing query messages (don't assert on the return
  value of a message to a collaborator you don't own).
- **Status:** even with the index, distinguishing "owned" from "unowned"
  collaborators and query-vs-command is hard. Listed for completeness as a
  **deep-research candidate**, not a committed cop. Do not implement without a
  separate design pass proving the signal.

## 6. Architecture & conventions

- **Namespace:** keep the `Metz/` prefix with a `Test*` naming convention (e.g.
  `Metz/TestReachesPrivate`) rather than a new top-level namespace — preserves
  the brand, the metadata DSL, and `OnSendCsendBridge`. The test-vs-design
  split is expressed by `Include` scope, not by namespace.
- **Config (`rubocop-metz/config/default.yml`):** each cop gets an entry with
  `Description`, `Enabled`, `Severity: refactor`, its `Include` test globs, and
  any `Max` / `AllowedMethods` / `AllowedReceivers`. Default-output promotion is
  gated on calibration (principle 4).
- **Metadata:** `why_it_matters`, `fix_safety`, `suggested_next_moves` for every
  cop — these drive `explain` and the enriched JSON/SARIF output, and are
  pinned by `cop_metadata_test.rb`.
- **`OnSendCsendBridge`** on every `on_send` cop.
- **Docs are test-enforced.** New cops touch README analyzer/cop docs, the
  skill content, and exact-output fixtures; expect the freshness tests
  (`readme_*`, `metz_scan_skill_test`) and exact-output fixtures to need
  deliberate updates in the same commit.

## 7. Explicit non-goals

We will **not** attempt cops for rules we cannot detect without hallucinating:

- Classifying incoming query vs. incoming command messages.
- Asserting that an outgoing **command** is sent (detecting a *missing*
  expectation).
- Rules about **self-sent** messages / internal message flow.

Documenting these as non-goals is deliberate: it stops a future session from
"completing the matrix" with cops that produce noise.

## 8. Calibration & dogfooding plan

Reuse the existing calibration/dogfooding machinery:

- Add test-file fixtures under `rubocop-metz/test/` exercising each cop's
  positive and negative cases, for **both** frameworks.
- Before any cop is promoted to default output, dogfood it against real repos
  with substantial Minitest and RSpec suites (the calibration targets already
  include large apps). Record false-positive rate; a cop earns default output
  only when the signal is sparse and reviewable, same bar as the project
  analyzers.
- Index-backed cops get a Rubydex-drift check alongside the existing four.

## 9. Rollout sequencing (post-release)

1. Land this spec (this slice) + roadmap entry. No cop code.
2. After v1 ships, implement **`Metz/TestReachesPrivate`** end-to-end as the
   template (cop + metadata + both-framework fixtures + docs), opt-in.
3. Dogfood it; fix FP patterns; decide default-output eligibility.
4. Repeat for `TestAssertsOnInternals`, `TestStubsSubject`, then the index-backed
   `TestCallsPrivateMethod`. Candidates (`TestTooManyAssertions`,
   `TestDependsOnUnownedReturn`) only if evidence warrants.
5. Each cop is its own reviewable slice with its own dogfooding round.

## 10. Open questions

- **"Subject under test" heuristic** for `TestStubsSubject` — named `subject`,
  `described_class`, most-asserted receiver? Needs a small spike on real specs.
- **ActiveSupport `test "..."` blocks** and `let`/`subject` DSLs — how much of
  the RSpec/Rails DSL surface to cover in the first `TestFrameworks` cut.
- **Default severity** — `refactor` (matching current cops) vs. a softer
  advisory level for the noisier candidates.
- Whether `TestTooManyAssertions` belongs in a Metz-branded tool at all, given
  its weaker tie to Sandi specifically.
