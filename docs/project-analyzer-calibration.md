# Project analyzer calibration

Last updated: 2026-06-24.

This note records real-world calibration passes for the opt-in analyzers behind
`metz-scan scan --project-analyzers`. The goal was to decide whether
`MetzProject/ServiceSoup`, `MetzProject/RepeatedBranching`, or
`MetzProject/DeepInheritanceTree` is ready to move closer to default scan
output.

## Method

The analyzers were run directly through the spike scripts so calibration focused
on project-analyzer behavior rather than each target project's RuboCop setup.
Only `app/` and `lib/` were scanned.

```bash
bundle exec ruby script/service_soup_spike.rb /tmp/<repo>/app /tmp/<repo>/lib
bundle exec ruby script/repeated_branching_spike.rb /tmp/<repo>/app /tmp/<repo>/lib
```

The DeepInheritanceTree pass used a one-off Rubydex-backed harness that built a
`ProjectIndex` for each target's `app/` and `lib/` paths, ran
`MetzScan::Analyzers::InheritanceDescendants` with its default threshold, and
recorded both raw findings and a manually triaged count excluding Ruby core and
Rubydex synthetic declarations.

Historical target-location note: early calibration runs used scratch checkouts
under `/private/tmp/metz-calibration`. Those paths are historical context only.
Current and future calibration runs should use repo-local ignored scratch space
under `tmp/project-analyzer-calibration/`, including
`tmp/project-analyzer-calibration/apps/` for approved sparse target checkouts.

Initial targets:

| Project | Revision | ServiceSoup findings | RepeatedBranching findings |
| --- | --- | ---: | ---: |
| `lobsters/lobsters` | `4b78f3d7fdbd` | 0 | 1 |
| `rubygems/rubygems.org` | `757047af5070` | 0 | 3 |
| `huginn/huginn` | `2607e5894689` | 0 | 2 |
| `maybe-finance/maybe` | `77b546983275` | 0 | 2 |
| `chatwoot/chatwoot` | `e86222034e39` | 0 | 1 |

Expanded targets, checked out sparsely under ignored repo-local scratch space
and scanned with the same commands:

| Project | Revision | ServiceSoup findings | RepeatedBranching findings |
| --- | --- | ---: | ---: |
| `discourse/discourse` | `2115f1cac5f9` | 1 | 5 |
| `mastodon/mastodon` | `34bbb4748223` | 3 | 14 |
| `forem/forem` | `d9a393f1d502` | 2 | 4 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 0 | 1 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 |

Triage-output follow-up on 2026-06-23: adding project-analyzer status,
confidence, triage severity, triage summary, and `summary.project_analyzers`
output metadata did not change the expanded calibration counts above.

Output-format follow-up on 2026-06-23: JSON, SARIF, text, and GitHub annotation
output now preserve project-analyzer triage context. `MetzProject/DeepInheritanceTree`
has been revived behind `--project-analyzers` as an experimental,
Rubydex-backed analyzer.

DeepInheritanceTree calibration follow-up on 2026-06-24: Rubydex-backed runs on
the five initial targets show useful inheritance signals, but raw output is too
noisy for default output. Ruby core declarations such as `BasicObject`,
`Object`, `Kernel`, `Module`, and `Class`, plus Rubydex synthetic declaration
names like `ApplicationRecord::<ApplicationRecord>`, dominate raw counts unless
filtered during triage.

Post-filter DeepInheritanceTree follow-up on 2026-06-24: current runs use
repo-local scratch checkouts under `tmp/project-analyzer-calibration/`. The
built-in filter removes Ruby core roots and Rubydex synthetic declaration names
from both base candidates and descendant counts. On the expanded local target
set, no filtered core or synthetic names remained in the captured findings.

## Default output readiness

Current decision: do not graduate any project analyzer into default
`metz-scan scan` output yet. `metz-scan scan --project-analyzers` remains the
right boundary for these findings because they change scan scope, runtime, and
triage semantics beyond the default RuboCop-backed cops.

Readiness by analyzer:

- `MetzProject/ServiceSoup` is the strongest graduation candidate. The latest
  repo-local rerun confirmed sparse, reviewable findings that still look like
  plausible true positives in service-heavy Rails applications. It should stay
  opt-in until calibration shows broader evidence across more service,
  interactor, job, mailer, and command-object styles.
- `MetzProject/RepeatedBranching` remains experimental. The counts are stable
  and context-enriched findings are readable, but generic decision subjects
  still need clearer user-facing confidence and severity language before this
  belongs in default output.
- `MetzProject/DeepInheritanceTree` remains experimental. Grouped output,
  class-only auto-discovery, and located-root filtering fixed the largest
  mechanical output problems, but broad framework-style roots still need better
  semantic labeling or filtering before this analyzer should appear by default.

