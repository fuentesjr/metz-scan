# Per-cop calibration round — `Metz/TestStubsSubject` (2026-07-09)

Focused dogfooding round for default-output eligibility of the third
testing-discipline cop (`docs/design/testing-cops.md` §8). Same method as the
`TestReachesPrivate` (`docs/dogfooding/2026-07-08-test-reaches-private.md`) and
`TestAssertsOnInternals` (`docs/dogfooding/2026-07-09-test-asserts-on-internals.md`)
rounds: working-tree cop (not a released gem), force-enabled and run directly
against real RSpec suites, judged on findings density and false-positive rate.

**RSpec-only cop** — no Minitest run (the cop has no Minitest detection by
design; only RSpec exposes a detectable `subject` token). Targets are RSpec
suites. This round used **four**: Mastodon and Discourse (the two rounds-standard
targets) plus Forem and OpenFoodNetwork, added because the first two targets
looked deceptively sparse and a broader RSpec base was needed before judging
default-output eligibility — that expansion changed the verdict.

## Method

```
# From a working dir OUTSIDE the repo (see note), with an explicit config:
#   plugins: [rubocop-metz]
#   AllCops: { TargetRubyVersion: 3.4, DisabledByDefault: true, NewCops: disable }
#   Metz/TestStubsSubject: { Enabled: true, Include: ['**/*_spec.rb'] }
BUNDLE_GEMFILE=<repo>/Gemfile bundle exec rubocop \
  --only Metz/TestStubsSubject --format json <target-spec-dir>
```

Two method corrections vs. a naive run, both material to the counts and worth
reusing in future per-cop rounds:

- **Do not run against a checkout under the repo's `tmp/`.** RuboCop's default
  config `Exclude: tmp/**/*` silently drops every target file (offense/target
  counts come back ~0). The spec trees were copied outside the repo before
  scanning.
- **Do not use `--force-default-config`.** It parses with the low default
  `TargetRubyVersion` (2.7), so modern spec syntax raises `Lint/Syntax` and
  RuboCop then **skips those files entirely** — the cop never runs on them. A
  first, biased run this way silently skipped ~11–12% of files. The corrected run
  pins `TargetRubyVersion: 3.4` via an explicit config, yielding **zero**
  `Lint/Syntax` and full coverage. (Same `TargetRubyVersion`-loss class as
  dogfood defect C, `4b64a93`.)

Denominators use matched `_spec.rb` file counts.

## Targets and results

| Target | `_spec.rb` files | TSS offenses | Density /100 spec files | Files w/ offense | `Lint/Syntax` |
| --- | --- | --- | --- | --- | --- |
| Mastodon | 1075 | 3 | ~0.28 | 3 | 0 |
| Discourse | 1565 | 0 | 0.0 | 0 | 0 |
| Forem | 1210 | 4 | ~0.33 | 3 | 0 |
| **OpenFoodNetwork** | 641 | **76** | **~11.9** | 16 | 0 |

No parse failures after the `TargetRubyVersion` fix; no stderr noise beyond
RuboCop's standard "new cops unconfigured" advisory.

## Accuracy (false-positive rate): zero observed across all four targets

Offenses were spot-checked against source on every target. Every sampled offense
stubs the **object under test**, not a collaborator:

- **Mastodon** — `allow(subject).to receive(:redis_info)` in two dimension specs
  (both carry a hand-written `# rubocop:disable RSpec/SubjectStub`), and
  `allow(subject).to receive(:push_notification_json)` in a worker spec whose true
  collaborators (`OpenSSL::PKey::EC`, `Random`) are stubbed via named receivers
  and correctly **not** flagged.
- **Forem** — `allow(subject).to receive(:published?)` (again with an explicit
  `# rubocop:disable RSpec/SubjectStub`), and stubs on the named subject
  `feed_config`.
- **OpenFoodNetwork** — `subject { described_class.new(v) }` then
  `allow(subject).to receive(:value_scaled?)` / `:option_value_value_unit` before
  asserting on `subject.name`; report specs with `subject { described_class.new(user, params) }`
  then `allow(subject).to receive(:columns/:query_result/:rules/:custom_headers)`.
  The subject-under-test is stubbed pervasively — genuine positives, just many of
  them in a legacy/report-heavy testing style.

No false positives surfaced. Multiple offenses across two targets already carry a
hand-written `# rubocop:disable RSpec/SubjectStub`, independent in-repo human
confirmation of the exact smell — `Metz/TestStubsSubject` reproduces
rubocop-rspec's already-accepted `RSpec/SubjectStub` rule.

## Eligibility verdict: NOT default-output eligible — stays opt-in

The bar (spec §8) is **sparse and reviewable across real suites**, not just the
clean ones. The cop is accurate everywhere, but its **density is
suite-dependent**: near-zero on three modern suites (0.0–0.33 per 100) yet
**~11.9 per 100 on OpenFoodNetwork** — comparable to the dense end of the two
prior testing cops. A first-time default scan of a legacy or report-heavy RSpec
suite would surface dozens of these (OFN: 76) and drown the design cops, exactly
the flood that keeps `TestReachesPrivate` and `TestAssertsOnInternals` opt-in.

Had this round stopped at Mastodon + Discourse (n=3, the sparse-looking pair) it
would have wrongly read as a default-output candidate. The fourth target
corrected that: the sparse signal does not generalize. `Metz/TestStubsSubject`
stays `Enabled: false` (opt-in), consistent with the other two testing cops — all
three are accurate, all three stay opt-in. Do not promote.

## Findings-quality notes (non-blocking)

- Density is bimodal, not uniform: three suites near zero, one an order of
  magnitude denser. The driver is testing *style* (OFN's report/service specs
  stub the subject's own methods to isolate formatting logic), not a per-suite
  detection artifact — the cop discriminated collaborators correctly everywhere.
- Like the other two, this cop is a candidate archetype for a future
  "legacy adoption" / diff-scoped mode if one is ever built — noted, not queued.

## Verdict against the eligibility question

**Keep opt-in.** No promotion. No code changed this round (judge-only). All three
shipped testing cops are now confirmed high-quality opt-in members of the family.
