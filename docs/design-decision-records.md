# Design Decision Records

A Design Decision Record (DDR) is a lightweight ADR for code-level design
exceptions. It records a specific decision where the project intentionally
does not follow a design rule, metric, or guiding principle because the local
context makes another choice better.

DDRs are especially important for Metz-style design rules. These rules are
pressure gauges, not laws. When the pressure is real but the best design still
chooses the exception, the exception needs to be explicit, reviewable, and
easy to revisit later.

## When to Write a DDR

Write a DDR when a change intentionally keeps or introduces code that violates
a project design principle or analyzer recommendation, such as:

- using inheritance instead of composition;
- accepting a broad base class or shared superclass;
- keeping a long method, large class, long parameter list, or deep object graph
  because the local design trade-off is better than the mechanical fix;
- choosing framework convention over a stricter object-design rule;
- accepting a persistent project-analyzer finding instead of fixing it.

Do not write a DDR for every implementation detail. A DDR is for a durable
decision that a future maintainer could reasonably challenge or accidentally
"fix" by applying a design rule mechanically.

## Required Code Reference

Every accepted DDR must be referenced from the relevant code with a short
comment. The comment should explain why the reader is being sent to the DDR,
not restate the entire decision.

Use this shape:

```ruby
# DDR: docs/ddrs/YYYY-MM-DD-short-title.md explains why this exception is intentional.
```

Keep the comment near the design exception: the class declaration, the method,
the dependency boundary, or the configuration entry that embodies the decision.

## Location and Naming

Store DDRs under `docs/ddrs/` with this filename shape:

```text
YYYY-MM-DD-short-title.md
```

Use lowercase words separated by hyphens. The date is the date the decision was
accepted or last substantially revised.

## Statuses

Use one of these statuses:

- `Accepted`: the decision is active and code may reference it.
- `Superseded`: the decision has been replaced. Link to the newer DDR.

Committed DDRs should be decisions, not proposals. Draft decision text can live
in an unmerged branch or pull request discussion, but a DDR merged into the
repository should be `Accepted` or `Superseded`.

Only `Accepted` DDRs should be referenced from production code.

## Process

1. Identify the design rule or principle under pressure.
2. Compare the main alternatives, including the mechanical rule-following
   option.
3. If the rule will not be followed, write or update the DDR before finalizing
   the code.
4. Add the short code comment that references the accepted DDR.
5. Revisit the DDR when the surrounding design, framework constraints, or
   failure modes change.

## Template

```markdown
# Decision: [Short title]

**Date:** YYYY-MM-DD
**Author:** [Name or agent]
**Status:** Accepted / Superseded

## Context / The Issue

Describe the specific situation in the codebase.

- What code, module, class, or boundary is involved?
- What problem or requirement are we solving?
- Which design rule or principle is under pressure?
- Why does a design choice need to be made here?

## Decision

We will [clearly state the decision].

## Rationale & Justification

Explain why this choice is best in this specific case.

- Key benefits that matter here.
- Trade-offs we accept.
- Why the main alternatives were rejected.
- Constraints or context that influenced the choice.

## Consequences / Impact

- Short-term effects on the code.
- Long-term implications for maintenance, extensibility, and testing.
- What would trigger us to revisit this decision later?
```
