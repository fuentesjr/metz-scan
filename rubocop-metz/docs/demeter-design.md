# `Metz/DemeterTrainWreck` — Design Decisions

This document records the resolved design decisions for the
`Metz/DemeterTrainWreck` cop. It is the source-of-truth for how the cop
behaves; the implementation in
`rubocop-metz/lib/rubocop/cop/metz/demeter_train_wreck.rb` and the
companion type-inference module follow the rules below.

The starting material is the research file
[`.mission-research/demeter-static-typing.md`](../../.mission-research/demeter-static-typing.md)
(referenced throughout as `demeter-static-typing.md`). Sections 1–5 of that
file establish the chain-walking primitives, the literal type predicates,
the proposed `METHOD_RETURN_TYPES` constant, the survey of prior art, and a
draft algorithm. Section 6 lists 12 open questions that this document now
resolves.

The cop's purpose is to flag Law-of-Demeter-violating *object-graph
traversals* — chains like `user.account.subscription.plan.name` — while
remaining quiet on long *value-object* chains like
`name.upcase.strip.split(' ').first`. The discriminator is static type
inference, not chain length alone. That is the defining trade-off the
research file calls out (see `demeter-static-typing.md` §5 and §6) and the
foundation every decision below builds on.

---

## Quick reference (the 12 questions)

| # | Topic                                                   | Decision (one-line)                                                                  |
|---|---------------------------------------------------------|--------------------------------------------------------------------------------------|
| 1 | Innermost receiver behavior                             | Reverse-lookup heuristic on the method name; unknown-only hops count.                 |
| 2 | String interpolation                                    | No special handling; RuboCop visits inner sends inside `dstr` nodes automatically.    |
| 3 | Implicit-self / explicit-self handling                  | `receiver.nil?` and `self_type?` both treated as unknown receiver.                    |
| 4 | Pass-through methods (`tap`/`then`/`yield_self`/`itself`/`dup`/`clone`/`freeze`) | Hard-coded transparent; no hop, type unchanged.       |
| 5 | Type-map location (Ruby constant vs YAML)               | Ruby constant `METHOD_RETURN_TYPES` in a frozen module.                               |
| 6 | csend (safe-nav) handling                               | `alias_method :on_csend, :on_send`; identical chain semantics.                        |
| 7 | `AllowedReceivers` and deep constants                   | Innermost constant match only; deep-constant chains out of scope for v0.1.            |
| 8 | Operator-method exclusion                               | Skip operator sends entirely (`arithmetic_operation?` and comparison operators).      |
| 9 | Setter / assignment handling                            | Skip when `setter_method?`; assignment terminates a chain, not extends it.            |
| 10 | Performance / caching                                  | Frozen literal map, lazy memoized `@allowed_receivers`; no per-link allocation.       |
| 11 | Severity                                               | `Severity: refactor` (valid RuboCop severity, advisory by default).                   |
| 12 | Structural vs typed mode                               | Ship `typed` mode only in v0.1; `Mode: structural` deferred to v0.2.                  |

The rest of the document expands each decision with the rationale, the
chosen implementation, and the alternative that was rejected.

---

## 1. Innermost receiver behavior

**Question.** What is the type of the *innermost receiver* in a chain like
`name.upcase.strip.split(' ').first`? `name` is a `(send nil :name)` node —
an implicit-self method call we cannot resolve statically. The naïve
algorithm marks `name`'s return type as `:unknown`, then every downstream
link inherits `:unknown`, and the whole chain is flagged as graph
traversal — which would fire on the canonical "good" example.

**Decision: reverse-lookup heuristic on the method name.** When the chain
walker encounters a link whose receiver type is `:unknown`, it inspects the
method name being invoked. If that method name appears in any value-object
entry of `METHOD_RETURN_TYPES` *and* its return type is consistent across
those entries, the cop assumes the unknown receiver was that value-object
type and propagates the call's return type forward. The link is counted as
"value-object" (free), not as a graph traversal.

Concretely:

- `name.upcase` — `upcase` exists on `:string` → assume `name` was a
  String; this hop is value-object (free); next type is `:string`.
