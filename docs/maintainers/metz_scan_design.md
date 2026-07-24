# `rubocop-metz` + `metz-scan` architecture

> Historical note (2026-06-24): this document records the original design intent.
> Some paths and proposed components below predate the current implementation. The current tree uses
> `rubocop-metz/` at the repository root, `bin/metz-scan` for the CLI, scan renderers under
> `lib/metz_scan/commands/scan/`, and project analyzers under `lib/metz_scan/analyzers/`.

This design uses a **RuboCop extension gem** for file-local rule detection and correction, plus a thin wrapper CLI for richer reporting and project-level heuristics. That split matches RuboCop’s plugin model, custom cop APIs, formatter support, and safe versus unsafe autocorrect behavior, while leaving room for higher-order checks that do not map cleanly to a single cop.[web:32][web:26][web:37][web:7]

## Why this shape

RuboCop already provides the hard parts for a v1 implementation: plugin loading, custom cops, AST traversal, config management, formatter hooks, and extension gem generation.[web:32][web:33][web:26] A separate wrapper command remains useful because some of the Sandi-Metz-inspired rules are cross-file or judgment-heavy, and RuboCop cops work best when a rule can be evaluated from a file and an AST node with a reasonably local autocorrection strategy.[web:7][page:2]

## Topology

```text
Developer / CI / Editor
        |
        v
    metz-scan
        |
        +--> rubocop (with rubocop-metz plugin)
        |       |
        |       +--> file-local cops
        |       +--> safe/unsafe autocorrect
        |       +--> standard or custom formatter output
        |
        +--> project-level analyzers
        |       +--> workflow heuristics
        |       +--> service-soup detection
        |       +--> repeated branching across files
        |
        +--> report merger
                +--> text summary
                +--> json / sarif
                +--> design-pressure explanation layer
```

## Repository layout

A mono-repo is the simplest way to ship both pieces together while keeping the RuboCop plugin independently usable.

```text
metz-scan/
├── gems/
│   └── rubocop-metz/
│       ├── config/
│       │   └── default.yml
│       ├── lib/
│       │   ├── rubocop-metz.rb
│       │   ├── rubocop/
│       │   │   ├── metz.rb
│       │   │   ├── metz/version.rb
│       │   │   ├── metz/plugin.rb
│       │   │   ├── cop/
│       │   │   │   ├── metz_cops.rb
│       │   │   │   └── metz/
│       │   │   │       ├── classes/too_long.rb
│       │   │   │       ├── methods/too_long.rb
│       │   │   │       ├── methods/too_many_parameters.rb
│       │   │   │       ├── demeter/train_wreck.rb
│       │   │   │       ├── controllers/too_many_direct_collaborators.rb
│       │   │   │       └── views/deep_navigation.rb
│       │   │   ├── formatter/
│       │   │   │   └── metz_json_formatter.rb
│       │   │   └── metz/
│       │   │       ├── ast_helpers.rb
│       │   │       ├── rails_file_classifier.rb
│       │   │       └── offense_metadata.rb
│       │   └── metz_scan/
│       │       └── compatibility.rb
│       ├── spec/
│       │   ├── rubocop/
│       │   │   └── cop/
│       │   └── formatter/
│       ├── rubocop-metz.gemspec
│       └── README.md
├── exe/
│   └── metz_scan
├── lib/
│   └── metz_scan/
│       ├── cli.rb
│       ├── runner.rb
│       ├── rubocop_runner.rb
│       ├── report_merger.rb
│       ├── project_index.rb
│       ├── analyzers/
│       │   ├── repeated_branching.rb
│       │   ├── service_soup.rb
│       │   └── unstable_abstractions.rb
│       ├── formatters/
│       │   ├── text.rb
│       │   ├── json.rb
│       │   └── sarif.rb
│       └── version.rb
├── Gemfile
├── metz-scan.gemspec
└── README.md
```

## RuboCop plugin

RuboCop recommends extension gems via the plugin system in modern versions, and the official generator scaffolds the standard files, including `plugin.rb`, `config/default.yml`, and a cops registry file.[web:32][web:33][web:42] That makes `rubocop-metz` the right home for rules that look like conventional cops.

### Plugin load path

Consumer `.rubocop.yml`:

```yaml
plugins:
  - rubocop-metz
```

This follows the current RuboCop plugin loading model rather than the older `require`-only pattern, although `require` remains available for internal files such as custom formatters.[web:32][web:28][web:23]

## Responsibility split

### `rubocop-metz`

Owns rules that are:

- file-local,
- AST-driven,
- reasonably deterministic,
- optionally autocorrectable with local rewrites.

Examples:

- `Metz/ClassesTooLong`
- `Metz/MethodsTooLong`
- `Metz/MethodsTooManyParameters`
- `Metz/DemeterTrainWreck`
- `Metz/ControllersTooManyDirectCollaborators`
- `Metz/ViewsDeepNavigation`

### `metz-scan`

Owns capabilities that RuboCop alone does not model well:

- project-level aggregation,
- cross-file heuristics,
- richer “why it matters” explanations,
- workflow-oriented summaries,
- unified reporting over RuboCop findings plus custom analyzers,
- a more opinionated `--auto-fix` entry point.

Examples:

- repeated branching across files,
- service-object-soup detection,
- unstable concern/base-class heuristics,
- grouped recommendation output by workflow, screen, or layer.[page:2]

## Rule taxonomy

Use RuboCop namespaces that fit the mental model but keep the public docs grouped by design concern.

| Design concern | RuboCop namespace | Example cop |
|---|---|---|
| Structural heuristics | `Metz` | `Metz/MethodsTooLong` |
| Message boundaries | `Metz` | `Metz/DemeterTrainWreck` |
| Rails controllers/views | `Metz` | `Metz/ViewsDeepNavigation` |
| Design pressure summaries | wrapper-only | `service_soup` analyzer |

Using a single namespace keeps installation simpler and avoids over-modeling the rule tree too early.

## Cop design conventions

Each cop should provide:

- a concise offense message,
- structured metadata for `metz-scan`,
- safe versus unsafe correction classification,
- examples in the README and spec fixtures,
- configuration knobs that preserve heuristic flexibility.

### Example cop skeleton

```ruby
module RuboCop
  module Cop
    module Metz
      class DemeterTrainWreck < Base
        extend AutoCorrector

        MSG = 'Call chain is too deep; prefer one message boundary.'

        def on_send(node)
          return unless chain_too_deep?(node)

          add_offense(node.loc.expression)
        end

        private

        def chain_too_deep?(node)
          send_chain_length(node) > max_chain_length
        end
      end
    end
  end
end
```

This follows RuboCop’s custom cop structure and `AutoCorrector` model for rules that can support corrections.[web:21][web:26]

## Offense metadata bridge

RuboCop offenses carry message and location data, but `metz-scan` needs richer explanation fields. The plugin should therefore expose a small metadata registry per cop.

```ruby
module RuboCop
  module Metz
    module OffenseMetadata
      def self.for(cop_name)
        {
          'Metz/DemeterTrainWreck' => {
            why_it_matters: 'Deep collaborator chains increase coupling and leak object graph knowledge.',
            fix_safety: 'unsafe',
            suggested_next_moves: [
              'Add delegation on the owning object',
              'Introduce a view boundary object',
              'Collapse the chain into one domain message'
            ]
          }
        }.fetch(cop_name)
      end
    end
  end
end
```

That lets the wrapper enrich RuboCop output without forking RuboCop’s offense model.[web:26][page:2]

## Formatter strategy

RuboCop already supports built-in and custom formatters, and custom formatters can be loaded with `--format` and `--require` when needed.[web:26][web:37][web:40] The cleanest approach is:

- use RuboCop’s JSON formatter for basic machine-readable output where possible,
- add one custom formatter in `rubocop-metz` only if extra per-offense metadata must be emitted directly,
- keep the higher-level pretty report formatting in `metz-scan`.

### Two viable options

1. **Minimal integration**: call RuboCop with JSON output, then join metadata in the wrapper by cop name.
2. **Rich integration**: ship `RuboCop::Formatter::MetzJsonFormatter` that emits offense metadata inline for the wrapper and editors.[web:26][web:23]

Option 1 is better for v1 because it reduces maintenance and keeps the plugin closer to standard RuboCop behavior.

## `metz-scan` command design

`metz-scan` should feel like the user-facing product, even though RuboCop performs much of the file-local analysis.

### Commands

```bash
metz-scan scan .
metz-scan scan . --auto-fix
metz-scan scan . --auto-fix --unsafe
metz-scan explain Metz/DemeterTrainWreck
metz-scan rules
metz-scan report tmp/rubocop.json
```

### Internal execution flow

1. Build config.
2. Run RuboCop with `rubocop-metz` enabled for file-local cops.[web:32][web:35]
3. Parse RuboCop JSON output.
4. Build a project index for cross-file analyzers.
5. Run wrapper-only analyzers.
6. Merge all findings.
7. Render text, JSON, or SARIF output.
8. If `--auto-fix` is set, delegate file-local corrections to RuboCop and wrapper-safe project fixes to dedicated patchers.

