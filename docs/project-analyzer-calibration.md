# Project analyzer calibration

Last updated: 2026-07-02.

This note records real-world calibration passes for the opt-in analyzers behind
`metz-scan scan --project-analyzers`. The goal was to decide whether
`MetzProject/ServiceSoup`, `MetzProject/RepeatedBranching`, or
`MetzProject/DeepInheritanceTree` is ready to move closer to default scan
output. `MetzProject/PackageDependencyPressure` was added later and now has a
candidate opt-in calibration pass after shared-dependency downranking.
`MetzProject/NamespaceLeakPressure` was added later as an uncalibrated
candidate and should remain opt-in until real-project samples confirm sparse,
useful namespace-boundary findings. `MetzProject/ImplicitContextPressure` was
added later as a candidate opt-in analyzer for repeated ambient context access.
`MetzProject/RepeatedQueryCriteria` was added later as a candidate opt-in
analyzer for repeated query predicates. `MetzProject/SubclassOverridePressure`
was added later as a candidate opt-in analyzer for repeated subclass method
overrides.

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
Use the repeatable evidence runner for new calibration slices:

```bash
bin/check_project_analyzer_calibration --text
bin/check_project_analyzer_calibration --text --analyzer MetzProject/RepeatedBranching
bin/check_project_analyzer_calibration --text --targets-file tmp/project-analyzer-calibration/project_analyzer_targets.yml
```

With no paths, the runner discovers target checkouts under
`tmp/project-analyzer-calibration/apps/`, scans each target's `app/` and `lib/`
directories when present, records checkout revisions, index metadata, finding
counts, triage summaries, and breakdowns by rule, confidence, severity, and
the common `project_analyzer_category` metadata field. Individual analyzer
metadata still preserves analyzer-specific category keys such as
`decision_subject_kind`, `dependency_pressure_category`, `namespace_leak_category`,
`implicit_context_category`, `repeated_query_category`, `root_kind`, and
`subclass_override_category` for compatibility and detailed inspection, but
summary breakdowns use the common category field so renderer code does not
need to know every analyzer-specific metadata key.
Package- and namespace-pressure analyzers also include a shared
`reference_shape` metadata object with referring file count, referring package
count, referring package roots, and referring package leafs so future
calibration can compare cross-package spread without duplicating metadata
logic.
Discovered targets without top-level `app/` or `lib/` are recorded with
no-scan metadata instead of falling back to a whole-root scan. Pass explicit
paths for intentional one-off scans, `--analyzer` one or more times for a
focused rule sample, or `--no-write` for a dry local summary. Use
`--targets-file` for approved nested or multi-root fixtures that should not be
scanned from the checkout root. Target-file roots are resolved relative to the
current working directory; each `scan_paths` entry is resolved relative to its
target root, and missing scan paths fail the run. Do not combine
`--targets-file` with positional `PATH` arguments; use one target source per
run.

```yaml
targets:
  - root: tmp/project-analyzer-calibration/apps/spree
    scan_paths:
      - spree/core/app
      - spree/core/lib
```

The runner writes `summary.json` plus `summary.md` under
`tmp/project-analyzer-calibration/results/<run-id>/`. Text, JSON, and Markdown
summaries include a limited, priority-sorted `notable_findings` list for
medium-confidence findings so calibration artifacts preserve the named manual
review prompts instead of only aggregate counts. Summaries also include a
readiness/backlog section keyed by analyzer rule id. That section records the
current disposition, evidence boundary, next useful task, and explicit
not-next boundary so calibration output can show analyzer readiness without
changing scan behavior or analyzer status.

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

Redmine target-intake follow-up on 2026-07-02 added `redmine/redmine` at
`3386d9595767` to the active target manifest with `app` and `lib` scan paths.
This target was chosen as a project/issue-tracking Rails app outside the
current support, social/forum, and commerce-heavy fixture families. The focused
candidate-analyzer run over the expanded manifest produced 220 findings and
220 offenses across the five parked candidate analyzers:
`PackageDependencyPressure=40`, `NamespaceLeakPressure=39`,
`ImplicitContextPressure=11`, `RepeatedQueryCriteria=16`, and
`SubclassOverridePressure=114`. The added target changed evidence, not analyzer
behavior, rollout status, thresholds, or default-output eligibility.

Rubygems.org target-intake follow-up on 2026-07-02 added
`rubygems/rubygems.org` at `757047af5070` to the active target manifest with
`app` and `lib` scan paths. This target was chosen as a package-registry and
supply-chain security Rails app outside the current support, social/forum,
commerce, and issue-tracking fixture families. The focused candidate-analyzer
run over the expanded manifest produced 231 findings and 231 offenses across
the five parked candidate analyzers: `PackageDependencyPressure=40`,
`NamespaceLeakPressure=42`, `ImplicitContextPressure=12`,
`RepeatedQueryCriteria=16`, and `SubclassOverridePressure=121`. The added
target changed evidence, not analyzer behavior, rollout status, thresholds, or
default-output eligibility.

ManageIQ target-intake follow-up on 2026-07-02 added `ManageIQ/manageiq` at
`67749d3468ce` to the active target manifest with `app` and `lib` scan paths.
This target was chosen as an infrastructure/operations Rails app after
Rubygems.org still left package-boundary evidence too narrow. The focused
candidate-analyzer run over the expanded manifest produced 248 findings and
248 offenses across the five parked candidate analyzers:
`PackageDependencyPressure=43`, `NamespaceLeakPressure=44`,
`ImplicitContextPressure=12`, `RepeatedQueryCriteria=16`, and
`SubclassOverridePressure=133`. The added target changed evidence, not analyzer
behavior, rollout status, thresholds, or default-output eligibility.

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

- `MetzProject/ServiceSoup` is validated for project-analyzer output.
  The latest repo-local rerun confirmed sparse, reviewable findings that still
  look like plausible true positives in service-heavy Rails applications. A
  follow-up promotion review added one more strong service-workflow target and
  one setup-orchestration example that is now downranked with low confidence
  and setup-specific triage language. Its medium-confidence design-pressure
  findings are explicitly default-output eligible; setup-orchestration findings
  remain available only with `--project-analyzers`.
