# Design: Metz testing-discipline cops

Status: **roadmap with rollout in progress.** This document is the specification
and evidence bar for testing-discipline cops; implementation proceeds one
opt-in slice at a time.

Last updated: 2026-07-09.

Implementation status (2026-07-09): rollout in progress. `Metz/TestReachesPrivate`
(§9 step 2), `Metz/TestAssertsOnInternals` (§5), and `Metz/TestStubsSubject`
(§5) are implemented and shipped opt-in (`Enabled: false`). `TestStubsSubject`
is RSpec-only: RSpec has an explicit subject token, while general Minitest
subject inference would flood false positives. `TestReachesPrivate` was
dogfooded (accurate but too dense → stays opt-in,
`docs/dogfooding/2026-07-08-test-reaches-private.md`). Deliberate deviations
from this spec, decided during implementation:

- **`public_send` is NOT flagged** (spec §5 listed it). It can only invoke
  public methods, so flagging it contradicts the cop's principle and is a
  guaranteed false positive; core `Style/SendWithLiteralMethodName` already owns
  the pointless-indirection angle. Detection is `send`/`__send__` only.
- **The `TestFrameworks` support module is deferred** (spec §4 and the §1
  day-one lock assumed it). The shipped cops either scope by file-glob `Include`
  and key off specific method sends, or are RSpec-shaped enough to keep subject
  tracking inline. There is still no real both-framework consumer for a shared
  module.

Decisions locked by the requesting session:

- **Frameworks:** Minitest **and** RSpec where a rule has a low-noise signal in
  both frameworks; `TestStubsSubject` is the documented RSpec-only exception.
- **Scope:** the statically-detectable smell subset (AST-only) **plus**
  Rubydex-index-backed visibility rules (the latter delivered as project
  analyzers in the wrapper, not cops — see §5 Tier 2).
- **Sequencing:** spec now; implement cop-by-cop after release, dogfooding each
  before it becomes default output.

## 1. Motivation: an identity gap

`rubocop-metz` originally shipped six design cops — `ClassesTooLong`, `MethodsTooLong`,
`DemeterTrainWreck`, `MethodsTooManyParameters`,
`ControllersTooManyDirectCollaborators`, `ViewsDeepNavigation`. Every one
targets a **design** smell (size, coupling, fan-out). None encodes Sandi
Metz's **testing** discipline, even though *Magic Tricks of Testing* and POODR
ch. 9 are as central to her teaching as her object-design rules. For a
Metz-branded linter that is a real gap.

It is not, however, an oversight of the "just add the cops" kind. The design
cops are framework-agnostic and apply to any Ruby file — `DemeterTrainWreck`
fires on Minitest `test/` code today, though note its shipped config already
carves out `Exclude: spec/**/*`, so the design/testing split is not perfectly
orthogonal in practice (see §3, principle 3). Testing cops are a distinct,
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
   scopes to `app/controllers`. Testing cops never fire on app code. Design
   cops mostly keep firing on tests, with one shipped exception:
   `DemeterTrainWreck` excludes `spec/**/*` by default, so the families are
   orthogonal in intent but not perfectly in current config — any future claim
   of orthogonality must account for that carve-out.
4. **Earn default output.** New cops ship implemented and `Enabled`, but their
   promotion to *default scan output* is a separate, calibrated decision per the
   default-output-policy escalation rule. Each cop stays evidence-gated (opt-in
   or generous threshold) until real-repo dogfooding proves a sparse,
   reviewable signal — same discipline as the project analyzers.
5. **Reuse the existing cop conventions.** `extend ::Metz::CopMetadata`
   (`why_it_matters` / `fix_safety` / `suggested_next_moves`), an `MSG`
   constant, and — for every `on_send` cop — `include OnSendCsendBridge` so
   `&.` is handled identically (a repo invariant).
6. **Dependency direction preserved.** Tier 1 (AST-only) cops live under
   `rubocop-metz/` and must never reference `MetzScan`/`metz_scan`. Tier 2
   rules need the Rubydex index, whose `RubydexBackend`/`NullBackend` plumbing
   lives in the wrapper (`lib/metz_scan/project_index.rb`) — so Tier 2 ships as
   **project analyzers** in `lib/metz_scan/analyzers/`, not as cops (see §5
   Tier 2 for the decision and tradeoff). This keeps the dependency direction
   intact and avoids inventing per-file index injection inside RuboCop's
   engine.

## 4. Framework handling

A shared support module (proposed `RuboCop::Cop::Metz::TestFrameworks`) answers
two questions so cops stay framework-neutral (file-level scoping is already
handled by RuboCop's engine via each cop's `Include` globs — the module does
not re-check paths):

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

### Prior art (rubocop-rspec / rubocop-minitest)