## Auto-fix model

RuboCop already distinguishes safe and unsafe autocorrections, which aligns with the desired philosophy: only mechanical, low-risk rewrites should be applied automatically by default.[web:7][web:10] That means the wrapper should not invent a separate safety system; it should extend RuboCop’s model.

### Proposed semantics

- `metz-scan scan . --auto-fix` → run RuboCop safe corrections only, plus any wrapper-level fixes classified safe.
- `metz-scan scan . --auto-fix --unsafe` → include RuboCop unsafe corrections and wrapper unsafe corrections after explicit confirmation.[web:7]
- `metz-scan scan . --auto-fix --dry-run` → produce diffs without writing.

### Good safe candidates

- local predicate extraction within one class,
- replacing an obviously duplicated condition with a private helper,
- rewriting a view chain to an already-existing delegating method,
- replacing string literals with already-defined constants.

### Good manual-only candidates

- extracting presenters,
- introducing parameter objects,
- collapsing service-object soup into a workflow object,
- replacing callback workflows with command objects.[page:2]

## Cross-file analyzers

These should live in the wrapper, not as ordinary cops.

### `RepeatedBranchingAnalyzer`

Build a simple normalized fingerprint of branch conditions, then find repeated status or role checks across classes and files. This is not a natural RuboCop cop because its value comes from aggregation, not a single offense site.[page:2]

### `ServiceSoupAnalyzer`

Look for sequences like `CreateX.call`, `ValidateX.call`, `PersistX.call`, `NotifyX.call` across a workflow entry point and report them as a single design-pressure finding. That is closer to a report synthesis pass than a cop.

### `UnstableAbstractionsAnalyzer`

Inspect concerns and base classes for indicators such as `case` on class names, feature flags, optional hooks, and subclass-specific branching. This is heuristic-heavy and should remain advisory.

## Recommended implementation order

### Phase 1: pure RuboCop extension

Ship only `rubocop-metz` first.

- scaffold with `rubocop-extension-generator`.[web:33]
- implement 4-6 high-value cops.
- add safe autocorrect only where confidence is high.
- publish the gem.

This gives immediate value and validates the rule set quickly.[web:32][web:33]

### Phase 2: thin wrapper

Add `metz-scan`.

- invoke RuboCop JSON.
- enrich findings with “why it matters” and suggested next moves.
- group by workflow/layer.
- add `explain` and `rules` commands.

### Phase 3: cross-file intelligence

- add project index.
- add service-soup and repeated-branching analyzers.
- add richer CI and editor integration.

## Example `.rubocop.yml`

```yaml
plugins:
  - rubocop-rails
  - rubocop-metz

Metz/MethodsTooLong:
  Enabled: true
  Max: 5

Metz/MethodsTooManyParameters:
  Enabled: true
  Max: 4

Metz/DemeterTrainWreck:
  Enabled: true
  MaxChainLength: 2
  AllowedReceivers:
    - Rails
    - Arel

Metz/ControllersTooManyDirectCollaborators:
  Enabled: true
  MaxCollaborators: 1
```

This keeps threshold tuning in the familiar RuboCop config path rather than inventing a parallel config too early.[web:28][web:38]

## Example user experience

### RuboCop direct

```bash
bundle exec rubocop --plugin rubocop-metz
bundle exec rubocop --plugin rubocop-metz -A
bundle exec rubocop --plugin rubocop-metz --auto-correct-all
```

The exact autocorrect flags should track RuboCop’s supported CLI behavior and safety model.[web:2][web:7]

### Wrapper direct

```bash
bundle exec metz-scan scan .
bundle exec metz-scan scan . --auto-fix
bundle exec metz-scan explain Metz/ViewsDeepNavigation
```

## Recommendation

The best practical path is to treat **RuboCop as the execution engine** and `metz-scan` as the product layer. RuboCop gives mature AST traversal, plugin loading, cops, config, formatters, and autocorrection infrastructure out of the box, while the wrapper gives space for your broader cost-of-change philosophy and the kinds of judgment-heavy summaries that are awkward to express as plain cops.[web:32][web:26][web:7][page:2]

For your workflow, this also minimizes novelty in the core enforcement path and keeps the system easy to adopt in editors, CI, and existing Ruby projects, which is usually the right tradeoff for a developer-facing tool.[cite:18]