- `MetzProject/RepeatedBranching` is validated for project-analyzer output.
  The counts are stable, context-enriched findings are readable, and a Spree
  follow-up produced only three findings with concrete domain context. Its
  medium-confidence design-pressure findings are explicitly default-output
  eligible; lower-confidence generic-subject findings remain available only
  with `--project-analyzers`.
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
- `MetzProject/ImplicitContextPressure` is candidate for opt-in
  project-analyzer output. The first slice is AST-only and reports repeated
  Rails `CurrentAttributes`-style ambient context access across at least three
  files and two coarse packages. It now includes namespaced CurrentAttributes
  constants such as `Spree::Current`. It is not default-output eligible and
  should not move toward validated status until broader calibration shows the
  signal is sparse and reviewable outside the initial Chatwoot and Spree
  evidence.
- `MetzProject/RepeatedQueryCriteria` is candidate for opt-in project-analyzer
  output. The first slice is AST-only and reports simple constant-receiver
  query criteria with at least two literal hash keys repeated across at least
  three files and two coarse packages. Active-fixture evidence currently covers
  positive `where` filters and `find_by` lookups; negative `where.not` is
  supported by tests but not yet fixture-evidenced at the current threshold. It
  is not default-output eligible and should not move toward validated status
  until broader calibration confirms the query-repetition signal is sparse and
  consistently actionable.
- `MetzProject/SubclassOverridePressure` is candidate for opt-in
  project-analyzer output. The first slice is index-backed and reports base
  classes whose known descendants override the same base-declared method in at
  least six subclasses. Broad framework, Rails application, controller, job,
  service, serializer, policy, worker, exception, CLI, and abstract bases are kept
  lower-confidence with broad-base triage. It records base method body kind and
  descendant `super` usage so medium findings can be separated into
  abstract-hook, cooperative, replacement, or unclassified override families.
  It is not default-output eligible and should not move toward validated status
  until follow-up calibration confirms those classified medium-confidence
  families are consistently actionable.

Current readiness/backlog boundaries are generated by the calibration evidence
runner instead of maintained as a second hand-written table in this document.
Run `bin/check_project_analyzer_calibration --text` or inspect the generated
`summary.md`/`summary.json` readiness section for the current disposition,
evidence boundary, next useful task, and not-next boundary. This document keeps
the historical evidence trail and rationale behind those current generated
entries.

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

Result: **Validated**. Medium-confidence design-pressure findings are
default-output eligible; lower-confidence setup-orchestration findings remain
available with `--project-analyzers`.

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
`lib/seed_data/`, `lib/test_data/`, `lib/generators/`, nested seed paths, and
nested `testing_support` paths when measuring cross-package pressure. Broad
shared dependencies such as configuration, settings, event registries,
exception families, infrastructure hubs, broad domain surfaces, and broad
protocol surfaces are reported with lower confidence and `shared dependency`
triage rather than suppressed. The current implementation expresses those
surface rules generically for conventional `app/models` domain models,
`lib/...` value objects, and `app/lib` protocol-manager style surfaces rather
than by checking active-fixture constant names.

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
validated opt-in status**. The rerun left 14 manual package-boundary findings
and 26 downranked shared-dependency findings across the sample. A targeted
2026-06-30 calibration pass then separated the remaining broad surfaces from
the stronger package-boundary prompt:

- `ActivityPub::TagManager` now downranks as a shared protocol URI/routing
  surface.
- OpenFoodNetwork `Spree::Order`, `Spree::Variant`, `Spree::Product`,
  `Spree::Money`, `Spree::User`, and `Spree::LineItem` now downranks as broad
  shared commerce domain/API surfaces.
- `OpenFoodNetwork::ScopeVariantToHub` remains a medium-confidence manual
  review candidate because it looks like a package-owned adapter participating
  in repeated cross-package scoping behavior.

After that targeted downranking, the active calibration evidence still does not
justify validated status: the useful manual signal is narrow and concentrated
in one application.

Manifest-backed follow-up on 2026-07-01 used the repeatable runner's
`--targets-file` option so nested Spree engine paths contributed evidence
without scanning the checkout root. The first manifest pass found 40
PackageDependencyPressure findings: 37 low-confidence shared dependencies and
3 medium manual-review package-boundary findings. The medium findings were
`OpenFoodNetwork::ScopeVariantToHub`, `Spree::Store`, and `Spree::Taxon`.
`Spree::Store` and `Spree::Taxon` were then calibrated as broad shared
commerce domain/API surfaces, consistent with the existing `Spree::*` model
downranking.

Post-downranking manifest-backed result:

| Project | Medium package-boundary findings | Shared-dependency findings |
| --- | ---: | ---: |
| `chatwoot/chatwoot` | 0 | 2 |
| `decidim/decidim` | 0 | 0 |
| `discourse/discourse` | 0 | 10 |
| `forem/forem` | 0 | 5 |
| `mastodon/mastodon` | 0 | 3 |
| `openfoodfoundation/openfoodnetwork` | 1 | 9 |
| `solidusio/solidus` | 0 | 0 |
| `spree/spree` nested engines | 0 | 9 |
| **Total** | **1** | **38** |

Decision: keep PackageDependencyPressure **Candidate** and opt-in. The
calibrated output is now sparse enough to review, but the only remaining
medium package-boundary finding is `OpenFoodNetwork::ScopeVariantToHub`, so
there is not enough cross-application positive evidence for validated status.

Targeted triage cleanup on 2026-07-01 removed the app-specific calibrated
shared-surface constant list from the analyzer and replaced it with generic
shared-surface predicates for conventional domain models, value objects, and
protocol-manager surfaces. A manifest-backed smoke run after that cleanup kept
the same review shape: 39 findings and 39 offenses, with 38 low-confidence
`shared_dependency` findings and the single medium `package_boundary` finding
for `OpenFoodNetwork::ScopeVariantToHub`.

Current decision:

- Keep PackageDependencyPressure **Candidate** and keep it opt-in.
- Treat findings as dependency-pressure prompts, not dependency-direction
  violations. The first slice deliberately does not infer whether a reference
  is architecturally wrong.
- Do not mark it **Validated** or move it toward default output until broader
  real-application passes show mostly concrete boundary-pressure examples after
  broad public/infra categories are handled.

