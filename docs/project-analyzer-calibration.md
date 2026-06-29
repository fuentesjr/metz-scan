# Project analyzer calibration

Last updated: 2026-06-26.

This note records real-world calibration passes for the opt-in analyzers behind
`metz-scan scan --project-analyzers`. The goal was to decide whether
`MetzProject/ServiceSoup`, `MetzProject/RepeatedBranching`, or
`MetzProject/DeepInheritanceTree` is ready to move closer to default scan
output. `MetzProject/PackageDependencyPressure` was added later and now has a
candidate opt-in calibration pass after shared-dependency downranking.
`MetzProject/NamespaceLeakPressure` was added later as an uncalibrated
candidate and should remain opt-in until real-project samples confirm sparse,
useful namespace-boundary findings.

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

Current decision: default `metz-scan scan` output uses a separate
analyzer-level eligibility gate and finding-level triage gate. A
project-analyzer finding qualifies for default output only when its analyzer is
explicitly default-output eligible, its analyzer status is `validated`, and the
individual finding is `confidence: medium` with `severity: design pressure`.
`metz-scan scan --project-analyzers` remains the boundary for the full
project-analyzer set, including candidate analyzers, validated opt-in-only
analyzers, and lower-confidence findings.

Readiness by analyzer:

- `MetzProject/ServiceSoup` is validated for opt-in project-analyzer output.
  The latest repo-local rerun confirmed sparse, reviewable findings that still
  look like plausible true positives in service-heavy Rails applications. A
  follow-up promotion review added one more strong service-workflow target and
  one setup-orchestration example that is now downranked with low confidence
  and setup-specific triage language. Its medium-confidence design-pressure
  findings are explicitly default-output eligible; setup-orchestration findings
  remain available only with `--project-analyzers`.
- `MetzProject/RepeatedBranching` is validated for opt-in project-analyzer
  output. The counts are stable, context-enriched findings are readable, and a
  Spree follow-up produced only three findings with concrete domain context. Its
  medium-confidence design-pressure findings are explicitly default-output
  eligible.
- `MetzProject/DeepInheritanceTree` is validated for opt-in project-analyzer
  output, but is not default-output eligible. Grouped output, class-only
  auto-discovery, located-root filtering, expanded root-kind labels, and
  broad-root downranking fixed the largest mechanical and triage-language
  problems. It should not move toward default output until broad root kinds are
  calibrated across more projects.
- `MetzProject/PackageDependencyPressure` is candidate for opt-in
  project-analyzer output. Threshold tuning and shared-dependency downranking
  reduced broad public APIs, shared configuration, framework extension points,
  and exception/utility hubs to lower-confidence triage, while leaving a
  smaller set of concrete package-boundary pressure prompts. It should not move
  toward default output or validated status until broader samples confirm those
  manual-review findings are consistently useful.
- `MetzProject/NamespaceLeakPressure` is candidate for opt-in project-analyzer
  output. The first implementation reports deeply nested declarations whose
  references spread outside the home namespace into at least three files across
  three packages. Calibration showed the original two-file/two-package threshold
  was too noisy, so public constants, nested exception families, and framework
  or extension namespaces are now downranked with shared-namespace triage. It
  should not move toward default output or validated status until follow-up
  calibration confirms those lower-confidence findings are sparse and useful.
  A tuned 2026-06-27 calibration pass at the three-file/three-package threshold
  produced 29 findings across Chatwoot, Discourse, Mastodon, Forem, and
  OpenFoodNetwork. Only five remained medium-confidence namespace-boundary
  findings (Chatwoot 1, Discourse 3, OpenFoodNetwork 1); the other 24 were
  low-confidence shared-namespace findings.

Reporting-language follow-up on 2026-06-24: text output now labels each
project-analyzer summary with status, confidence, and severity, and the summary
heading explicitly calls these findings advisory signals. Text and GitHub
annotation triage lines now label the same status, confidence, and severity
fields before the analyzer-specific triage summary.

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
Rubydex bundle group, and accepts zero project-analyzer findings. That makes
the dogfood gate fail when any non-project-analyzer offense or project-analyzer
finding appears.

Report-priority follow-up on 2026-06-25: direct `ProjectAnalyzerRunner`
sampling against the repo-local Mastodon checkout at `34bbb4748223` captured
JSON, SARIF, text, and GitHub annotation output for `app/` and `lib/`. The
sample used an ignored temporary harness:

```bash
bundle exec ruby tmp/project-analyzer-calibration/runs/20260625-140109/render_project_analyzer_sample.rb \
  tmp/project-analyzer-calibration/runs/20260625-140109/mastodon \
  mastodon \
  tmp/project-analyzer-calibration/apps/mastodon/app \
  tmp/project-analyzer-calibration/apps/mastodon/lib
```

It still produced 57 findings and 83 offenses: `ServiceSoup` had 3 findings
and 12 offenses, `DeepInheritanceTree` had 40 findings and 40 offenses, and
`RepeatedBranching` had 14 findings and 31 offenses. JSON, SARIF, and GitHub
annotations preserved the triage metadata needed by downstream tools. Text
output was readable but sorted project-analyzer blocks alphabetically, which
buried the higher-confidence `ServiceSoup` candidate after the high-volume
experimental inheritance and repeated-branching sections. Text output now
keeps normal RuboCop cops first, then orders project-analyzer summary rows and
blocks by triage priority so higher-confidence design-pressure signals surface
before experimental/manual-review signals.

Second-target validation on 2026-06-25: direct `ProjectAnalyzerRunner`
sampling against the repo-local Discourse checkout at `2115f1cac5f9` captured
JSON, SARIF, text, and GitHub annotation output for `app/` and `lib/` using:

```bash
bundle exec ruby tmp/project-analyzer-calibration/runs/20260625-140109/render_project_analyzer_sample.rb \
  tmp/project-analyzer-calibration/runs/20260625-143504/discourse \
  discourse \
  tmp/project-analyzer-calibration/apps/discourse/app \
  tmp/project-analyzer-calibration/apps/discourse/lib
```

The sample produced 53 findings and 60 offenses: `ServiceSoup` had 1 finding
and 3 offenses, `DeepInheritanceTree` had 47 findings and 47 offenses, and
`RepeatedBranching` had 5 findings and 10 offenses. The text report now lists
the `ServiceSoup` design-pressure summary and block first, ahead of
the larger experimental inheritance and repeated-branching sections. This
confirms the Mastodon-driven priority change helps on a second high-volume
target rather than only on the original sample.

Readiness decision after second-target validation: keep all project analyzers
behind `--project-analyzers`. The priority-ordered text report now makes the
sparse `ServiceSoup` signal visible even when `DeepInheritanceTree` dominates
finding volume, but this improves triage rather than default-output readiness.
At that checkpoint, `ServiceSoup` remained the strongest candidate but still
needed broader service-style coverage before graduation. `RepeatedBranching`
remained experimental until its
generic branch-subject findings have clearer confidence/severity interpretation.
`DeepInheritanceTree` remained the main blocker for default project-analyzer
output at this checkpoint because large Rails and framework roots needed more
calibration after semantic labeling before they were safe to show by default.
Follow-up tracking:
GitHub issue #27 covers DeepInheritanceTree framework-root noise, and GitHub
issue #28 covers RepeatedBranching generic branch-subject triage.

## `MetzProject/ServiceSoup`

Result: **Validated**, behind `--project-analyzers`.

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

- Keep ServiceSoup as **Candidate** and still opt-in at this point in the
  calibration history. The expanded sample shows
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
- Keep ServiceSoup **Candidate** and opt-in at this point in the calibration
  history. It has the strongest true-positive
  evidence of the three project analyzers, but not enough breadth yet for
  default output.

Follow-up promotion review reran Chatwoot from repo-local scratch space and
added Spree as another service-heavy Rails target:

| Project | Revision | ServiceSoup findings | Triage |
| --- | --- | ---: | --- |
| `chatwoot/chatwoot` | `e86222034e39` | 3 | Same three plausible workflow true positives from the prior `perform` pass. |
| `spree/spree` | `7752652ef4ea` | 2 | One strong cart stock-reservation workflow and one low-priority seed setup orchestrator. |

The Spree stock-reservation finding is a useful new true positive:
`Spree::Carts::Update#sync_stock_reservations` coordinates release, reserve, and
extend services for the same cart. The Spree seed finding is a weaker signal:
`Spree::Seeds::All#call` invokes many setup tasks in sequence, which is visible
coordination but is less likely to represent everyday domain workflow pressure.

Seed/setup downranking follow-up:

- ServiceSoup now detects setup-like workflows by path, namespace/class name, or
  method name terms such as `seed`, `seeds`, `setup`, `install`, and
  `bootstrap`.
- Setup-like findings keep `status: validated` but emit `confidence: low`,
  `severity: setup orchestration`, setup-specific triage language, and
  setup-specific next moves.