Reporting-language follow-up on 2026-06-24: text output now labels each
project-analyzer summary with status, confidence, and severity, and the summary
heading explicitly calls these findings opt-in advisory signals. Text and
GitHub annotation triage lines now label the same status, confidence, and
severity fields before the analyzer-specific triage summary.

Real-output sampling follow-up on 2026-06-24: direct `ProjectAnalyzerRunner`
text rendering against the repo-local Discourse checkout produced 53 findings
and 60 offenses, split clearly across DeepInheritanceTree, RepeatedBranching,
and ServiceSoup. The summary wording was readable at this volume. A full
`metz-scan scan` sample against the same paths was blocked by Discourse's
RuboCop plugin dependency (`rubocop-discourse`), so external-target
report-language calibration should use the direct project-analyzer runner when
the target repo's RuboCop config is not installed locally.

Next non-release action: compare the updated report language against one
higher-volume target, such as Mastodon, before changing detector mechanics
again. The calibration evidence now points more to confidence, severity, and
summary interpretation than to another immediate analyzer rule change.

High-volume sampling follow-up on 2026-06-24: direct `ProjectAnalyzerRunner`
text rendering against the repo-local Mastodon checkout produced 57 findings
and 83 offenses. The summary remained readable, but the first pass exposed
overly long absolute paths for project-analyzer-only file entries. The runner
now displays appended project-local files relative to the current working
directory while preserving absolute paths outside the project. After that
normalization, the Mastodon sample used readable `tmp/...` paths without
changing finding counts.

Dogfood follow-up on 2026-06-24: project analyzers now use RuboCop target-file
selection for normal scans, so `AllCops: Exclude` applies to project-analyzer
input as well as RuboCop-backed cops. `bin/check_dogfood` runs
`metz-scan scan . --project-analyzers --format json`, requires the optional
Rubydex bundle group, and accepts only the current exact
`MetzProject/DeepInheritanceTree` offense on
`rubocop-metz/lib/rubocop/cop/metz/base.rb` where `RuboCop::Cop::Metz::Base`
has nine descendants. That makes the dogfood gate fail when any
non-project-analyzer offense appears or when the accepted project-analyzer
signature changes.

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

Repo-local rerun on 2026-06-24 used the local service-soup fixture and sparse
target checkouts under `tmp/project-analyzer-calibration/apps/`. Counts matched
the expanded calibration and continued to look like plausible true positives.

| Project | Revision | ServiceSoup findings | Distinct services |
| --- | --- | ---: | ---: |
| `test/fixtures/service_soup_app` | local fixture | 1 | 4 |
| `discourse/discourse` | `2115f1cac5f9` | 1 | 3 |
| `mastodon/mastodon` | `34bbb4748223` | 3 | 11 |
| `forem/forem` | `d9a393f1d502` | 2 | 7 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 0 | 0 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 |

Rerun decision:

- No implementation change is warranted from this pass. The findings remain
  sparse and reviewable, and the current supported call shapes are sufficient
  for the observed examples.
- Keep ServiceSoup **Candidate** and opt-in. It has the strongest true-positive
  evidence of the three project analyzers, but not enough breadth yet for
  default output.

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

Repo-local rerun on 2026-06-24 used the same local fixture and sparse target
checkouts under `tmp/project-analyzer-calibration/apps/`. Counts matched the
expanded calibration, and the context-enriched findings remained low volume
enough for manual review.

| Project | Revision | RepeatedBranching findings | Occurrences |
| --- | --- | ---: | ---: |
| `test/fixtures/sample_app` | local fixture | 0 | 0 |
| `discourse/discourse` | `2115f1cac5f9` | 5 | 10 |
| `mastodon/mastodon` | `34bbb4748223` | 14 | 31 |
| `forem/forem` | `d9a393f1d502` | 4 | 9 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 1 | 3 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 |

Rerun decision:

- No implementation change is warranted from this pass. The generic-looking
  decisions such as `value`, `action`, and `key.to_s` are understandable because
  each finding reports enclosing class/module and method context.
- Keep RepeatedBranching **Experimental** until users have more explicit
  confidence/severity language for interpreting repeated branch tables.

## `MetzProject/DeepInheritanceTree`

Result: keep as **Experimental**, behind `--project-analyzers`.

The analyzer depends on the optional Rubydex-backed project index. Without the
optional bundle group enabled, it contributes no findings. With Rubydex enabled,
the focused spike on this repository still reports `RuboCop::Cop::Metz::Base`
with nine descendants, which is a plausible true positive for an intentionally
shared cop base class.

Initial Rubydex-backed calibration used the same five real applications as the
first project-analyzer pass, scanning only `app/` and `lib/`. The raw count is
what the analyzer currently emits. The triaged count removes Ruby core roots and
Rubydex synthetic declaration names by hand, to show the size of the useful
candidate set.