Reference-shape follow-up on 2026-07-02 kept the manifest-backed count at 39
findings and 39 offenses: 38 low-confidence `shared_dependency` findings and
one medium `package_boundary` finding for
`OpenFoodNetwork::ScopeVariantToHub`. The analyzer now shares reference-set
and reference-metadata helpers with `NamespaceLeakPressure`, and its metadata
includes `reference_shape` for source-derived package-spread evidence. Rollout
status and default-output eligibility did not change.

Evidence-gap follow-up on 2026-07-02 reran the active manifest and confirmed
the same readiness shape: 39 findings and 39 offenses, with 38 low-confidence
`shared_dependency` findings and one medium `package_boundary` finding for
`OpenFoodNetwork::ScopeVariantToHub`. This is useful as a regression lock but
still too thin for analyzer promotion. The only medium finding is concentrated
in OpenFoodNetwork, while the rest of the sample is broad shared API,
infrastructure, value-object, or protocol-surface pressure already downranked
by the generic shared-surface rules.

Disposition follow-up on 2026-07-02 checked the active fixture manifest for
unused evidence sources. The current manifest already covers the meaningful
repo-local Ruby roots: Chatwoot, Discourse, Forem, Mastodon, and
OpenFoodNetwork `app`/`lib`, Decidim and Solidus `lib`, and the nested Spree
engine roots. The remaining excluded paths are intentional setup or test noise
such as `spec`, `test`, `lib/tasks`, seed data, generators, and
`testing_support`. Current fixtures therefore do not provide a second
independent medium package-boundary example. Park the analyzer as
candidate-only until new approved targets produce broader medium
package-boundary evidence outside the current OpenFoodNetwork-heavy sample.
Rollout status, thresholds, classifier rules, and default-output eligibility
did not change.

Redmine target-intake follow-up on 2026-07-02 increased the manifest-backed
count to 40 findings and 40 offenses: 39 low-confidence `shared_dependency`
findings and the same single medium `package_boundary` finding for
`OpenFoodNetwork::ScopeVariantToHub`. Redmine added shared-dependency evidence
but no independent medium package-boundary prompt. Decision: keep
PackageDependencyPressure **Candidate** and parked; add another domain-distinct
target before reopening package-boundary rules, and do not retune thresholds or
downrank the sole medium finding from this expanded sample.

Rubygems.org target-intake follow-up on 2026-07-02 kept the manifest-backed
count at 40 findings and 40 offenses: 39 low-confidence `shared_dependency`
findings and the same single medium `package_boundary` finding for
`OpenFoodNetwork::ScopeVariantToHub`. Rubygems.org added no package-pressure
evidence at the current threshold. Decision: keep PackageDependencyPressure
**Candidate** and parked; the next target should be an infrastructure or
operations app before reopening package-boundary rules.

ManageIQ target-intake follow-up on 2026-07-02 increased the manifest-backed
count to 43 findings and 43 offenses: 40 low-confidence `shared_dependency`
findings and 3 medium `package_boundary` findings. ManageIQ added two medium
package-boundary prompts:

| Target | Declaration | Quality bucket | Rationale |
| --- | --- | --- | --- |
| `manageiq` | `ActiveRecord::Base` | Needs context | The finding captures many database and migration references plus ManageIQ's `lib/extensions/ar_base.rb` patch, but `ActiveRecord::Base` is a framework root and may be expected infrastructure coupling. |
| `manageiq` | `Vmdb::Logging` | Useful design-pressure prompt | Logging is mixed into framework extensions, workers, inventory parsers, importers, mailers, and models across many packages, making a cross-cutting logging dependency visible throughout the app. |

Decision: keep PackageDependencyPressure **Candidate** and opt-in. ManageIQ
finally adds independent infrastructure package-boundary evidence, but one of
the new prompts is a framework root and the other is cross-cutting logging.
Compare these prompts against one more infrastructure or operations target
before promotion, threshold, or framework-root downranking discussions.

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

Manifest-backed follow-up on 2026-07-01 used nested Spree engine paths through
the calibration runner target manifest. The first pass produced 37 findings:
32 low-confidence shared namespaces and 5 medium manual-review namespace
boundaries. Two Spree medium findings were partly supported by nested seed or
`testing_support` references, so the shared pressure-analyzer path filter now
ignores nested seed and `testing_support` paths.

Post-filter manifest-backed result:

| Project | Medium namespace-boundary findings | Shared-namespace findings |
| --- | ---: | ---: |
| `chatwoot/chatwoot` | 0 | 9 |
| `decidim/decidim` | 0 | 0 |
| `discourse/discourse` | 1 | 11 |
| `forem/forem` | 0 | 2 |
| `mastodon/mastodon` | 0 | 2 |
| `openfoodfoundation/openfoodnetwork` | 1 | 3 |
| `solidusio/solidus` | 0 | 0 |
| `spree/spree` nested engines | 1 | 4 |
| **Total** | **3** | **31** |

Remaining medium findings are `Badge::Trigger::PostRevision`,
`Spree::Gateway::StripeSCA`, and `Spree::PaymentMethod::StoreCredit`.
Decision: keep NamespaceLeakPressure **Candidate** and opt-in. The new Spree
StoreCredit finding is plausible, but two of the three medium findings are in
the Spree/OpenFoodNetwork commerce family, so the evidence is still too narrow
for validated status.

Reference-shape follow-up on 2026-07-02 kept the manifest-backed count at 34
findings and 34 offenses: 31 low-confidence `shared_namespace` findings and
three medium `namespace_boundary` findings. The analyzer now shares
reference-set and reference-metadata helpers with `PackageDependencyPressure`,
and its metadata includes `reference_shape` for source-derived package-spread
evidence. Rollout status and default-output eligibility did not change.

Medium-finding quality follow-up on 2026-07-02 reran the active manifest and
kept the same 34-finding shape. The 31 low-confidence `shared_namespace`
findings remain intentionally downranked public constants, exception families,
or framework/extension namespaces. The three medium `namespace_boundary`
findings are plausible but still too narrow for promotion:

| Target | Declaration | Quality bucket | Rationale |
| --- | --- | --- | --- |
| `discourse` | `Badge::Trigger::PostRevision` | Useful design-pressure prompt | Post creation and revision flows pass a nested badge trigger constant into `BadgeGranter`, making caller code know the trigger namespace. |
| `openfoodnetwork` | `Spree::Gateway::StripeSCA` | Needs context | Admin payment-method flows, serializers, and subscription jobs select a concrete Stripe payment provider; this may be intentional extension-point wiring. |
| `spree` | `Spree::PaymentMethod::StoreCredit` | Needs context | Store-credit setup and checkout code reference a concrete payment method type across packages, but it is a core Spree payment extension concept. |

