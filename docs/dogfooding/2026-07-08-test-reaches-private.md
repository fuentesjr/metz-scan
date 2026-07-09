# Per-cop calibration round — `Metz/TestReachesPrivate` (2026-07-08)

Focused dogfooding round for default-output eligibility of the first
testing-discipline cop (`docs/design/testing-cops.md` §8; `PROJECT_TRACKER.md`
Next Queue item 1). This is a **per-cop calibration**, not a release-quality
round, with two deliberate deviations from the `dogfood-round` rubric:

1. **Working-tree cop, not a released gem.** `Metz/TestReachesPrivate` is not in
   any published gem (it landed post-`v0.5.3` at `9875972`), so it is run from
   the working tree.
2. **Test-file FP judgment, not overall default output.** The cop is opt-in
   (`Enabled: false`) and scoped to test files, so it is force-enabled and run
   directly against real Minitest and RSpec suites.

## Method

Run from the repo (path-gem plugin resolves), against sparse/shallow clones of
each target's test/spec trees:

```
bundle exec rubocop --plugin rubocop-metz --force-default-config \
  --only Metz/TestReachesPrivate --format json <test-or-spec dirs>
```

Cop config confirmed via `--show-cops`: `Include: **/*_test.rb, **/test_*.rb,
**/*_spec.rb`; `AllowedMethods: define_method, remove_const, include, extend,
prepend, alias_method`; `AllowedReceivers: []`. Offense counts were
independently re-verified from the raw JSON.

## Targets and results

| Target | Framework | Test files | Offenses | Density /100 files | Files w/ offense | Distinct method names |
| --- | --- | --- | --- | --- | --- | --- |
| Rails (`activerecord`, `actionpack`, `activesupport`, `railties`, `actionview`, `activejob`, `activemodel` tests) | Minitest | ~1139 | **247** | **21.7** | 79 | 116 |
| Mastodon (`spec/`) | RSpec | ~1077 | **45** | **4.2** | 6 | 9 |
| Discourse (`spec/`) | RSpec | ~1597 | **140** | **8.8** | 37 | 47 |

No parse failures, no unreadable files, no stderr noise beyond RuboCop's
standard "new cops unconfigured" advisory (unrelated to this cop). Exit 1 in all
three ("findings reported", not a crash).

## Accuracy (false-positive rate): low

Spot-checked the method-name histograms and ~60 sampled offenses against source.
The pattern is overwhelmingly a genuine **test invoking a private method on its
subject**:

- Rails: `@connection.send(:type_map)` (16×), `send(:normalize_key)` (16×),
  `@connection.send(:with_raw_connection)`, `connection_pool.send(:new_connection)`,
  `send(:translate_exception_class)`, `send(:rename_column_for_alter)`,
  `send(:supports_rename_column?)` — all private adapter internals.
- Mastodon: `subject.send(:must_clauses)` / `:must_not_clauses` /
  `:filter_clauses` (a private query transformer's internals, 10× each in one
  spec), `subject.send(:http_client)`, `described_class.new.send(:after_update_redirect_path)`.
- Discourse: `creator.send(:add_remote_uploads_to_archive)`,
  `creator.send(:get_parameterized_title)`, `creator.send(:notify_user)`,
  `instance.send(:append_content_localization_param)`, `cpp.send(:post_process_videos)`.

These are true positives by the cop's principle. No systematic false-positive
category surfaced: the literal-arg + `dsym`/`dstr` exclusion keeps
dynamic-dispatch loops out, `public_send` is not flagged, and operator symbols
are skipped. The one non-target-shaped call class is metaprogramming that slips
past the current `AllowedMethods` (see below), which is a config nit, not a
detection defect.

## Eligibility verdict: NOT default-output eligible — keep opt-in

The bar (spec §8) is **sparse and reviewable**. The cop is accurate, but its
signal is dense on real code — testing private methods via `send` is idiomatic
and widespread, peaking at **21.7 findings per 100 test files** on Rails-style
Minitest. Promoting it to default output would flood a first scan with hundreds
of accurate-but-opinionated findings and drown the higher-signal design cops
(`MethodsTooLong`, `DemeterTrainWreck`). That is a bad default even though each
finding is correct.

`Metz/TestReachesPrivate` stays `Enabled: false` (opt-in). This **validates the
slice-1 decision** to ship it opt-in behind the `Metz/Test*` gate: teams who
want the discipline enable it; default output stays focused. Do not promote.

## Findings-quality notes (queue candidates, non-blocking)

- **`remove_method` (Discourse, 2×)** is a metaprogramming sibling of the
  already-allowed `define_method` / `remove_const` and is a candidate for the
  default `AllowedMethods`. Trivial volume; optional, and only worth doing
  alongside other detection work — not on its own.
- Density, not accuracy, is the gating factor here. If a future "legacy
  adoption" mode is ever wanted (e.g. a per-cop budget or a `--new` diff-scoped
  run), this cop is the archetype that would benefit — noted, not queued.

## Verdict against the eligibility question

**Keep opt-in.** No promotion escalation is requested (the recommendation is to
*not* promote). No code changed this round (judge-only). The cop is confirmed a
high-quality opt-in member of the testing-discipline family.