- `account.subscription` — `subscription` is in no value-object map; this
  hop counts as a graph traversal; next type stays `:unknown`.

Only **adjacent unknown→unknown** transitions count as hops. A single
"unknown receiver, unknown method" link is one hop; a chain that immediately
escapes into known value-object territory pays nothing for the entry hop.
This matches the two canonical examples from `demeter-static-typing.md` §5:

- `name.upcase.strip.split(' ').first` (5 links): `name → upcase` resolves
  the receiver as String; the rest stay in String/Array; total hops = 0;
  silent.
- `user.account.subscription.plan.name` (5 links): no method name has a
  unique value-object reverse-lookup hit; all 5 are unknown→unknown hops;
  hops = 5 > `Max: 4`; fires.

**Innermost-receiver special cases:**

- `lvar` / `ivar` / `cvar` / `gvar` (local/instance/class/global variables)
  → type is `:unknown` regardless of name.
- `(self)` and `(receiver: nil)` → type is `:unknown` (see §3).
- `const` reference → checked against `AllowedReceivers` first (§7); if
  matched, the entire chain is exempt; otherwise type is `:unknown`.
- Literal node (`str`, `int`, `array`, …) → typed via `LITERAL_MAP`
  (`demeter-static-typing.md` §3).

Why this and not the alternatives:

- "First hop is always free" (rejected): false-negatives on the canonical
  bad example — `user.account.subscription.plan.name` becomes 4 hops and
  doesn't fire.
- "Require explicit `AssumeValueObjectMethods` opt-in" (rejected): every
  user has to recreate the same list; the recommended heuristic from
  `demeter-static-typing.md` §6 Q1 wins on usability.
- "Reverse-lookup on method name with collision tolerance" (chosen): only
  consider the lookup *unambiguous* if all matching value-object types
  agree on a return type. If two value-object types claim the same method
  with different return types, fall back to `:unknown`.

The reverse map is built once at load time from `METHOD_RETURN_TYPES`
(see §5).

---

## 2. String interpolation handling

**Question.** When a `dstr` (interpolated string) node such as
`"Hello, #{user.account.name}"` contains a chain inside its
interpolation, should the cop walk inside the interpolation or rely on
RuboCop's standard tree traversal?

**Decision: no special handling for interpolation.** RuboCop's commander
walks the AST recursively and dispatches `on_send` (and `on_csend`) on
every `send` node it encounters, including those nested inside
`(dstr ... (begin (send ...)) ...)`. The chain analyzer anchors on the
*outermost* send of each chain (via `part_of_outer_chain?`), so the
chain inside an interpolation is analyzed exactly once.

**Implication for tests:** the fixture suite includes a test asserting
that `"#{user.account.subscription.plan.name}"` produces the same offense
count as the bare expression — proving the interpolation case piggybacks
on the same code path. No `on_dstr` handler is needed.

---

## 3. Implicit-self and explicit-self receivers

**Question.** Should `foo.bar.baz` (where `foo` is implicit-self) and
`self.foo.bar.baz` behave identically?

**Decision: yes, both treated as unknown receiver.** In the `infer_type`
helper, both `receiver.nil?` and `receiver.self_type?` resolve to
`:unknown`. The chain walker does not distinguish between an `(send nil
:foo)` (implicit) and `(send (self) :foo)` (explicit-self): both are
"start of chain, type unknown", and the reverse-lookup heuristic from §1
takes over from there.

This matches the rationale in `demeter-static-typing.md` §6 Q3: there is
no static way to know what `self` is in a refactored method body, and
splitting the two cases would surprise users without buying any
precision. The explicit-self case `self.thing.foo.bar.baz.qux` (5 links, all
unknown -> 5 hops) fires once at `Max: 4`.

---

## 4. Pass-through methods (`tap`, `then`, `yield_self`, `itself`,
`dup`, `clone`, `freeze`)

**Question.** Methods like `tap`, `then`, and `itself` return `self` (or
its equivalent). Should they consume a hop in the chain count, or be
transparent?

