# /goal backlog — top 5 bounded runs

Ranked by expected value against the tracker's rubygems.org exit criteria
(historical Path to rubygems.org criteria; current goal is in `.trk/STATE.md`).
Assumption: `/goal` accepts a
free-text goal statement; the DoD, proof, cap, and constraints are embedded in
each command so the executing agent carries them even if the harness doesn't.
OpenAI/Codex operators: there is no `/goal` command — paste the goal text
(everything after `/goal`) as the session prompt; the skills it names resolve
via `.agents/skills`. Re-derive this backlog from `.trk/STATE.md` Next
Queue when it drifts.

---

## 1. Dogfooding round on released 0.5.1 (exit criterion 2)

```
/goal Run the dogfood-round skill against the released 0.5.1 gems on 3-5 real codebases under tmp/project-analyzer-calibration/apps (must include one project without a .rubocop.yml). Judge output against the headline-UX rubric, write docs/dogfooding/2026-MM-DD-round-0.5.1.md in the 0.5.0 round's format, draft (do not file) issues for any headline defects, update PROJECT_TRACKER.md, and land via the land-slice skill. Do not modify target checkouts, do not fix defects in-round, do not publish anything. Cap: 80 turns. Proof: paste the per-target offense table, the verdict line against exit criterion 2, and the passing bin/check_ci_parity tail.
```

- **Definition of done:** notes file exists matching the 0.5.0 structure;
  binary verdict recorded; tracker snapshot/queue/checkpoint updated; slice
  committed with green `bin/check_ci_parity`.
- **Pasted proof:** per-target table (project, `.rubocop.yml`?, offenses,
  dominant cop), verdict sentence, `check_ci_parity: ok` tail.
- **Turn cap:** 80 (five scans at 21–47s each plus verification spot-checks).
- **Safety:** read-only on targets; released gems only (never the working
  tree); no issue filing without approval; no analyzer/threshold changes.
- **Expected value:** highest — this is the gating criterion for the public
  release; a pass unlocks criteria 3–4, a fail produces the next queue.

## 2. README quickstart verified end-to-end (exit criterion 3)

```
/goal Execute README.md exactly as written from a clean environment: the GitHub Packages install block (lines under "## Install"), then "## Quick Start", in a fresh temp consumer project with no repo-local bundler state. Record every step that fails, needs prior knowledge, or under-explains; fix those README steps minimally; land via the land-slice skill. Do not restructure the README beyond what the walkthrough demands; do not change CLI behavior. Cap: 30 turns. Proof: paste the transcript of each README command with its real output, and the passing readme freshness test names from the rake run.
```

- **Definition of done:** every README install/quickstart command runs as
  pasted from a clean consumer; defective steps fixed; freshness tests
  (`test/metz_scan/readme_workflow_docs_test.rb` etc.) green; slice landed.
- **Pasted proof:** command-by-command transcript; `bundle exec rake` summary
  line; `check_ci_parity: ok`.
- **Turn cap:** 30.
- **Safety:** README/doc edits only (plus freshness-test fixture updates if
  wording moved); no gemspec, no CLI code, no publishing; needs a
  `read:packages` token — stop if `gh auth status` lacks it.
- **Expected value:** high — criterion 3, and the quickstart is the first
  impression the public release trades on.

## 3. rubygems.org release preflight (exit criterion 4)

```
/goal Run the rubygems.org release preflight: gem build both gems, inspect metadata (description, license, homepage, links, changelog pointer) with gem specification, check both gem names are still unclaimed on rubygems.org via the public API, and record a go/no-go against all four Path-to-rubygems.org criteria in PROJECT_TRACKER.md. Fix only metadata defects found (gemspec/README/release-notes text). Do NOT publish, tag, or push gems anywhere. Cap: 25 turns. Proof: paste the gem build output for both gems, the metadata fields inspected, the rubygems.org API responses for both names, and the go/no-go paragraph.
```

- **Definition of done:** both gems build warning-free; metadata reads
  correctly; name-availability documented with dated evidence; go/no-go
  recorded in the tracker; any metadata fix landed via the `land-slice` skill.
- **Pasted proof:** `gem build` outputs, inspected fields, API status lines,
  go/no-go text.
- **Turn cap:** 25.
- **Safety:** no `gem push`, no tags, no releases — the publish itself is an
  explicit user decision (tracker rule); metadata edits re-run
  `release_metadata_test.rb`.
- **Expected value:** high once 1–2 pass — it is the last gate, and name
  availability decays with time.

## 4. Per-cop offense summary in text output (dogfooding quality note)

```
/goal Add an end-of-run summary to metz-scan's text output: total offenses, files inspected, and a per-cop offense rollup, rendered after the offense lines (project analyzers already get a summary header — mirror that precedent in lib/metz_scan/commands/scan/text_renderer.rb). Red-green: failing renderer test first. Update every exact-output fixture and README section the change breaks — do not loosen assertions. No new flags, no JSON/SARIF changes, no threshold or policy changes. Land via the land-slice skill. Cap: 50 turns. Proof: paste the new summary block from a real scan of the copied service_soup_app fixture, the failing-then-passing test output, and the check_ci_parity tail.
```

- **Definition of done:** summary renders on text scans; regression test
  written red-first; all exact fixtures + README freshness tests updated and
  green; slice landed.
- **Pasted proof:** rendered summary block, red test run then green suite
  summary, `check_ci_parity: ok`.
- **Turn cap:** 50 (the fixture cascade is the cost).
- **Safety:** text renderer only; expect and update the exact-fixture cluster
  (`test/fixtures/scan_text_renderer_project_analyzer/`, README status tests);
  no output-policy changes; no changes under `rubocop-metz/`.
- **Expected value:** high user-visible payoff — the 0.5.0 round's top quality
  note was a 1,441-line unranked offense wall with no rollup
  (`docs/dogfooding/2026-07-05-round-0.5.0.md`).

## 5. Clearer generic branch-subject wording in RepeatedBranching

```
/goal Improve MetzProject/RepeatedBranching finding wording for generic/bare branch subjects (the lobsters case: subject "k" rendered as "`k` (state branch subject) branches in 2 files"). When the subject is a bare short local/block variable, the message must lead with the shared branch-value set or enclosing methods instead of the bare name. Red-green from a fixture reproducing the lobsters shape. Do not change detection, thresholds, confidence, or triage policy — wording and metadata rendering only (lib/metz_scan/analyzers/repeated_branching/decision_subject.rb and the formatters). Update affected exact fixtures and README wording. Land via the land-slice skill. Cap: 45 turns. Proof: paste before/after finding text for the repro fixture and the green suite + check_ci_parity tails.
```

- **Definition of done:** repro fixture produces readable wording; detection
  behavior byte-identical for non-generic subjects (existing
  `repeated_branching_*_test.rb` files stay green unmodified except wording
  assertions); slice landed.
- **Pasted proof:** before/after finding text, suite summary,
  `check_ci_parity: ok`.
- **Turn cap:** 45.
- **Safety:** #28 is parked for *behavior* changes — this goal is wording only;
  if it can't be fixed without touching detection or thresholds, stop and
  report instead of proceeding.
- **Expected value:** medium-high — recurring "reads as noise" complaint about
  the tool's standout analyzer; wording is the sanctioned lever.

---

Not in this backlog on purpose: a legacy-adoption path (todo-baseline vs
top-offender ranking) is high value but needs a user design decision first;
propose options before turning it into a `/goal`.