Decision: keep NamespaceLeakPressure **Candidate** and opt-in. The medium
bucket has one useful prompt and two commerce/payment extension examples that
need broader comparison before changing status, thresholds, classifier rules,
or default-output eligibility. Future evidence work should add or refresh
approved calibration targets that can produce non-commerce namespace-boundary
examples; do not add app-specific suppressions or downrank payment namespaces
from this sample alone.

Redmine target-intake follow-up on 2026-07-02 increased the manifest-backed
count to 39 findings and 39 offenses: 33 low-confidence `shared_namespace`
findings and 6 medium `namespace_boundary` findings. Redmine added three
medium findings:

| Target | Declaration | Quality bucket | Rationale |
| --- | --- | --- | --- |
| `redmine` | `Redmine::Activity::Fetcher` | Useful design-pressure prompt | Activity controllers, helpers, and project/user models construct the activity fetcher directly, making application code know the nested activity service namespace. |
| `redmine` | `Redmine::Scm::Adapters` | Needs context | Repository controllers and version/info helpers reach into SCM adapter constants and exceptions, but SCM adapters are likely an intentional extension surface. |
| `redmine` | `Redmine::Scm::Base` | Needs context | Repository helpers, repository models, and settings views use the SCM registry, which may be the intended public interface for source-control integration. |

Decision: keep NamespaceLeakPressure **Candidate** and opt-in. Redmine improves
the evidence by adding non-commerce namespace-boundary examples, but two of its
three medium findings are still SCM extension infrastructure. Compare the
Redmine activity and SCM prompts against at least one more non-commerce target
before status, default-output, threshold, or classifier discussions.

Rubygems.org target-intake follow-up on 2026-07-02 increased the
manifest-backed count to 42 findings and 42 offenses: 33 low-confidence
`shared_namespace` findings and 9 medium `namespace_boundary` findings.
Rubygems.org added three medium OIDC/security-policy findings:

| Target | Declaration | Quality bucket | Rationale |
| --- | --- | --- | --- |
| `rubygems.org` | `OIDC::AccessPolicy::Statement` | Useful design-pressure prompt | OIDC controllers, models, and form views construct policy statements directly, making policy-language internals visible outside the access-policy model. |
| `rubygems.org` | `OIDC::AccessPolicy::Statement::Condition` | Useful design-pressure prompt | Controllers, Avo resources, models, and form views construct conditions directly, spreading low-level claim/operator details across the app. |
| `rubygems.org` | `OIDC::TrustedPublisher::GitHubAction` | Useful design-pressure prompt | Controllers, helpers, views, Avo resources, and policies reference the concrete trusted-publisher subtype across several packages. |

Decision: keep NamespaceLeakPressure **Candidate** and opt-in. Rubygems.org
adds a useful non-commerce security-policy sample, but the current medium set
still mixes domain prompts, intentional SCM/public extension surfaces, and
security-policy value objects. Compare the Redmine SCM and Rubygems.org OIDC
prompts against an infrastructure target before status, default-output,
threshold, or classifier discussions.

ManageIQ target-intake follow-up on 2026-07-02 increased the manifest-backed
count to 44 findings and 44 offenses: 33 low-confidence `shared_namespace`
findings and 11 medium `namespace_boundary` findings. ManageIQ added two
medium reporting findings:

| Target | Declaration | Quality bucket | Rationale |
| --- | --- | --- | --- |
| `manageiq` | `ManageIQ::Reporting::Charting` | Needs context | The charting facade delegates to a detected plugin and is referenced by reporting/chart content code, but it may be an intentional public reporting entry point. |
| `manageiq` | `ManageIQ::Reporting::Formatter` | Needs context | Reporting formatters are referenced from report models and legacy compatibility aliases, so the spread may be intentional migration/public API wiring rather than namespace leakage. |

Decision: keep NamespaceLeakPressure **Candidate** and opt-in. ManageIQ adds
infrastructure reporting examples, but the medium set still mixes useful domain
prompts with likely public facades, extension points, and legacy compatibility
surfaces. Do not promote, downrank, suppress, or retune from this target alone.

## `MetzProject/ImplicitContextPressure`

Result: **Candidate**, behind `--project-analyzers`.

This analyzer reports repeated reliance on ambient context. The first slice
deliberately stays narrow: it detects `Current.<attribute>` and namespaced
`Current` reads and writes, plus literal `Thread.current[...]` key reads and
writes; it ignores lifecycle methods such as `Current.reset`,
`Spree::Current.reset`, and `Current.set(...)`, dynamic thread-local keys, and
named thread APIs such as `Thread.current.name`; it requires at least three
files across at least two coarse packages and emits one primary offense per
ambient context. The full reference list remains in project-analyzer metadata.

First active-fixture manifest pass on 2026-07-01 used the generic target
manifest:

```bash
bundle exec ruby bin/check_project_analyzer_calibration --text --no-write \
  --targets-file tmp/project-analyzer-calibration/project_analyzer_targets.yml \
  --analyzer MetzProject/ImplicitContextPressure
```

The run produced 5 findings and 5 offenses, all in `chatwoot/chatwoot`:

| Ambient context | Files | Packages |
| --- | ---: | ---: |
| `Current.account` | 77 | 8 |
| `Current.account_user` | 6 | 2 |
| `Current.contact` | 4 | 3 |
| `Current.executed_by` | 8 | 3 |
| `Current.user` | 29 | 8 |

Decision: keep ImplicitContextPressure **Candidate** and opt-in. The Chatwoot
evidence is strong enough to justify an exploratory analyzer, but it is
concentrated in one target and needs broader calibration before validated
status or default-output eligibility.

Namespaced CurrentAttributes follow-up on 2026-07-01 used the same active
manifest and analyzer-specific command. The run produced 10 findings and 10
offenses, still all medium-confidence manual-review candidates:

| Target | Ambient context | Files | Packages |
| --- | --- | ---: | ---: |
| `chatwoot` | `Current.account` | 77 | 8 |
| `chatwoot` | `Current.account_user` | 6 | 2 |
| `chatwoot` | `Current.contact` | 4 | 3 |
| `chatwoot` | `Current.executed_by` | 8 | 3 |
| `chatwoot` | `Current.user` | 29 | 8 |
| `spree` | `Spree::Current.channel` | 5 | 3 |
| `spree` | `Spree::Current.currency` | 8 | 4 |
| `spree` | `Spree::Current.locale` | 6 | 3 |
| `spree` | `Spree::Current.market` | 5 | 4 |
| `spree` | `Spree::Current.store` | 21 | 8 |

Decision: keep ImplicitContextPressure **Candidate** and opt-in. The
namespaced pass broadens the evidence beyond Chatwoot, but the new findings
are all from Spree's framework-level `Current` surface and still need manual
review before any validated-status or default-output discussion.

Category-aware follow-up on 2026-07-02 kept the manifest-backed count at 10
findings and 10 offenses, but split `project_analyzer_category` into
`root_current_write=5` for Chatwoot and `namespaced_current_write=5` for Spree.
Messages now say whether the context is read, written, or both, and metadata
records `current_receiver_scope` plus `current_attribute`. Rollout status and
default-output eligibility did not change.

Literal `Thread.current[...]` follow-up on 2026-07-02 increased the
manifest-backed count to 11 findings and 11 offenses by adding one Mastodon
thread-local finding:

| Target | Ambient context | Files | Packages | Category |
| --- | --- | ---: | ---: | --- |
| `mastodon` | `Thread.current[:redis]` | 4 | 2 | `thread_current_write` |

Overall `project_analyzer_category` is now `root_current_write=5`,
`namespaced_current_write=5`, and `thread_current_write=1`. The Thread.current
slice only accepts literal symbol or string bracket keys and keeps dynamic
thread-local access out of scope. Rollout status and default-output eligibility
did not change.

Backlog-selection follow-up on 2026-07-02 reran the active manifest and kept the
same shape: 11 findings and 11 offenses, all medium-confidence manual-review
signals. Compared with the already-dispositioned repeated-query, package, and
subclass analyzers, this is the clearest next evidence target because it has
cross-application coverage but no explicit useful-vs-mechanical quality split
yet. This set up a focused quality pass over the 5 Chatwoot root `Current`
findings, 5 Spree namespaced `Current` findings, and 1 Mastodon
`Thread.current[:redis]` finding.

Focused quality pass on 2026-07-02 reran the active manifest and kept the same
11-finding shape, but classified the findings as 9 mechanical framework-state
signals, 1 useful design-pressure prompt, and 1 needs-context fallback:

| Finding group | Count | Quality bucket | Rationale |
| --- | ---: | --- | --- |
| `Current.account`, `Current.account_user`, `Current.contact` | 3 | Mechanical framework state | Chatwoot account, authorization, and contact setup are request/bootstrap boundaries. |
| `Spree::Current.channel`, `Spree::Current.currency`, `Spree::Current.locale`, `Spree::Current.market`, `Spree::Current.store` | 5 | Mechanical framework state | Spree uses its namespaced `Current` surface for API request context, fallback resolution, and import-job store setup/cleanup. |
| `Thread.current[:redis]` | 1 | Mechanical framework state | Mastodon's thread-local value is an infrastructure connection cache. |
| `Current.executed_by` | 1 | Useful design-pressure prompt | Chatwoot ambient execution identity crosses assignment/automation services, model concerns, and event dispatch metadata, and it changes activity-message content. |
| `Current.user` | 1 | Needs context | Chatwoot has broad current-user usage, but the notable `NotificationBuilder` sample is a fallback for `secondary_actor`, which may be intentional builder API shape. |

Decision: keep ImplicitContextPressure **Candidate** and opt-in. Do not promote,
make default-output eligible, add suppressions, retune thresholds, or add more
global-access forms from this sample. Future work should use broader samples to
separate generic boundary/setup state from ambient identity dependencies before
changing analyzer behavior.

Rubygems.org target-intake follow-up on 2026-07-02 increased the
manifest-backed count to 12 findings and 12 offenses by adding
`Current.user` from `Api::BaseController` authentication. The new finding is a
needs-context identity prompt, not a promotion signal: API authentication writes
the current user, while ownership auditing and transfer/onboarding flows read
it. The expanded quality split is now 9 mechanical framework-state signals,
1 useful execution-identity prompt, and 2 needs-context identity prompts.
Rollout status, thresholds, detector scope, and default-output eligibility did
not change.

ManageIQ target-intake follow-up on 2026-07-02 kept the manifest-backed count
at 12 findings and 12 offenses. It added no implicit-context findings at the
current threshold. The quality split remains 9 mechanical framework-state
signals, 1 useful execution-identity prompt, and 2 needs-context identity
prompts. Rollout status, thresholds, detector scope, and default-output
eligibility did not change.

## `MetzProject/RepeatedQueryCriteria`

Result: **Candidate**, behind `--project-analyzers`.

This analyzer reports repeated ActiveRecord hash query criteria. The current
slice deliberately stays narrow: it accepts constant receivers and
constant-root no-argument scope chains for positive `where` filters, negative
`where.not` filters, and finder lookups; ignores dynamic SQL strings,
single-key lookups, dynamic scope chains, non-constant receivers, dynamic
hashes, bang finders, and broader relation APIs; requires the same receiver,
query method, and sorted criteria-key set to appear in at least three files
across at least two coarse packages; and emits one primary offense per
repeated query fingerprint. The full occurrence list remains in
project-analyzer metadata.

First active-fixture manifest pass on 2026-07-01 used the generic target
manifest:

```bash
bundle exec ruby bin/check_project_analyzer_calibration --text --no-write \
  --targets-file tmp/project-analyzer-calibration/project_analyzer_targets.yml \
  --analyzer MetzProject/RepeatedQueryCriteria
```

The run produced 6 findings and 6 offenses:

| Target | Query fingerprint | Files | Packages |
| --- | --- | ---: | ---: |
| `discourse` | `Draft.where(draft_key, user_id)` | 3 | 2 |
| `discourse` | `GroupUser.where(group_id, user_id)` | 3 | 2 |
| `discourse` | `Post.where(post_number, topic_id)` | 7 | 6 |
| `discourse` | `TopicUser.where(topic_id, user_id)` | 7 | 4 |
| `forem` | `Comment.where(commentable_id, commentable_type)` | 4 | 4 |
| `mastodon` | `AccountDomainBlock.where(account_id, domain)` | 4 | 4 |