**Decision: hard-coded transparent, no hop, type unchanged.** A
constant `PASS_THROUGH = %i[tap then yield_self itself dup clone
freeze].to_set.freeze` lists the methods. When the chain walker
encounters a link whose `method_name` is in `PASS_THROUGH`:

- `hops` is not incremented;
- the propagated type is left untouched;
- the block argument (if any, e.g. `tap { |x| ... }`) is ignored for
  chain-length purposes — its body is its own AST subtree visited
  separately by RuboCop's recursion.

Why a constant rather than a config knob in v0.1: the seven names are
ergonomic Ruby idioms (Object#tap, Object#then, Kernel#itself,
Object#freeze, etc.) used the same way across every Ruby codebase. There
is no precedent for projects redefining what `tap` means; making this
configurable would invite accidental drift. If a real demand surfaces,
v0.2 can promote it to `AllowedPassThroughMethods` without breaking
anyone.

This realises `demeter-static-typing.md` §6 Q4 directly. The chain
`obj.tap { _1.log }.foo.bar.itself.baz` collapses to four unknown-graph hops
(`obj`, `foo`, `bar`, `baz`) and does NOT fire at `Max: 4`.

---

## 5. Type-map location: Ruby constant vs YAML

**Question.** Where does `METHOD_RETURN_TYPES` live — in
`config/default.yml` (or a sibling YAML file) or as a Ruby constant
inside the gem's `lib/`?

**Decision: a frozen Ruby constant.** The `METHOD_RETURN_TYPES` map is a
top-level constant in
`rubocop-metz/lib/rubocop/cop/metz/demeter_train_wreck/type_inference.rb`,
defined as a frozen Hash whose values are frozen Hashes. The constant is
deeply frozen at load time; no runtime mutation is allowed.

Why Ruby constant beats YAML here:

- **Operator method names.** Symbols like `:+`, `:-`, `:*`, `:[]`,
  `:[]=`, `:<=>` are first-class hash keys in Ruby. YAML can quote them
  but the syntax is awkward and parser-dependent (`"+":` is not the same
  as `:+:` in YAML 1.1 vs YAML 1.2 implementations). Ruby Symbols also
  match exactly what `node.method_name` returns from rubocop-ast — no
  conversion layer needed.
- **Load cost.** YAML must be parsed every time a cop instance is
  constructed (RuboCop instantiates one cop per file under analysis,
  multiplied by parallel workers). A Ruby constant is loaded once when
  the gem is required and never re-parsed.
- **Static validation.** Ruby code is rejected by `gem build` if it
  contains a syntax error; a typo in a YAML symbol key is silent until
  runtime.
- **Configurability is a non-goal.** Users do not need to extend the type
  map — extending it would expose them to false-positive risk that we
  cannot test. The cop is configurable through `Max`,
  `AllowedReceivers`, `AllowedValueObjects`, `Mode`, and `Severity`; the
  type map itself is a sealed implementation detail.

The constant lives at:

```ruby
module RuboCop::Cop::Metz::DemeterTrainWreck::TypeInference
  METHOD_RETURN_TYPES = { string: { ... }, symbol: { ... }, ... }.freeze
end
```

The full content is the table from `demeter-static-typing.md` §3, frozen
at the per-type-hash level. `LITERAL_MAP` (literal node-type → value-object
type) lives next to it.

---

## 6. csend (safe-navigation) handling

**Question.** How are safe-navigation chains (`a&.b&.c&.d`) handled? Does
the cop walk them at all, and if so, how?

**Decision: csend is treated identically to send.** Every Metz cop
honours the project-wide csend invariant (`AGENTS.md` "csend invariant"):
this cop defines `on_send(node)`, then `alias_method :on_csend, :on_send`
at the bottom of the class. `chain_links(node)` already calls
`current.type?(:send, :csend)` so safe-nav links are collected the same
way as dot links.

Why identical, not different:

- The Demeter rule is about object-graph traversal depth; whether the
  links are guarded with `&.` against nil does not change the graph
  shape. `user&.account&.subscription&.plan&.name` is exactly the same
  refactor problem as `user.account.subscription.plan.name`.
- `MethodDispatchNode` (the rubocop-ast mixin) gives `csend` nodes the
  same `receiver` and `method_name` accessors as `send`, so the chain
  walker code is unchanged.
- Mixed `&.` / `.` chains are still chains. `Lint/SafeNavigationChain`
  flags the *correctness* problem of mixing them; our cop flags the
  *depth* problem on whichever style is used.

This means a 5-link chain in safe-nav style fires exactly one offense, the
same as the non-safe-nav version. It also satisfies the project-wide csend
invariant audit.

---

## 7. `AllowedReceivers` and deep constants

**Question.** `AllowedReceivers` exempts chains rooted at certain
constants (`Rails`, `Arel`, `Time`, `Date`, `DateTime`). What about
chains rooted at *deeper* constant paths like `Rails.application` or
`ActiveRecord::Base`?

**Decision: only the innermost constant receiver is matched against
`AllowedReceivers` in v0.1.** When `chain_links(node)` produces its
inner-to-outer list, the cop checks whether `links.first.receiver` is a
`(const)` node whose `const_name` is in the configured `AllowedReceivers`
list. If so, the entire chain is exempt and zero offenses are produced;
otherwise standard analysis runs.

Implication: `Rails.application.config.action_controller.perform_caching`
is exempt because `Rails` is the innermost constant. But
`Rails.application.cache.fetch(...).config.x.y.z` is also exempt for the
same reason; users who want to flag *that* should remove `Rails` from
`AllowedReceivers`. This is the trade-off the research file flagged
(`demeter-static-typing.md` §6 Q7).

What about deep constants — chains rooted at things like
`ActiveRecord::Base` (a `(const (const nil :ActiveRecord) :Base)` node)?
Two cases:

- **Top-level deep constants** (`ActiveRecord::Base`,
  `Foo::Bar`): the innermost-const check uses
  `node.const_name`, which on rubocop-ast returns the fully qualified
  name (`"ActiveRecord::Base"`). To exempt `ActiveRecord::Base.find(1).x`
  the user would add `"ActiveRecord::Base"` to `AllowedReceivers`.
  Supported in v0.1.
- **Receiver chains like `Rails.application.config`** (a `(send (send
  (const nil :Rails) :application) :config)` node): only `Rails` itself
  is matched. v0.1 does NOT support exempting partial chains.

Future work: a separate `AllowedReceiverChains` knob (e.g.
`AllowedReceiverChains: ['Rails.application.config']`) could match a
prefix on the chain and exempt downstream links. This is deliberately
deferred to v0.2 to keep the v0.1 surface tight.

A chain rooted at `Rails` produces zero offenses with the default config.

---

## 8. Operator-method exclusion

**Question.** Operator chains like `a + b + c + d + e` parse as nested
send nodes (`(send (send (send (send a :+ b) :+ c) :+ d) :+ e)`).
Without exclusion, a 5-operator arithmetic expression would fire under
`Max: 4`, which is wrong — this is not a Demeter violation.

**Decision: operator methods are excluded from chain analysis.** The
cop checks `node.arithmetic_operation?` (a built-in
`MethodDispatchNode` predicate covering `+ - * / % **`) plus a
hard-coded list of comparison and bitwise operators (`COMPARISON_OPS =
%i[== != < > <= >= <=> === =~ !~]`, `BITWISE_OPS = %i[& | ^ << >>]`),
and skips analysis when the *outermost* send is an operator method. We
also filter operator links out of `chain_links` itself: an operator send
inside a chain (rare but possible, e.g. `(a + b).foo.bar`) does not
contribute to the hop count.

Concretely:

```ruby
OPERATOR_METHODS = (
  %i[+ - * / % **] + %i[== != < > <= >= <=> === =~ !~] + %i[& | ^ << >>]
).to_set.freeze

def operator_send?(node)
  node.type?(:send, :csend) && OPERATOR_METHODS.include?(node.method_name)
end
```

Operator sends have a different syntactic shape (binary infix in source,
nested `send` in AST) and a different semantic — they do not traverse an
object graph. Treating them as Demeter violations would produce noise
and confuse users. This matches `demeter-static-typing.md` §6 Q8:
`a + b + c + d + e` produces zero offenses.

---

## 9. Setter methods and assignment handling

**Question.** Setter sends like `obj.foo = bar` and indexing
assignments like `arr[0] = bar` parse as send nodes with method names
`:foo=` and `:[]=`. Should they participate in chain analysis?

**Decision: setter and assignment sends are skipped.** The check is
`node.setter_method?` (built into `MethodDispatchNode`, returns true
when `method_name` ends with `=`). When the outermost send is a setter,
the cop returns early without walking the chain. When a setter appears
*inside* a chain (`obj.foo = bar` inside a larger expression — rare,
since `=` is right-associative and terminates an expression), the chain
walker stops at it.

The rationale follows `demeter-static-typing.md` §6 Q9: setters
terminate a chain in source order, they cannot be the start of a new
graph traversal in the same expression, and `attr_writer`-style chains
should not double-count a write. Indexing assignment (`arr[0] = bar`,
method name `:[]=`) is treated identically: also a setter, also skipped.

A non-assigning bracket call (`arr[0]`, method name `:[]`) is a regular
chain link and *is* analyzed. `:[]` is in `OPERATOR_METHODS` (§8) so it
is also excluded — collection indexing is not a Demeter hop. (Both
exclusions agree, so the order of checks does not matter.)

---

## 10. Performance and caching

**Question.** Each chain link does two hash lookups
(`METHOD_RETURN_TYPES.dig(type, method)`). On a 100k-LOC project with
many chains, does this add up?

**Decision: ship as-is with frozen constants and instance-level
memoization; profile only if needed.** The performance plan:

- **Frozen literal map.** `METHOD_RETURN_TYPES` and its inner hashes are
  `.freeze`d at module load. No per-link allocation; lookups are O(1)
  hash hits on Ruby's standard Hash.
- **Frozen `PASS_THROUGH` and `OPERATOR_METHODS`.** Both are
  `.to_set.freeze`d at module load.
- **Lazy memoized config readers.** `allowed_receivers` is computed once
  per cop instance (`@allowed_receivers ||= ...`) and reused across
  every `on_send` invocation. Same for `max`.
- **No regex on hot path.** Chain detection uses node type predicates
  (`type?(:send, :csend)`), not regex on method names. Operator
  detection uses set membership.
- **Reverse-lookup map computed once.** The reverse map (method name →
  inferred value-object type, see §1) is built lazily and memoized at
  the module level (`@@reverse_map ||= ...`) on first use, then frozen.

We do not introduce any per-file or per-chain caching beyond what
RuboCop itself provides. RuboCop already memoizes `cop_config` per file;
that is sufficient. Profiling (`bundle exec rubocop --profile`) is
deferred to a v0.2 micro-optimization sweep if the cop shows up in the
top-N hot cops on a real project.

This matches `demeter-static-typing.md` §6 Q10's recommendation. The
"caching" lever (reverse-lookup memoization) is documented here so
future maintainers don't re-derive it.

---

## 11. Severity

**Question.** What `Severity:` value does the cop ship with by default?
Is `refactor` a valid RuboCop severity?

**Decision: `Severity: refactor`.** RuboCop accepts five severity
levels — `info`, `warning`, `convention`, `refactor`, `error`, `fatal`
— and `refactor` is the canonical advisory level for "this code works
but should be reorganized." It is documented in
[RuboCop's manual](https://docs.rubocop.org/rubocop/configuration.html#severity).

Concrete behaviour at this severity:

- `bundle exec rubocop` without `--fail-level` exits 0 on a project
  that has only `refactor`-level offenses (RuboCop's default
  `--fail-level` is `convention`, which is a higher threshold).
- `bundle exec rubocop --fail-level refactor` surfaces refactor
  offenses as a non-zero exit, gating CI when desired.
- Developers see the offense in editor output (rubocop-lsp) without
  the build going red.

This is the right default for an advisory cop on a chain pattern that
has legitimate cases. Users who want stricter behaviour use their own
`.rubocop.yml` to override.

---

## 12. Structural vs typed mode

**Question.** Should the cop expose a `Mode:` knob letting users opt
into a strict structural rule (any chain longer than `Max` = bad,
without the value-object filter)?

**Decision: ship `typed` mode only in v0.1; `structural` is deferred to
v0.2.** The cop ships with a single behaviour: the typed analyzer
described above. There is no `Mode:` config in `config/default.yml` for
v0.1.

Why defer `structural`:

- `Style/SafeNavigationChainLength` already exists as a structural
  chain-length cop for `&.` chains. Users who want pure structural
  enforcement on dot chains have a much narrower problem and would be
  better served by a focused future cop (`Metz/ChainLength`) rather
  than a mode toggle on `Metz/DemeterTrainWreck`.
- A mode toggle doubles the test surface (every behaviour case must be
  covered in both modes) and complicates the cop's mental model. In
  v0.1 we want to nail the typed behaviour first.
- Adding `Mode: typed | structural` later is non-breaking: existing
  users have implicit `Mode: typed` and no behaviour change. The knob
  can land in v0.2 with a single new YAML key and an `if mode ==
  :structural` branch in `count_graph_traversals`.

The decision to ship typed-only matches `demeter-static-typing.md` §6
Q12.

---

## Default configuration (recap)

The cop's `rubocop-metz/config/default.yml` entry locks in the
decisions above:

```yaml
Metz/DemeterTrainWreck:
  Description: 'Detects Law-of-Demeter-violating object-graph traversal chains.'
  Enabled: true
  Severity: refactor
  Max: 4
  AllowedReceivers: [Rails, Arel, Time, Date, DateTime]
  AllowedValueObjects: [String, Integer, Float, Symbol, Array, Hash, Set]
  Exclude:
    - 'spec/**/*'
    - 'db/migrate/**/*'
  VersionAdded: '0.1'
```

Notes:

- `Max: 4` permits chains up to four object-graph hops. The threshold
  comes from `metz_scan_design.md` and Sandi Metz's
  "demeter-as-a-smell" reading: three or fewer hops is the comfortable
  range, four is borderline, five and above is a refactor smell.
- `AllowedValueObjects` is informational in v0.1: the actual value-object
  recognition is hard-wired in `LITERAL_MAP` and `METHOD_RETURN_TYPES`.
  A v0.2 may consult this list to disable, e.g., `Hash` recognition for
  domain Hash subclasses.
- `Exclude` skips test code and migrations: tests routinely set up deep
  fixtures (`build_stubbed(:user, account: build_stubbed(:account, ...))`)
  and migrations are short-lived enough that depth is a non-issue.

---

## Decision keyword index

To make the design choices grep-discoverable, the same topics are
listed here with the alternative phrasings used elsewhere in the
mission documents:

- innermost receiver — see §1
- interpolation — see §2
- implicit (self) — see §3
- pass-through|tap (transparent methods) — see §4
- type map|Ruby constant (where the type table lives) — see §5
- csend|safe-nav (`&.` chains) — see §6
- AllowedReceivers|deep constants — see §7
- operator (arithmetic and comparison sends) — see §8
- setter|assignment — see §9
- performance|caching — see §10
- severity (`refactor` level) — see §11
- structural|typed (`Mode:`) — see §12

## Cross-references

- Source research: [`.mission-research/demeter-static-typing.md`](../../.mission-research/demeter-static-typing.md)
  (referred to by filename `demeter-static-typing.md` throughout this
  document)
- Algorithm sketch: `demeter-static-typing.md` §5
- Type map source: `demeter-static-typing.md` §3
- Open questions resolved: `demeter-static-typing.md` §6 (this document
  closes Q1–Q12)
- Historical validation IDs: [milestone-history.md](../../docs/milestone-history.md)
- csend invariant (project-wide): `AGENTS.md` "csend invariant"
- Safe-navigation bridge and metadata DSL:
  (`rubocop-metz/lib/rubocop/cop/metz/on_send_csend_bridge.rb`,
  `rubocop-metz/lib/metz/cop_metadata.rb`)