- Rule summaries and text-rendered rule blocks choose the highest-priority
  triage metadata when a rule has mixed normal and setup findings, so one seed
  finding does not downrank the whole `MetzProject/ServiceSoup` block.

Calibration threshold for opt-in validation:

- Pass if calibration finds at least 10 medium-confidence, design-pressure
  ServiceSoup findings across at least 5 real Rails repositories.
- Pass only if no sampled repository has high-volume ServiceSoup output that
  would bury other findings.
- Pass only if recurring low-value categories are either downranked,
  suppressed, or explicitly documented before counting the analyzer as
  validated.

Repo-local calibration rerun after setup downranking:

| Project | Revision | Medium design-pressure findings | Low setup findings | Result |
| --- | --- | ---: | ---: | --- |
| `chatwoot/chatwoot` | `e86222034e39` | 3 | 0 | pass |
| `discourse/discourse` | `2115f1cac5f9` | 1 | 0 | pass |
| `forem/forem` | `d9a393f1d502` | 2 | 0 | pass |
| `mastodon/mastodon` | `34bbb4748223` | 3 | 0 | pass |
| `spree/spree` | `7752652ef4ea` | 1 | 1 | pass with setup downranked |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 | neutral |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 0 | 0 | neutral |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 | neutral |

Threshold result: **pass for validated opt-in status**. The rerun produced 10
medium-confidence design-pressure findings across 5 repositories, plus 1
downranked setup finding, and no high-volume ServiceSoup target. This does not
settle default-output readiness; it establishes that ServiceSoup is ready for a
validated opt-in status.

Promotion-review decision:

- Promote ServiceSoup to **Validated** while keeping it opt-in behind
  `--project-analyzers`.
- Do not add `execute` or `run` support yet. The passing evidence still comes
  from existing `call` and `new(...).perform` support.

## `MetzProject/PackageDependencyPressure`

Result: **Candidate**, behind `--project-analyzers`.

This analyzer was added after the initial calibration passes. It uses the
optional project index to report classes or modules referenced from at least
12 files across at least 5 coarse packages outside the declaration's own
package. The first slice requires a namespaced declaration so broad root
namespaces and top-level Rails model constants do not dominate early output.
Findings emit one primary offense at the declaration path and preserve the
referring files and packages in project-analyzer metadata.
The first slice only counts declarations under `app/` and `lib/` packages, and
it ignores references from `spec/`, `test/`, `lib/tasks/`, `lib/seeders/`,
`lib/seed_data/`, `lib/test_data/`, and `lib/generators/` when measuring
cross-package pressure. Broad shared dependencies such as configuration,
settings, event registries, exception families, and infrastructure hubs are
reported with lower confidence and `shared dependency` triage rather than
suppressed.

Initial real-project calibration before threshold tuning used 4 files across 2
packages. It produced high-volume output on most full applications:

| Project | Revision | Findings before tuning |
| --- | --- | ---: |
| `chatwoot/chatwoot` | `e86222034e39` | 30 |
| `discourse/discourse` | `2115f1cac5f9` | 38 |
| `forem/forem` | `d9a393f1d502` | 32 |
| `mastodon/mastodon` | `34bbb4748223` | 33 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 34 |
| `spree/spree` | `7752652ef4ea` | 75 |
| `solidusio/solidus` | `8d781ac742e3` | 0 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 |

Pass/fail threshold for promotion review:

- Pass only if a rerun across at least five real Rails applications produces
  reviewable volume and a majority of inspected findings look like concrete
  package-boundary pressure.
- Fail if the sample is mostly broad public APIs, shared configuration,
  framework extension points, exceptions, utility hubs, setup/support paths, or
  intentional platform-wide model references.
- Treat 10-15 findings in any one full application as the upper reviewable
  range. Higher volume needs stronger filtering before validation.

Repo-local calibration rerun after threshold tuning and setup/support path
suppression:

| Project | Revision | Tuned findings | Result |
| --- | --- | ---: | --- |
| `chatwoot/chatwoot` | `e86222034e39` | 2 | fail for validation; mixed event/Redis hubs |
| `discourse/discourse` | `2115f1cac5f9` | 10 | fail for validation; exceptions, utilities, framework hooks |
| `forem/forem` | `d9a393f1d502` | 5 | fail for validation; shared settings dominate |
| `mastodon/mastodon` | `34bbb4748223` | 3 | fail for validation; ActivityPub/errors dominate |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 10 | fail for validation; broad Spree/OpenFoodNetwork APIs |
| `spree/spree` | `7752652ef4ea` | 10 | fail for validation; broad commerce models/config |
| `solidusio/solidus` | `8d781ac742e3` | 0 | neutral |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | neutral |

