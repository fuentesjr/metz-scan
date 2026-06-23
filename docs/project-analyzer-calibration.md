# Project analyzer calibration

Last updated: 2026-06-23.

This note records a small real-world calibration pass for the opt-in analyzers
behind `metz-scan scan --project-analyzers`. The goal was to decide whether
`MetzProject/ServiceSoup` or `MetzProject/RepeatedBranching` is ready to move
closer to default scan output.

## Method

The analyzers were run directly through the spike scripts so calibration focused
on project-analyzer behavior rather than each target project's RuboCop setup.
Only `app/` and `lib/` were scanned.

```bash
bundle exec ruby script/service_soup_spike.rb /tmp/<repo>/app /tmp/<repo>/lib
bundle exec ruby script/repeated_branching_spike.rb /tmp/<repo>/app /tmp/<repo>/lib
```

Targets:

| Project | Revision | ServiceSoup findings | RepeatedBranching findings |
| --- | --- | ---: | ---: |
| `lobsters/lobsters` | `4b78f3d7fdbd` | 0 | 1 |
| `rubygems/rubygems.org` | `757047af5070` | 0 | 3 |
| `huginn/huginn` | `2607e5894689` | 0 | 2 |
| `maybe-finance/maybe` | `77b546983275` | 0 | 2 |
| `chatwoot/chatwoot` | `e86222034e39` | 0 | 1 |

## `MetzProject/ServiceSoup`

Result: keep as **Candidate**, behind `--project-analyzers`.

The analyzer produced no findings across the five sampled applications. That is
useful evidence that the default threshold of three distinct service constants
is conservative, but it is not evidence that the analyzer is ready for default
scan output. The current detector recognizes method-level workflows made of
`Constant.call(...)`, `Constant.new(...).call`, and their namespaced constant
variants; the sampled applications often used other service styles or had
isolated service calls rather than three in one method.

Decision:

- Keep the threshold at three distinct services for now.
- Keep the analyzer opt-in.
- Do not graduate it until it sees useful true positives in service-heavy Rails
  codebases.
- Before graduation, consider whether additional service invocation shapes are
  worth supporting, such as `perform`, `execute`, `run`, or framework-specific
  command/interactor APIs. Add these only with fixtures from real examples.

Follow-up context pass on 2026-06-23: counts stayed at zero across the same
sample. No new service invocation shapes were added because the calibration did
not produce fixture-backed evidence for `perform`, `execute`, `run`, or a
framework-specific command API.

## `MetzProject/RepeatedBranching`

Result: keep as **Experimental**, behind `--project-analyzers`.

The analyzer produced nine findings across the five sampled applications. The
volume was low enough to review manually, and several findings looked like real
repeated domain decisions:

- `rubygems.org` repeats the same `range` case table in Avo metric cards for
  rubygems and versions.
- `rubygems.org` repeats `normalize_for_json(value)` branching on `Hash` and
  `Array` in two places.
- `huginn` repeats Faraday backend branching in OpenAI and web request concerns.
- `huginn` repeats read/write mode branching in FTP and S3 agents.
- `maybe` repeats safe `per_page` range handling in two API controllers.
- `chatwoot` repeats typing-status branching in a public controller and service.

Follow-up context pass on 2026-06-23: counts were unchanged across the same
sample, and each finding now reports enclosing class/module and method context.
That made generic receiver findings faster to triage, for example:

- `lobsters`: `k` in `Comment#as_json` and `Story#as_json`.
- `rubygems.org`: `range` in `Avo::Cards::RubygemsMetric#query` and
  `Avo::Cards::VersionsMetric#query`.
- `huginn`: `backend = faraday_backend` in
  `OpenaiConcern#build_openai_connection` and `WebRequestConcern#faraday`.
- `maybe`: `per_page` in `Api::V1::AccountsController#safe_per_page_param` and
  `Api::V1::TransactionsController#safe_per_page_param`.
- `chatwoot`: `params[:typing_status]` in
  `Public::Api::V1::Inboxes::ConversationsController#toggle_typing` and
  `Conversations::TypingStatusManager#toggle_typing_status`.

Ambiguities and risk:

- The analyzer groups by lexical decision text and branch values only. Context
  is reported for triage but is intentionally not part of the grouping
  signature, so generic receiver names such as `value` or `k` can still
  over-group unrelated code in larger samples.
- Single explicit `when` branches plus `else` can still reveal duplicated type
  checks, but they are weaker evidence than multi-branch tables.

Decision:

- Keep the minimum occurrence rule at two distinct files for now.
- Do not require more than one explicit branch value yet; doing so would hide
  potentially useful duplicated range/type checks seen in this pass.
- Keep the analyzer experimental until the context-enriched report has been
  sampled on more applications.
- Prefer adding context to findings before adding ignore lists or more knobs.