| Project | Revision | Raw findings | Triaged findings |
| --- | --- | ---: | ---: |
| `test/fixtures/sample_app` | local fixture | 9 | 1 |
| `lobsters/lobsters` | `4b78f3d7fdbd` | 24 | 12 |
| `rubygems/rubygems.org` | `757047af5070` | 62 | 41 |
| `huginn/huginn` | `2607e5894689` | 38 | 24 |
| `maybe-finance/maybe` | `77b546983275` | 54 | 35 |
| `chatwoot/chatwoot` | `e86222034e39` | 111 | 76 |

The strongest useful examples were broad application bases and widely included
concerns:

- `sample_app`: `ApplicationRecord` has six model descendants.
- `lobsters`: `ApplicationController`, `ApplicationRecord`,
  `Mod::ModController`, `ApplicationJob`, and `ApplicationMailer` identify
  broad Rails inheritance or shared module surfaces.
- `rubygems.org`: `ApplicationController`, `ApplicationRecord`,
  `Admin::ApplicationPolicy`, `Admin::ApplicationPolicy::Scope`,
  `Api::BaseController`, `ApplicationJob`, and `ApplicationComponent` identify
  meaningful large family roots.
- `huginn`: `Agent` has 75 descendants, and shared modules such as
  `DryRunnable`, `LiquidInterpolatable`, and `WorkingHelpers` span most agent
  subclasses.
- `maybe`: controller concerns such as `Authentication`, `AutoSync`,
  `FeatureGuardable`, and `StoreLocation` each reach 73 descendants.
- `chatwoot`: `ApplicationController`, `Api::BaseController`,
  `Api::V1::Accounts::BaseController`, `ApplicationJob`,
  `ApplicationRecord`, and concerns like `RequestExceptionHandler` and
  `SwitchLocale` show very broad descendant spread.

Risks:

- The current auto-discovery path reports Ruby core declarations and Rubydex
  synthetic declarations, which creates obvious false positives in user-facing
  `scan --project-analyzers` output.
- Before grouped output, findings expanded to one offense per descendant
  location, so noisy roots could create high offense counts even when the
  underlying finding count was smaller.
- Location fidelity remains file-level; Rubydex exposes declaration paths here,
  but the adapter does not provide precise class-definition line/column data.

Decision:

- Keep DeepInheritanceTree **Experimental** and opt-in.
- Keep filtering Ruby core roots and synthetic declaration names from
  auto-discovered candidates.
- Group output by base declaration, or otherwise reduce per-descendant offense
  expansion, before calibrating high-volume applications again.

Post-filter expanded calibration on 2026-06-24 used only the local fixture and
repo-local sparse checkouts under `tmp/project-analyzer-calibration/apps/`. The
filter removed the obvious Ruby core and Rubydex synthetic false-positive bucket,
but high-volume applications still produce too many user-facing offenses because
each base finding expands to one offense per descendant location.

| Project | Revision | Base findings | Descendant-location offenses | Largest descendant count |
| --- | --- | ---: | ---: | ---: |
| `test/fixtures/sample_app` | local fixture | 1 | 6 | 6 |
| `discourse/discourse` | `2115f1cac5f9` | 98 | 2837 | 230 |
| `mastodon/mastodon` | `34bbb4748223` | 95 | 6157 | 337 |
| `forem/forem` | `d9a393f1d502` | 41 | 1556 | 155 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 62 | 2036 | 119 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 | 0 |

Useful examples remain local and meaningful:

- `discourse`: `Jobs::Base`, `ApplicationSerializer`, and
  `ActiveModel::Serializer` each identify large job or serializer families.
- `mastodon`: broad helpers and controller concerns such as
  `AuthorizedFetchHelper`, `DomainControlHelper`, `Localized`, and
  `CacheConcern` span hundreds of indexed declarations.
- `forem`: controller concerns such as `ValidRequest`, `SessionCurrentUser`,
  `ImageUploads`, and `CachingHeaders` span most controllers.
- `openfoodnetwork`: `ApplicationRecord`, `Spree::Preferences::Preferable`,
  `Spree::Core::ControllerHelpers::Auth`, and `RequestTimeouts` identify broad
  model, controller, and framework-extension surfaces.

Post-filter decision:

- The core/synthetic filter is worth keeping; the corrected run found zero
  remaining `BasicObject`, `Object`, `Kernel`, `Module`, `Class`, or `::<`
  synthetic declaration names in findings.
- Grouping DeepInheritanceTree output by base declaration is the next
  implementation target. It should emit one primary finding per broad root with
  descendant examples in metadata. Per-descendant offense expansion is the main
  blocker now.
