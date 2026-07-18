---
name: dogfood-round
description: "Run a qualitative dogfooding round of released metz-scan gems against real external codebases and judge the output against the headline-UX rubric (rubygems.org exit criterion 2). Use when the tracker queue calls for a dogfooding round, after a release carrying UX fixes, or when the user asks to evaluate scan output quality on real projects."
---

# Dogfooding round

This is the project's direction engine (`.trk/STATE.md` Current
Direction): install the *released* gems the way a user would, run them on real
codebases, and judge whether the output would embarrass the tool. The
2026-07-05 round (`docs/dogfooding/2026-07-05-round-0.5.0.md`) is the canonical
example — match its method and its notes format.

## Scope rules

- Judge output only. Defects found become filed issues and queue items — do
  not fix them mid-round.
- Target checkouts are read, never modified.
- Use the released GitHub Packages gems, not the working tree. The point is to
  see exactly what a user sees.

## Setup

1. Create a clean Bundler consumer project in a temp dir following the README
   install path (GitHub Packages source block, `gem "metz-scan", "~> X.Y"`).
   Requires a `read:packages` token per README "Install".
2. Targets live under `tmp/project-analyzer-calibration/apps/` (the active
   calibration-fixture home per `AGENTS.md`). The 0.5.0 round used: lobsters,
   huginn (both without `.rubocop.yml`, filling the small-project slot), maybe,
   redmine, rubygems.org. Use 3–5 targets, at least one without a
   `.rubocop.yml`.
3. Run from each target root without editing its Gemfile:
   `BUNDLE_GEMFILE=<consumer>/Gemfile bundle exec metz-scan scan app lib`
   (default mode first; add `--project-analyzers` for a second read).

## Rubric — two classes of finding

**Headline-UX defects (block the exit criterion):** wrong default output,
misleading or duplicated findings, broken quickstart. Examples that qualified:
default scan ignoring project `AllCops: Exclude` (#33), collaborator cop
counting rescue classes/own constants/stdlib and mislabeling methods (#34).

**Findings-quality nits (queue candidates, never blockers):** e.g. no per-cop
offense rollup at end of run, no legacy-adoption path, cryptic generic branch
subjects like lobsters' `k`. Record them; do not act on them in-round.

For every candidate defect: verify against the target's source before calling
it a defect, and build a minimal repro against the released gems (the #33 repro
pattern: a project whose config excludes a templated `.rb` file, default vs
`--all-cops` disagreement). An unverified impression is a note, not a defect.

## Judging guide

- Per project record: `.rubocop.yml` present?, total offenses, dominant cop,
  scan wall time, any stderr.
- Spot-check the dominant cop's top offenders against the source: would a
  reviewer agree these files are the problem files?
- Read every project-analyzer finding (there are few) and label it: earned its
  space / needs context / misleading.
- Silence is signal too: note validated analyzers producing zero findings
  (ServiceSoup was silent on all five 0.5.0 targets — recorded, not "fixed").

## Output

1. Write `docs/dogfooding/YYYY-MM-DD-round-X.Y.Z.md` matching the 0.5.0 file's
   structure: setup, target table, headline-UX defects (with repro), quality
   notes, findings that earned their space, verdict against exit criterion 2.
2. Verdict is binary: **passed** (no new headline-UX-class defects) or **not
   passed** (list them). Quality nits do not fail the round.
3. Draft GitHub issues for each headline defect — filing needs user approval
   (precedent: #34 draft waited for approval).
4. Update `.trk/` via `trk` (goal/next/backlog/log as needed): dogfooding
   state and queue rebuilt around any defects found. Commit notes + tracker
   together via the `land-slice` skill.
