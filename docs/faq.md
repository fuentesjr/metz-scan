# FAQ

## Is `metz-scan` a replacement for RuboCop?

No. `metz-scan` uses RuboCop under the hood and adds a small set of design-oriented cops inspired by Sandi Metz's rules. Use normal RuboCop checks for style, correctness, and broad Ruby conventions; use `metz-scan` when you want focused feedback on object boundaries, method shape, and coupling.

## Are Sandi Metz's rules meant to be followed literally?

No. Treat them as pressure gauges, not laws. Short methods, narrow parameter lists, small classes, and limited object-graph traversal are useful signals that code may be hard to change, but there are legitimate exceptions.

The goal is not to make every method five lines forever. The goal is to notice when code is hiding multiple responsibilities or forcing callers to know too much about another object.

## Are the line-count limits arbitrary?

They are intentionally simple defaults. A five-line method or one-hundred-line class is not automatically good, and a six-line method is not automatically bad. The thresholds are useful because they make design pressure visible early.

The default `metz-scan scan` uses stock thresholds on purpose, so a project cannot weaken a cop and get a rosier report. If a cop is too noisy for part of your codebase, take that code out of the cop's scope with a per-cop `Exclude` in `.rubocop.yml`:

```yaml
Metz/MethodsTooLong:
  Exclude:
    - "test/**/*"
```

Custom thresholds such as `Max` apply only under `metz-scan scan --all-cops` or plain `bundle exec rubocop` with the `rubocop-metz` plugin loaded.

## Won't this create too many tiny methods?

It can if the rule is applied mechanically. Extracting every few lines into a private method with a vague name can make code worse.

Good extractions name a real concept, reduce duplication, or move behavior to the object that owns the data. If a method is short but the reader has to jump through five private helpers to understand it, the design has not improved.

## Isn't the Law of Demeter too strict for Ruby and Rails?

It is too strict if treated as "never call more than one dot." That is not how `metz-scan` applies it.

`Metz/DemeterTrainWreck` tries to distinguish object-graph traversal from value-object chaining. For example, string or array transformations are usually fine, while `user.account.subscription.plan.name` often means the caller knows too much about the shape of the domain model.

Rails also has practical escape hatches. The default config excludes specs and migrations, and allows common framework receivers such as `Rails`, `Arel`, `Time`, `Date`, and `DateTime`.

## Does this fight Rails conventions?

It should not. Rails applications still benefit from small actions, clear view boundaries, and models that expose meaningful behavior instead of making controllers and views traverse internals.

Some Rails idioms are intentionally direct. Helpers, presenters, form objects, query objects, and decorators are all reasonable ways to keep templates and controllers from becoming maps of the application's object graph.

## Is this just subjective design taste?

Design feedback always has judgment in it. The value of these cops is that they make a specific kind of judgment repeatable and reviewable.

The cops do not prove that code is bad. They point to places where change may be more expensive than it needs to be. A team can then decide whether the finding is worth fixing, configuring, or ignoring.

## Should these findings fail CI?

Not at first. Start by running `metz-scan` locally or in CI as informational output. Once the team understands the noise level, decide whether to fail CI on new findings only, on a subset of cops, or not at all.

The default severity is `refactor`, which is meant to communicate design pressure rather than correctness failure.

## What should I do when a finding is legitimate?

Prefer small, domain-shaped changes:

- Move behavior to the object that owns the data.
- Introduce a named query, presenter, decorator, or value object.
- Replace a long parameter list with a small object when the parameters travel together.
- Split a long method around named responsibilities, not arbitrary chunks.
- Add delegation when the caller should not know an intermediate association exists.

Avoid refactors that only satisfy the metric while making the code harder to read.

## What should I do when a finding is wrong for my code?

Scope the cop instead of fighting it. The default scan honors two RuboCop mechanisms: a per-cop `Exclude` in `.rubocop.yml`, for example to skip generated files, and a narrow inline disable with a reason. Raising a threshold or setting `Enabled: false`, including in a directory's own `.rubocop.yml`, affects only `--all-cops` and plain `rubocop`.

```ruby
# rubocop:disable Metz/DemeterTrainWreck -- this query object intentionally mirrors the reporting schema
row.account.subscription.plan.name
# rubocop:enable Metz/DemeterTrainWreck
```

Inline disables should be rare and specific. If the same exception appears repeatedly, prefer a per-cop `Exclude` in `.rubocop.yml`, with the reason as a comment on or above the entry.

Suppressions stay visible. The default scan lists every finding an inline disable or a per-cop `Exclude` hid in a suppression ledger (the JSON `suppressions` array and the text `Suppressed findings` section), with the reason it found or a note that none was given. Suppressed findings do not count as offenses or affect the exit status.

## Can static analysis really understand object-oriented design?

Only partially. `metz-scan` cannot know every runtime type, every domain intention, or every tradeoff behind the code. It uses static signals that are cheap to run and easy to discuss.

That limitation is why findings should be reviewed as prompts. A warning means "look here," not "rewrite this blindly."

## Does auto-fix redesign my code?

No. Auto-correction is limited to fixes that RuboCop can apply mechanically. Design changes usually require human judgment, naming, and tests, so most Metz findings explain the issue and suggest next moves rather than rewriting the code.

Use `--dry-run` before auto-fix when you want to inspect what would change.

```bash
bundle exec metz-scan scan . --auto-fix --dry-run
```

## Where should I start on an existing codebase?

Start with a narrow path and read the report before changing anything.

```bash
bundle exec metz-scan scan app/models app/controllers --format text
```

Look for repeated patterns rather than isolated violations. The highest-value fixes are usually places where controllers, views, or service objects repeatedly reach through the same collaborators.

## How should a team adopt these rules?

Adopt them as shared language first. Discuss a few findings in code review, agree on which ones reflect real pain, and settle exclusions before enforcing anything.

A practical rollout is:

1. Run `metz-scan` locally on changed files.
2. Add CI reporting without failing the build, such as this GitHub Actions step:

   ```yaml
   - name: Run metz-scan annotations
     run: bundle exec metz-scan scan . --format gh-annotations
   ```

3. Add per-cop `Exclude` entries for code the team agrees a cop should not cover.
4. Fail CI only on findings your team agrees matter, for example by filtering the JSON report on `cop_name`.

## Where can I learn more about the Demeter implementation?

See [`rubocop-metz/docs/demeter-design.md`](../rubocop-metz/docs/demeter-design.md) for the detailed design notes behind `Metz/DemeterTrainWreck`.
