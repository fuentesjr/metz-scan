# Project analyzer calibration

Last updated: 2026-06-23.

This note records real-world calibration passes for the opt-in analyzers behind
`metz-scan scan --project-analyzers`. The goal was to decide whether
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

Initial targets:

| Project | Revision | ServiceSoup findings | RepeatedBranching findings |
| --- | --- | ---: | ---: |
| `lobsters/lobsters` | `4b78f3d7fdbd` | 0 | 1 |
| `rubygems/rubygems.org` | `757047af5070` | 0 | 3 |
| `huginn/huginn` | `2607e5894689` | 0 | 2 |
| `maybe-finance/maybe` | `77b546983275` | 0 | 2 |
| `chatwoot/chatwoot` | `e86222034e39` | 0 | 1 |

Expanded targets, checked out sparsely under ignored local scratch space and
scanned with the same commands:

| Project | Revision | ServiceSoup findings | RepeatedBranching findings |
| --- | --- | ---: | ---: |
| `discourse/discourse` | `2115f1cac5f9` | 1 | 5 |
| `mastodon/mastodon` | `34bbb4748223` | 3 | 14 |
| `forem/forem` | `d9a393f1d502` | 2 | 4 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 0 | 1 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 |

## `MetzProject/ServiceSoup`

Result: keep as **Candidate**, behind `--project-analyzers`.

The analyzer produced no findings across the five sampled applications. That is
useful evidence that the default threshold of three distinct service constants
is conservative, but it is not evidence that the analyzer is ready for default
scan output. The current detector recognizes method-level workflows made of
`Constant.call(...)`, `Constant.new(...).call`, and their namespaced constant
variants, plus `Constant.new(...).perform` and its namespaced variants; the
sampled applications often used other service styles or had isolated service
calls rather than three in one method.

Decision:

- Keep the threshold at three distinct services for now.
- Keep the analyzer opt-in.
- Do not graduate it until it sees useful true positives in more service-heavy
  Rails codebases.
- Before graduation, consider whether additional service invocation shapes are
  worth supporting, such as `perform`, `execute`, `run`, or framework-specific
  command/interactor APIs. Add these only with fixtures from real examples.

Follow-up context pass on 2026-06-23: counts stayed at zero across the same
sample. No new service invocation shapes were added because the calibration did
not produce fixture-backed evidence for `perform`, `execute`, `run`, or a
framework-specific command API.

Follow-up ServiceSoup pass on 2026-06-23: adding support for
`Constant.new(...).perform` and namespaced variants changed only Chatwoot, from
0 to 3 findings. The other four sampled applications remained at 0.

| Project | ServiceSoup findings after `perform` support |
| --- | ---: |
| `lobsters/lobsters` | 0 |
| `rubygems/rubygems.org` | 0 |
| `huginn/huginn` | 0 |
| `maybe-finance/maybe` | 0 |
| `chatwoot/chatwoot` | 3 |

The three Chatwoot findings look like plausible true positives:

- `Inboxes::FetchImapEmailsJob#process_email_for_channel` coordinates three
  IMAP fetch services.
- `Campaign#execute_campaign` coordinates three campaign delivery services.
- `MessageTemplates::HookExecutionService#trigger_templates` coordinates three
  message-template services.

Expanded calibration on 2026-06-23 found six more plausible true positives with
the existing supported invocation styles:

- `discourse`: `CategoriesController#manage_category_types` coordinates site
  setting updates plus category type configure/unconfigure services.
- `forem`: `Feeds::Import#create_articles_from_feed_source` coordinates feed
  import checks, author resolution, and article markdown assembly.
- `forem`: `Users::DeleteArticles#call` coordinates multiple edge-cache busting
  services while deleting article and comment state.
- `mastodon`: `BulkImportRowService#call` coordinates account/status lookup plus
  follow, block, mute, and related import actions.
- `mastodon`: `ResolveURLService#process_url` coordinates remote actor, status,
  and featured collection lookup services.
- `mastodon`: `UpdateStatusService#update_metadata!` coordinates hashtag,
  mention, and link processing services.

Static `Constant.perform`, `execute`, and `run` were not added because this pass
did not show three-service workflows using those shapes.

Expanded decision:

- Keep ServiceSoup as **Candidate** and still opt-in. The expanded sample shows
  useful true positives in service-heavy applications, but the evidence is not
  broad enough for default scan output.
- Do not add more invocation styles until calibration finds repeated,
  fixture-backed examples. The current expanded findings all came from
  `Constant.call(...)` or `Constant.new(...).call`.

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

Expanded calibration on 2026-06-23 found twenty-four findings across four of six
additional applications. The stronger examples still look like repeated domain
decisions:

- `discourse` repeats `action`, `exception.wrapped`, `period`,
  `File.extname(URI(url).path || "")`, and `status` decisions across
  controllers, jobs, models, services, and filters.
- `forem` repeats page template fallback, Liquid tag date parsing and sorting,
  and AI locale instruction decisions across parallel components.
- `mastodon` repeats ActivityPub add/remove and accept/reject decisions, trend
  filter scope tables, batch action dispatch, storage backend handling, follow
  request handling, and merge/unmerge worker dispatch.
- `openfoodnetwork` repeats the same enterprise authorization action table
  across three API controllers.

The expanded sample also confirms the main remaining risk: generic decision
subjects such as `value`, `type`, `action`, and `key.to_s` need context before
triage. In this pass, context made most of those examples understandable rather
than noisy, but Mastodon's fourteen findings show that volume can become high in
projects with many parallel domain objects.

Expanded decision:

- Keep RepeatedBranching as **Experimental** and still opt-in.
- Keep the current grouping rules for now. The expanded sample did not justify
  ignore lists or stricter branch-value requirements.
- Before moving closer to default output, add either clearer severity/confidence
  language or a project-analyzer report summary that helps users triage high
  volumes by context.