The community plugins already cover parts of this catalog, and the spec must
position against them rather than silently re-implement:

| Proposed | Existing coverage |
| --- | --- |
| `TestStubsSubject` | `RSpec/SubjectStub` (RSpec only) — including a battle-tested subject-identification heuristic |
| `TestTooManyAssertions` | `RSpec/MultipleExpectations` **and** `Minitest/MultipleAssertions` — both ecosystems already ship this |
| `TestAssertsOnInternals` | `RSpec/InstanceVariable` (partial, RSpec only, different rule shape) |
| `TestReachesPrivate` / `test_calls_private_method` | none in either plugin |

What is genuinely novel here: (1) Metz-branded delivery of testing discipline
alongside the design cops; (2) the literal-`send` + **index-confirmed privacy**
pair, which neither plugin attempts; (3) Metz metadata (`why_it_matters` etc.)
driving `explain` and enriched output. Where an existing cop has solved a
heuristic we need (notably `RSpec/SubjectStub`'s subject detection, see §10),
reuse its approach — do not re-derive it. Where a rule is already well-served
in both ecosystems (`TestTooManyAssertions`), the bar for a Metz-branded
duplicate is correspondingly higher.

### Tier 1 — AST-only (no index required)

#### `Metz/TestReachesPrivate`
- **Principle:** test the interface, not the implementation.
- **Detects:** `send` / `__send__` / `public_send` with a **literal** symbol or
  string first argument, inside a test case — the canonical "reach past the
  public interface" move. AST alone cannot confirm the target is private, so
  Tier 1 flags literal `send` in tests at **low confidence** (opt-in); Tier 2
  (`test_calls_private_method`) confirms privacy via the index. The two must
  not double-report: when the index is available and confirms privacy, only
  the Tier 2 finding surfaces; the Tier 1 cop is the fallback signal for
  index-less runs, not an additional one.
- **FP risk:** legitimate metaprogramming, dynamic dispatch of *public* methods,
  frameworks that require `send`. Mitigation: literal-arg only; low confidence;
  `AllowedReceivers`/`AllowedMethods` config escape hatch.
- **`on_send`** → include `OnSendCsendBridge`.

#### `Metz/TestAssertsOnInternals`
- **Principle:** don't bind tests to implementation state.
- **Detects:** `instance_variable_get` / `instance_variable_set` on any
  receiver inside a test case, and Rails controller-test `assigns(:ivar)`
  (rails-controller-testing) — the real-world pattern for asserting on a SUT's
  internal state. Note: bare `@ivar` reads in a test body are **not** a
  signal — they refer to the test class's own fixture state (`@user = ...` in
  `setup` is ubiquitous), and a SUT's ivar is unreachable by bare-`@ivar`
  syntax anyway; flagging them would be a false-positive flood.
- **FP risk:** low for `instance_variable_get/_set` and `assigns`. Occasional
  legitimate legacy-state assertions → `AllowedMethods`.

#### `Metz/TestStubsSubject`
- **Principle:** don't mock the object you are testing; minimize doubles.
- **Detects (high signal, RSpec-only):** stubbing/mocking the subject under
  test via `expect(subject).to receive`, `allow(subject).to receive`,
  `is_expected.to receive`, named `subject(:name)` / `subject!(:name)`, inherited
  subject names, negated runners, spies, and nested stub matchers. `let`/`let!`
  with the same symbol subtracts that name from the subject set so collaborators
  can be safely overridden.
- **FP risk:** low for RSpec's explicit subject token. Minitest remains deferred:
  no equivalent subject token exists, and inferring from arbitrary locals or
  `described_class` instances floods false positives.

#### `Metz/TestTooManyAssertions`  *(candidate — weakest Sandi tie, weakest novelty)*
- **Principle:** sparse, focused tests ("test one thing"). Closer to
  Meszaros/xUnit than to Sandi specifically; included as a candidate, not a
  headline cop.
- **Detects:** assertion/expectation count per test case exceeds a generous
  `Max`.
- **FP risk:** legitimately multi-fact tests. Generous default, opt-in.
- **Prior art:** already shipped in *both* ecosystems
  (`RSpec/MultipleExpectations`, `Minitest/MultipleAssertions`), which weakens
  the case further — a Metz version must justify itself beyond "framework
  neutrality" (users can enable both existing cops today). Default stance:
  probably drop; see §10.

### Tier 2 — Rubydex-index-backed (cross-file visibility): project analyzers, not cops