Threshold result: **fail for validated opt-in status**. The tuning made output
reviewable by volume, but the leading categories are still too broad for a
validated analyzer. The next improvement should classify or suppress global
configuration, public namespace APIs, framework extension points, and exception
families before another promotion attempt.

Repo-local calibration rerun after shared-dependency downranking:

| Project | Revision | Manual package-boundary findings | Shared-dependency findings | Result |
| --- | --- | ---: | ---: | --- |
| `chatwoot/chatwoot` | `e86222034e39` | 0 | 2 | neutral after shared-dependency downrank |
| `discourse/discourse` | `2115f1cac5f9` | 0 | 10 | neutral after scheduler/rate-limiter downrank |
| `forem/forem` | `d9a393f1d502` | 0 | 5 | neutral after shared-settings downrank |
| `mastodon/mastodon` | `34bbb4748223` | 1 | 2 | fail for validation; `ActivityPub::TagManager` remains broad |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 7 | 3 | mixed; concrete Spree model pressure remains |
| `spree/spree` | `7752652ef4ea` | 6 | 4 | mixed; concrete commerce model pressure remains |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 | neutral |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 | neutral |

Shared-dependency result: **pass for candidate opt-in status; still fail for
validated opt-in status**. The rerun leaves 14 manual package-boundary findings
and 26 downranked shared-dependency findings across the sample. Spree and
OpenFoodNetwork retain useful domain-model pressure around `Order`, `Product`,
`Variant`, `Store`, and related commerce models. The remaining broad manual
examples, especially `ActivityPub::TagManager` and
`OpenFoodNetwork::ScopeVariantToHub`, are acceptable candidate-level review
prompts, but they block validated status.

Current decision:

- Promote PackageDependencyPressure to **Candidate** and keep it opt-in.
- Treat findings as dependency-pressure prompts, not dependency-direction
  violations. The first slice deliberately does not infer whether a reference
  is architecturally wrong.
- Do not mark it **Validated** or move it toward default output until broader
  real-application passes show mostly concrete boundary-pressure examples after
  broad public/infra categories are handled.

## `MetzProject/NamespaceLeakPressure`

Result: **Candidate**, behind `--project-analyzers`.

This analyzer was added after `PackageDependencyPressure` to report deeply
nested declarations whose references spread outside their home namespace into
at least three files across three packages. Public constants, nested exception
families, and framework or extension namespaces are downranked as
low-confidence shared-namespace findings rather than counted as
medium-confidence namespace-boundary evidence.

Candidate-path checkpoint on 2026-06-29:

- Pass threshold: revisit validation only if the active repo-local calibration
  home shows at least one additional clear medium-confidence true positive
  beyond the two already documented.
- Active source: `tmp/project-analyzer-calibration/apps`; historical
  `/private/tmp` calibration paths were not used.
- Result: **fail for validation; stop/defer**. A read-only rerun over active
  checkouts found only two medium-confidence namespace-boundary findings:
  `Badge::Trigger::PostRevision` in Discourse and
  `Spree::Gateway::StripeSCA` in OpenFoodNetwork. Chatwoot, Forem, Mastodon,
  Solidus, and Decidim produced no additional medium-confidence
  namespace-boundary findings.
- Decision: keep NamespaceLeakPressure as a candidate opt-in analyzer. Do not
  start a full graduation loop until a new approved target or refreshed active
  checkout produces at least a third clear medium-confidence namespace-boundary
  positive.

## `MetzProject/RepeatedBranching`

Result: **Validated**, behind `--project-analyzers`.

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

Expanded decision at this point in the calibration history:

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
- At this point in the calibration history, keep RepeatedBranching
  **Experimental** until users have more explicit confidence/severity language
  for interpreting repeated branch tables.

Validation follow-up added Spree at `7752652ef4ea` as one more service-heavy
Rails target. The run produced three findings and six occurrences:

- `error` repeated in `Spree::Api::V3::ErrorHandler#render_service_error` and
  `Spree::Payment::Processing#gateway_error`.
- `payment.source_type` repeated in admin and public payment serializers.
- `code` repeated in country-to-timezone and store-default timezone workflows.

Validation threshold:

- Pass if one more representative Rails target stays below five findings.
- Pass only if every finding carries enough enclosing class/module and method
  context to make generic branch subjects reviewable.
- Pass only if no high-volume outlier appears after context enrichment.