- Do not narrow auto-discovered roots yet. The largest remaining roots are local
  application declarations rather than obvious external noise, and they contain
  useful signal once grouped.
- Location fidelity remains secondary. File-level descendant paths are enough to
  identify the output-volume problem and the broad roots causing it.

Grouped-output follow-up on 2026-06-24: `MetzProject/DeepInheritanceTree` now
emits one primary offense at the base declaration for each finding. Descendant
declaration paths remain available in `project_analyzer.descendant_locations`,
and findings without a base declaration path fall back to the first descendant
path so the finding stays visible. The grouped run reused only the local fixture
and repo-local sparse checkouts under `tmp/project-analyzer-calibration/apps/`.

| Project | Revision | Base findings | Grouped offenses | Descendant locations | Largest descendant count |
| --- | --- | ---: | ---: | ---: | ---: |
| `test/fixtures/sample_app` | local fixture | 1 | 1 | 6 | 6 |
| `discourse/discourse` | `2115f1cac5f9` | 98 | 98 | 2837 | 230 |
| `mastodon/mastodon` | `34bbb4748223` | 95 | 95 | 6157 | 337 |
| `forem/forem` | `d9a393f1d502` | 41 | 41 | 1556 | 155 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 62 | 62 | 2036 | 119 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 | 0 | 0 |

Grouped-output decision:

- Keep DeepInheritanceTree **Experimental** and opt-in. The output volume is now
  reviewable by finding count, but Discourse, Mastodon, and Open Food Network
  still produce enough broad-root findings that default output would be too
  assertive.
- Keep descendant-location metadata. It preserves review context without
  multiplying RuboCop/SARIF/GitHub annotation volume.
- Investigate root-selection quality before graduation. The remaining signal is
  local, but many high-count roots are broad concerns and helpers rather than
  conventional inheritance bases.

Class-root follow-up on 2026-06-24: auto-discovered
`MetzProject/DeepInheritanceTree` roots now use Rubydex declaration kind when
available and skip known non-class declarations. Explicit `base_names:` still
allow focused module or concern inspection. The rerun used the same local
fixture and repo-local sparse checkouts under
`tmp/project-analyzer-calibration/apps/`.

| Project | Revision | Grouped findings before class filter | Grouped findings after class filter | Descendant locations after class filter | Largest descendant count after class filter |
| --- | --- | ---: | ---: | ---: | ---: |
| `test/fixtures/sample_app` | local fixture | 1 | 1 | 6 | 6 |
| `discourse/discourse` | `2115f1cac5f9` | 98 | 47 | 1288 | 230 |
| `mastodon/mastodon` | `34bbb4748223` | 95 | 41 | 1248 | 293 |
| `forem/forem` | `d9a393f1d502` | 41 | 26 | 608 | 150 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 62 | 29 | 500 | 100 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 | 0 | 0 |

Class-root decision:

- Keep the class-only auto-discovery filter. It removes the largest helper,
  concern, mixin, and controller-helper buckets while preserving conventional
  Rails bases such as `ApplicationController`, `ApplicationRecord`, jobs,
  serializers, policies, and service bases.
- Do not graduate DeepInheritanceTree yet. Some framework or module-like roots
  still remain, for example `ActiveModel::Serializer`,
  `ViteRails::TagHelpers`, and `ActivityPub::Serializer`; the next calibration
  question is whether to label or filter framework-style roots separately.
- Keep explicit configured roots unrestricted so spike scripts and focused
  investigations can still inspect module spread when that is the user’s goal.

Located-root follow-up on 2026-06-24: auto-discovered
`MetzProject/DeepInheritanceTree` roots now also require a declaration path.
Explicit configured roots still fall back to the first descendant path when the
base declaration is unavailable. This removes roots like `ViteRails::TagHelpers`
where Rubydex can see descendant spread but cannot point to a local root
declaration.

| Project | Revision | Grouped findings after class filter | Grouped findings after located-root filter | Descendant locations after located-root filter |
| --- | --- | ---: | ---: | ---: |
| `test/fixtures/sample_app` | local fixture | 1 | 1 | 6 |
| `discourse/discourse` | `2115f1cac5f9` | 47 | 47 | 1288 |
| `mastodon/mastodon` | `34bbb4748223` | 41 | 40 | 1089 |
| `forem/forem` | `d9a393f1d502` | 26 | 26 | 608 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 | 0 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 29 | 29 | 500 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 | 0 |

Located-root decision:

- Keep the located-root auto-discovery filter. A finding without a base
  declaration path cannot anchor a useful primary offense automatically.
- Treat this as a small quality cleanup, not a major calibration shift. The
  remaining large roots are mostly located local classes and should be assessed
  by semantic category rather than by location availability.