**Architecture decision.** The `RubydexBackend`/`NullBackend` plumbing lives in
the wrapper (`lib/metz_scan/project_index.rb`), and `rubocop-metz` must never
reference `MetzScan` (dependency direction, enforced by
`bin/check_dependency_direction`). RuboCop cops also run per-file inside
RuboCop's engine, with no natural home for a project-wide index. So Tier 2
rules ship as **project analyzers** in `lib/metz_scan/analyzers/`, exactly like
the four existing index-backed analyzers — snake_case class with
`PROJECT_ANALYZER_STATUS` / `TRIAGE_SUMMARY`, surfaced via
`project_analyzers`, not via `--only Metz` cop runs.

The alternative — giving `rubocop-metz` its own optional `rubydex` dependency
plus index-injection machinery inside the RuboCop engine — was considered and
rejected: it adds a dependency (an escalation item), invents new plumbing for a
problem the wrapper already solves, and splits the index behind two backends.
The accepted tradeoff is that the Tier 1 cop / Tier 2 analyzer pair for the
private-method rule spans both products.

Analyzer conventions apply: `RubydexBackend` when the optional `rubydex` bundle
group is present, `NullBackend` (zero findings) otherwise. **Never** write a
test assuming the index is installed — use the
`test/support/missing_rubydex.rb` pattern for both paths.

#### `test_calls_private_method` (analyzer)
- **Principle:** don't test private methods (the confirmed form of
  `TestReachesPrivate`).
- **Detects:** a test invokes a method that the index resolves as `private` /
  `protected` on the corresponding production class. High signal, low FP.
- **Dependency:** index only; contributes zero findings under `NullBackend`.
  When it does run, it supersedes `Metz/TestReachesPrivate` for the same call
  site (no double-reporting; see Tier 1).

#### `test_depends_on_unowned_return` (analyzer)  *(speculative — needs research)*
- **Principle:** don't test outgoing query messages (don't assert on the return
  value of a message to a collaborator you don't own).
- **Status:** even with the index, distinguishing "owned" from "unowned"
  collaborators and query-vs-command is hard. Listed for completeness as a
  **deep-research candidate**, not a committed analyzer. Do not implement
  without a separate design pass proving the signal.

## 6. Architecture & conventions

- **Namespace:** Tier 1 cops keep the `Metz/` prefix with a `Test*` naming
  convention (e.g. `Metz/TestReachesPrivate`) rather than a new top-level
  namespace — preserves the brand, the metadata DSL, and `OnSendCsendBridge`.
  The test-vs-design split is expressed by `Include` scope, not by namespace.
  Tier 2 rules are wrapper-side project analyzers (snake_case, §5 Tier 2) and
  follow analyzer conventions, not cop conventions.
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

- Add test-file fixtures under `rubocop-metz/test/` exercising each Tier 1
  cop's positive and negative cases, for **both** frameworks; Tier 2 analyzer
  tests live wrapper-side and follow the existing index-backed analyzer
  test conventions (including the missing-rubydex both-paths pattern).
- Before any cop is promoted to default output, dogfood it against real repos
  with substantial Minitest and RSpec suites (the calibration targets already
  include large apps). Record false-positive rate; a cop earns default output
  only when the signal is sparse and reviewable, same bar as the project
  analyzers.
- Index-backed testing analyzers get a Rubydex-drift check alongside the
  existing four index-backed analyzers.

## 9. Rollout sequencing (post-release)

1. Land this spec (this slice) + roadmap entry. No cop code.
2. Implement **`Metz/TestReachesPrivate`** end-to-end as the template (cop +
   metadata + both-framework fixtures + docs), opt-in.
3. Dogfood it; fix FP patterns; decide default-output eligibility.
4. Repeat for `TestAssertsOnInternals`, `TestStubsSubject`, then the
   index-backed `test_calls_private_method` analyzer (wrapper-side slice,
   including its drift-check entry). Candidates (`TestTooManyAssertions`,
   `test_depends_on_unowned_return`) only if evidence warrants.
5. Each cop is its own reviewable slice with its own dogfooding round.

## 10. Open questions

- **Minitest subject inference for `TestStubsSubject`** — deferred. RSpec's
  explicit `subject` / `is_expected` token is implemented; `described_class`,
  arbitrary locals, and Minitest `sut.stub` are intentionally not inferred
  without stronger evidence.
- **ActiveSupport `test "..."` blocks** and `let`/`subject` DSLs — how much of
  the RSpec/Rails DSL surface to cover in the first `TestFrameworks` cut.
- **Default severity** — `refactor` (matching current cops) vs. a softer
  advisory level for the noisier candidates.
- Whether `TestTooManyAssertions` belongs in a Metz-branded tool at all, given
  its weaker tie to Sandi specifically **and** that both
  `RSpec/MultipleExpectations` and `Minitest/MultipleAssertions` already exist
  (see §5 Prior art). Current lean: drop it and recommend the community cops
  instead.