Category-aware follow-up on 2026-07-02 kept the manifest-backed count at 6
findings and 6 offenses, but split `project_analyzer_category` into
`scoped_association_where_criteria=3`,
`compound_association_where_criteria=2`, and
`polymorphic_where_criteria=1`. Messages and triage summaries now name the
criteria shape while preserving the first slice's detector scope. Rollout
status and default-output eligibility did not change.

Constant-root scope-chain follow-up on 2026-07-02 kept the manifest-backed
count at 6 findings and 6 offenses. The active fixture set did not add new
repeated scope-chain findings at the three-file/two-package threshold, but
the analyzer now accepts conservative no-argument scope chains such as
`Order.active.where(...)` and records `receiver_shape` as `constant` or
`scope_chain` in metadata. Dynamic receiver chains remain out of scope.
Rollout status and default-output eligibility did not change.

Finder and negative-filter follow-up on 2026-07-02 increased the
manifest-backed count to 15 findings and 15 offenses. The added findings came
from repeated multi-key `find_by` lookups; the active fixture set did not add a
repeated `where.not` finding at the current threshold. Operation metadata now
splits the current sample into `filter=6` and `finder=9`, with query methods
`where=6` and `find_by=9`. Overall `project_analyzer_category` is now
`scoped_association_where_criteria=8`,
`compound_association_where_criteria=2`,
`polymorphic_where_criteria=1`, and `where_hash_criteria=4`.
Rollout status and default-output eligibility did not change.

Calibration-quality follow-up on 2026-07-02 reviewed the 15 findings for
Sandi-Metz-style design-pressure usefulness rather than detector coverage.
The sample is promising but still mixed: 12 findings looked like useful manual
review prompts, 3 looked mostly mechanical or expected, and none justified
validated status or default-output eligibility.

| Target | Query fingerprint | Operation | Quality read |
| --- | --- | --- | --- |
| `discourse` | `Badge.find_by(enabled, id)` | finder | Mechanical/expected enabled-id lookup. |
| `discourse` | `Draft.where(draft_key, user_id)` | filter | Useful domain lookup prompt. |
| `discourse` | `GroupUser.where(group_id, user_id)` | filter | Mechanical/expected join-table membership lookup. |
| `discourse` | `Post.find_by(post_number, topic_id)` | finder | Useful post-within-topic lookup prompt. |
| `discourse` | `Post.where(post_number, topic_id)` | filter | Useful post-within-topic lookup prompt. |
| `discourse` | `PostLocalization.find_by(locale, post_id)` | finder | Useful locale-scoped content lookup prompt. |
| `discourse` | `PostRevision.find_by(number, post_id)` | finder | Useful revision lookup prompt. |
| `discourse` | `TagLocalization.find_by(locale, tag_id)` | finder | Useful locale-scoped tag lookup prompt. |
| `discourse` | `TopicLocalization.find_by(locale, topic_id)` | finder | Useful locale-scoped topic lookup prompt. |
| `discourse` | `TopicUser.where(topic_id, user_id)` | filter | Mechanical/expected join-table membership lookup. |
| `forem` | `Comment.where(commentable_id, commentable_type)` | filter | Useful polymorphic lookup prompt. |
| `mastodon` | `AccountDomainBlock.where(account_id, domain)` | filter | Useful domain-blocking lookup prompt. |
| `mastodon` | `CustomEmoji.find_by(domain, shortcode)` | finder | Useful domain-shortcode lookup prompt. |
| `mastodon` | `Follow.find_by(account, target_account)` | finder | Useful follow-graph lookup prompt. |
| `mastodon` | `FollowRequest.find_by(account, target_account)` | finder | Useful follow-request lookup prompt. |

Readiness boundary: keep `MetzProject/RepeatedQueryCriteria` candidate-only.
Do not add more query forms until another calibration pass isolates pure
association-table lookups from business-named lookups and confirms whether the
mechanical bucket dominates. If the mechanical bucket stays small, keep
polymorphic lookups, localization lookups, follow-graph lookups, and
domain-block lookups in the main manual-review bucket. If join-table lookups
grow, consider a lighter triage bucket or softer wording for pure membership
tables before changing thresholds.

Membership-vs-domain follow-up on 2026-07-02 confirmed that the current 15
finding sample does not justify a Ruby behavior change yet. The useful bucket
is dominated by business-named lookup concepts: post-within-topic, localization,
revision, polymorphic comment, domain-block, custom emoji, and follow-graph
lookups. The mechanical bucket is limited to `Badge.find_by(enabled, id)` and
join-table membership lookups such as `GroupUser.where(group_id, user_id)` and
`TopicUser.where(topic_id, user_id)`. Treat this as a calibration boundary, not
a suppression rule: the current sample is too small for generic membership-table
downranking, but large enough to keep those cases separate from the stronger
domain lookup prompts in future reviews.

Redmine target-intake follow-up on 2026-07-02 increased the manifest-backed
count to 16 findings and 16 offenses by adding
`Token.where(action, user_id)` across 4 files and 2 packages. Source review
classified the new Redmine finding as a useful token-lifecycle lookup prompt:
session, autologin, email-address, and two-factor code flows all repeat the same
token action/user criteria. The expanded quality split is now 13 useful
manual-review prompts and 3 mechanical lookups. Rollout status, thresholds,
detector scope, and default-output eligibility did not change.

Rubygems.org target-intake follow-up on 2026-07-02 kept the manifest-backed
count at 16 findings and 16 offenses. It added no repeated-query findings at
the current threshold, so the expanded quality split remains 13 useful
manual-review prompts and 3 mechanical lookups. Detector scope, thresholds,
rollout status, and default-output eligibility did not change.

ManageIQ target-intake follow-up on 2026-07-02 kept the manifest-backed count
at 16 findings and 16 offenses. It added no repeated-query findings at the
current threshold, so the expanded quality split remains 13 useful
manual-review prompts and 3 mechanical lookups. Detector scope, thresholds,
rollout status, and default-output eligibility did not change.