Threshold result: **pass for validated opt-in status**. Spree produced three
context-readable findings, stayed below the volume threshold, and did not add a
new recurring false-positive category.

## `MetzProject/DeepInheritanceTree`

Result: **Validated opt-in**, not default-output eligible.

The analyzer depends on the optional Rubydex-backed project index. Without the
optional bundle group enabled, it contributes no findings. First-party cops now
compose Metz helpers directly with `RuboCop::Cop::Metz::OnSendCsendBridge`;
the old local base shim has been removed as a breaking cleanup.

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

- At this checkpoint, keep DeepInheritanceTree **Experimental** and opt-in.
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

- At this checkpoint, keep DeepInheritanceTree **Experimental** and opt-in. The
  output volume is now reviewable by finding count, but Discourse, Mastodon,
  and Open Food Network still produce enough broad-root findings that default
  output would be too assertive.
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

Root-kind labeling follow-up on 2026-06-25: `MetzProject/DeepInheritanceTree`
now labels common broad roots in both the visible message and
`project_analyzer.root_kind` metadata. The first supported labels are
`framework root`, `rails application base`, `controller base`,
`serializer base`, `application service base`, and `application job base`.
The 2026-06-29 expansion added `policy base`, `worker base`, `exception base`,
`cli base`, and `abstract base`.
Direct `ProjectAnalyzerRunner` reruns against Mastodon `34bbb4748223` and
Discourse `2115f1cac5f9` used the same `app/` and `lib/` paths as the
report-priority samples. Finding counts did not change: Mastodon still produced
40 DeepInheritanceTree findings, and Discourse still produced 47.

Examples from the rerun:

- `discourse`: `ActiveModel::Serializer (framework root)`,
  `ApplicationController (rails application base)`,
  `ApplicationSerializer (serializer base)`, and
  `Jobs::Base (application job base)`.
- `mastodon`: `ApplicationController (rails application base)`,
  `ApplicationRecord (rails application base)`,
  `Api::BaseController (controller base)`,
  `ActivityPub::Serializer (serializer base)`, and
  `BaseService (application service base)`.

Root-kind decision:

- Promote DeepInheritanceTree to **Candidate** and keep it opt-in. Root-kind
  labels plus `broad base` downranking make broad-root findings interpretable
  enough for opt-in review, but they are not a default-output signal.
- Keep the labels as metadata as well as text. JSON, SARIF, and downstream
  consumers can use `project_analyzer.root_kind` without parsing messages.
- Do not filter root kinds yet. The labeled categories still need calibration
  across more projects before deciding whether any category should be hidden or
  summarized separately.
- Broad framework and Rails application bases are reported with
  `confidence: low` and `severity: broad base`. Unlabeled custom inheritance
  roots keep `confidence: medium` and `severity: manual review`.

Root-kind expansion and opt-in validation follow-up on 2026-06-29:
`MetzProject/DeepInheritanceTree` now also labels recurring controller, job,
service, policy, worker, exception, CLI, and explicit abstract-base roots. The
rerun used existing repo-local scratch checkouts under
`tmp/project-analyzer-calibration/apps/` and did not use the historical
`/private/tmp` calibration paths.

| Project | Revision | Findings | Medium manual-review findings | Low broad-base findings |
| --- | --- | ---: | ---: | ---: |
| `chatwoot/chatwoot` | `e86222034e39` | 32 | 2 | 30 |
| `discourse/discourse` | `2115f1cac5f9` | 47 | 13 | 34 |
| `forem/forem` | `d9a393f1d502` | 26 | 3 | 23 |
| `mastodon/mastodon` | `34bbb4748223` | 40 | 6 | 34 |
| `openfoodfoundation/openfoodnetwork` | `be9d51ab32a6` | 29 | 10 | 19 |
| `decidim/decidim` | `b2001fa7c9d2` | 0 | 0 | 0 |
| `solidusio/solidus` | `8d781ac742e3` | 0 | 0 | 0 |

Validation decision:

- Promote DeepInheritanceTree to **Validated** for opt-in project-analyzer
  output. The remaining medium-confidence findings stay below 15 per full
  target and are concrete inheritance-family prompts, while broad recurring
  base categories remain visible with lower-confidence `broad base` triage.
- Do not mark it default-output eligible. Its findings depend on the optional
  Rubydex-backed project index, and broad-root output still needs opt-in
  reviewer intent.
- Keep expanded root-kind labels in metadata so downstream consumers can group
  or filter broad bases without parsing message text.