Decision: keep RepeatedQueryCriteria **Candidate** and opt-in. The first pass
is sparse and readable, but repeated query criteria can be intentional local
lookup duplication. It needs more calibration before validated status or
default-output eligibility.

## `MetzProject/SubclassOverridePressure`

Result: **Candidate**, behind `--project-analyzers`.

This analyzer reports repeated descendant overrides of a method declared by the
base class. The first slice is deliberately conservative: it requires the
optional project index, only uses known descendants and method declarations,
requires at least six descendants overriding the same method, and emits one
primary offense per override family. The full override list remains in
project-analyzer metadata. The analyzer also parses the base method body and
override bodies to classify base methods as `abstract_raise`, `empty`,
`default_value`, `concrete`, or `unknown`, and to count descendant overrides
that call `super`. Broad framework, Rails application, controller, job,
service, serializer, policy, worker, exception, CLI, and abstract bases are
still visible but reported with lower-confidence broad-base triage.

First active-fixture manifest pass on 2026-07-01 used the generic target
manifest:

```bash
bundle exec ruby bin/check_project_analyzer_calibration --text --no-write \
  --targets-file tmp/project-analyzer-calibration/project_analyzer_targets.yml \
  --analyzer MetzProject/SubclassOverridePressure
```

The latest method-identity follow-up produced 106 findings and 106 offenses:

| Target | Findings | Medium | Low | Category mix |
| --- | ---: | ---: | ---: | --- |
| `chatwoot` | 10 | 0 | 10 | `broad_root_override=10` |
| `decidim` | 0 | 0 | 0 | none |
| `discourse` | 17 | 13 | 4 | `abstract_hook_override=8`, `cooperative_override=4`, `replacement_override=1`, `broad_root_override=4` |
| `forem` | 15 | 3 | 12 | `replacement_override=3`, `broad_root_override=12` |
| `mastodon` | 16 | 1 | 15 | `abstract_hook_override=1`, `broad_root_override=15` |
| `openfoodnetwork` | 18 | 7 | 11 | `abstract_hook_override=5`, `cooperative_override=1`, `replacement_override=1`, `broad_root_override=11` |
| `solidus` | 0 | 0 | 0 | none |
| `spree` | 30 | 6 | 24 | `abstract_hook_override=4`, `replacement_override=2`, `broad_root_override=24` |

Overall category mix:

| Category | Findings | Meaning |
| --- | ---: | --- |
| `broad_root_override` | 76 | The base is already a broad framework/application/root-kind family and remains low-confidence broad-base output. |
| `abstract_hook_override` | 18 | The base method is empty, raises an abstract-method error, or returns a default literal value. |
| `cooperative_override` | 5 | At least one descendant override calls `super`, suggesting an extension protocol rather than pure replacement. |
| `replacement_override` | 7 | The base method is concrete and the sampled descendant overrides do not call `super`. |

Category-specific follow-up on 2026-07-01 kept the finding counts and category
mix unchanged, but now uses each medium category to render clearer report
messages, triage summaries, why-it-matters text, and suggested next moves. For
example, abstract hooks now say descendants implement an abstract hook,
cooperative overrides say descendants extend behavior with `super`, and
replacement overrides say descendants replace concrete base behavior.

Decision: keep SubclassOverridePressure **Candidate** and opt-in. The signal is
useful for identifying hook protocols, but the first pass is still too broad
for validated status or default output: 76 of 106 findings are intentionally
low-confidence broad-root prompts, and the 30 medium findings are now
classified for manual review rather than promoted or suppressed.

Method-identity follow-up on 2026-07-02 preserves `receiver_kind` and
`method_identity` in `ProjectIndex::MethodDeclaration`, so instance and
singleton override families are no longer grouped together. This fixed a
design-review blocker and changed the manifest-backed calibration count from
104 to 106 findings without changing rollout status or default-output
eligibility. A follow-up body-facts fix uses the AST node body API for both
instance and singleton methods, keeping the final count at 106 while classifying
18 abstract hooks, 5 cooperative overrides, and 7 replacement overrides.

Medium-finding quality follow-up on 2026-07-02 reran the active manifest and
confirmed the same shape: 106 findings and 106 offenses, with 76 low-confidence
`broad_root_override` findings and 30 medium manual-review findings. A
second-pass source review split the 30 medium findings into 18 design-pressure
hook protocol prompts, 5 deliberate extension APIs, 5 setup/mechanical
families, and 2 needs-context replacements. The medium sample is concrete and
readable, but still mixed enough to keep the analyzer candidate-only:

| Quality bucket | Count | Representative families | Read |
| --- | ---: | --- | --- |
| Design-pressure hook protocols | 18 | Discourse `Auth::Authenticator`, Discourse `ProblemCheck`, Mastodon `ActivityPub::Activity`, OpenFoodNetwork `Reporting::ReportTemplate`, Spree `Spree::Calculator`, `Spree::Export`, and `Spree::ShippingCalculator` | Useful manual-review prompts. The base methods raise abstract errors, return documented defaults, or otherwise define an implicit subclass protocol. |
| Deliberate extension APIs | 5 | Forem `Authentication::Providers::Provider`, Spree `Spree::PromotionRule` | Likely intentional adapter or rule extension surfaces. Keep visible for manual review, but do not treat as promotion evidence by themselves. |
| Setup/mechanical families | 5 | Discourse `DiscourseDev::Record`, Discourse `ThemeSettingsManager`, OpenFoodNetwork `Sets::ModelSet` | Mostly setup, coercion, or `super`-threading bookkeeping. Useful evidence that these families may need softer triage if they grow. |
| Needs context | 2 | Discourse `Auth::Authenticator#display_name`, OpenFoodNetwork `Reporting::ReportTemplate#search` | Intentional overrides, but local source alone does not decide whether a named formatter/query strategy would be clearer. |

Readiness boundary: keep `MetzProject/SubclassOverridePressure` candidate-only.
Do not retune thresholds, suppress medium categories, or add app-specific
classifier rules from this sample alone. The next useful step is to separate
deliberate extension-point families from design-pressure hook protocols across
more targets, while preserving the current broad-root downranking.

Redmine target-intake follow-up on 2026-07-02 increased the manifest-backed
count to 114 findings and 114 offenses: 80 low-confidence
`broad_root_override` findings and 34 medium manual-review findings. Redmine
added 8 findings overall: 4 low broad-root findings and 4 medium findings. The
medium additions are one useful `CustomField#type_name` abstract-hook family and
three `Redmine::Scm::Adapters::AbstractAdapter` replacement families for
`cat`, `entries`, and `info`. The SCM adapter findings are plausible manual
review prompts but also likely intentional adapter extension points, so they do
not change readiness. Keep the analyzer candidate-only and continue separating
generic hook-protocol evidence from deliberate extension APIs before any
promotion, suppression, or threshold discussion.

Rubygems.org target-intake follow-up on 2026-07-02 increased the
manifest-backed count to 121 findings and 121 offenses: 83 low-confidence
`broad_root_override` findings and 38 medium manual-review findings. Rubygems.org
added 7 findings overall: 3 low broad-root findings and 4 medium findings. The
medium additions are `Admin::ApplicationPolicy::Scope#resolve`,
`Avo::Actions::ActionHandler#handle_record`,
`Avo::Actions::ActionHandler#handle_standalone`, and cooperative
`Avo::Actions::ApplicationAction#fields` overrides. These are useful as
evidence that the analyzer finds policy/action hook protocols outside commerce
and social/forum apps, but they are also likely intentional extension APIs.
Keep the analyzer candidate-only and continue separating generic hook-protocol
evidence from deliberate framework or admin-tool extension points before any
promotion, suppression, or threshold discussion.

ManageIQ target-intake follow-up on 2026-07-02 increased the manifest-backed
count to 133 findings and 133 offenses: 86 low-confidence
`broad_root_override` findings and 47 medium manual-review findings. ManageIQ
added 12 findings overall: 3 low broad-root findings and 9 medium findings.
The medium additions include Ansible credential hooks (`env_vars` and
`write_config_files`), ManageIQ request hooks (`my_zone`, `my_queue_name`,
`my_role`, and `requested_task_idx`), request-task hooks
(`after_request_task_create`), and request-workflow hooks
(`automate_dialog_request` and `get_source_and_targets`). These are useful
calibration evidence for hook protocols in an infrastructure app, but they are
also likely intentional variation points. Keep the analyzer candidate-only and
continue separating generic hook-protocol evidence from deliberate workflow or
provider extension APIs before any promotion, suppression, or threshold
discussion.

## `MetzProject/RepeatedBranching`

Result: **Validated**. Medium-confidence design-pressure findings are
default-output eligible; lower-confidence generic-subject findings remain
available with `--project-analyzers`.

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

Generic-subject triage follow-up on 2026-06-30: `RepeatedBranching` now keeps
state-like and expression subjects at `confidence: medium` and
`severity: design pressure`, but reports generic subjects such as `action`,
`type`, `value`, and `key.to_s` with `confidence: low` and
`severity: context required`. The message and metadata still include
`decision_subject_kind`, reported contexts, and branch values, so the finding is
reviewable under `--project-analyzers` without treating a generic variable name
as default-output design pressure.

The calibration evidence runner now records breakdowns by rule, confidence,
severity, and analyzer-specific metadata such as `decision_subject_kind`. Use
those breakdowns in future reruns to confirm whether generic repeated-branch
subjects stay sparse and context-readable before changing thresholds.

A full repo-local `bin/check_project_analyzer_calibration --text --no-write`
run over the active fixture home on 2026-06-30 produced 25
`RepeatedBranching` findings and 55 offenses after default target discovery was
stabilized to skip nested-only targets such as the active `spree` checkout. The
subject-kind breakdown was 11 generic, 8 state-like, and 6 expression subjects;
the generic findings carried `context required` triage while state-like and
expression findings stayed medium-confidence design-pressure candidates.

Project-analyzer summaries now include per-rule breakdown metadata. Text
reports show a compact `mix:` hint when one rule has multiple severities or
metadata categories, so high-volume `DeepInheritanceTree` output can reveal the
broad-base/manual-review split without filtering root kinds.

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

Target-manifest follow-up on 2026-07-01: the repeatable calibration runner now
supports a calibration-only `--targets-file` option for nested or multi-root
fixtures. The focused `MetzProject/DeepInheritanceTree` pass used the active
repo-local targets plus nested Spree engine paths under
`tmp/project-analyzer-calibration/apps/spree`.

```bash
bundle exec ruby bin/check_project_analyzer_calibration --text \
  --targets-file tmp/project-analyzer-calibration/project_analyzer_targets.yml \
  --analyzer MetzProject/DeepInheritanceTree
```

| Project | Findings | Medium manual-review findings | Low broad-base findings |
| --- | ---: | ---: | ---: |
| `chatwoot/chatwoot` | 32 | 2 | 30 |
| `decidim/decidim` | 0 | 0 | 0 |
| `discourse/discourse` | 47 | 13 | 34 |
| `forem/forem` | 26 | 3 | 23 |
| `mastodon/mastodon` | 40 | 6 | 34 |
| `openfoodfoundation/openfoodnetwork` | 29 | 10 | 19 |
| `solidusio/solidus` | 0 | 0 | 0 |
| `spree/spree` nested engines | 35 | 15 | 20 |
| **Total** | **209** | **49** | **160** |

Aggregate root-kind breakdown for low-confidence broad roots:

| Root kind | Findings |
| --- | ---: |
| `abstract base` | 38 |
| `application job base` | 7 |
| `application service base` | 8 |
| `cli base` | 1 |
| `controller base` | 50 |
| `exception base` | 17 |
| `framework root` | 1 |
| `policy base` | 3 |
| `rails application base` | 15 |
| `serializer base` | 17 |
| `worker base` | 3 |

Policy decision:

- Do not add another DeepInheritanceTree filter or downranking rule from this
  pass. Existing broad-root categories are already low-confidence `broad base`
  findings, and the remaining medium-confidence findings are diverse
  application or domain extension families rather than one recurring obvious
  framework bucket.
- Keep DeepInheritanceTree **Validated opt-in** and not default-output
  eligible. The Spree nested-engine sample adds useful evidence, but it also
  confirms that manual reviewer intent is still necessary for interpreting
  domain inheritance families such as `Spree::Calculator`,
  `Spree::PaymentMethod`, `Reporting::ReportTemplate`, and
  `ActivityPub::Activity`.
- Revisit filtering only if a future manifest-backed run shows a recurring
  non-actionable root family across multiple targets.
