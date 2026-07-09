# Per-cop calibration round — `Metz/TestAssertsOnInternals` (2026-07-09)

Focused dogfooding round for default-output eligibility of the second
testing-discipline cop (`docs/design/testing-cops.md` §8). Same method and
deviations as the `TestReachesPrivate` round
(`docs/dogfooding/2026-07-08-test-reaches-private.md`): working-tree cop (not a
released gem), force-enabled and run directly against real test suites, judged
on test-file findings density and false-positive rate.

## Method

```
bundle exec rubocop --plugin rubocop-metz --force-default-config \
  --only Metz/TestAssertsOnInternals --format json <test-or-spec dirs>
```

Run against the same sparse/shallow clones used for the `TestReachesPrivate`
round (Rails Minitest test trees; Mastodon and Discourse `spec/`). Offense counts
taken from the raw JSON; densities use the same matched-test-file denominators as
the prior round (Rails ~1139, Mastodon ~1077, Discourse ~1597).

## Targets and results

| Target | Framework | Offenses | Density /100 test files | Files w/ offense | `instance_variable_get` | `instance_variable_set` | `assigns` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Rails | Minitest | **364** | **~32.0** | 71 | 263 | 101 | 0 |
| Discourse | RSpec | **53** | ~3.3 | 21 | 33 | 20 | 0 |
| Mastodon | RSpec | **4** | ~0.4 | 3 | 2 | 2 | 0 |

No parse failures; no stderr noise beyond RuboCop's standard "new cops
unconfigured" advisory. No `assigns(:x)` offenses surfaced — modern suites use
request specs and Rails moved controller-test `assigns` to a separate gem, so the
form is rare in these targets. Detection is correct; the sample simply has few
instances.

## Accuracy (false-positive rate): low

Spot-checked Rails offenses against source. Every sampled offense is a genuine
reach into / assertion on object internal state:

- `@connection.instance_variable_set(:@last_activity, ...)` /
  `assert_nil @connection.instance_variable_get(:@last_activity)`
  (activerecord adapter_test)
- `decoded.instance_variable_set(:@ar_pg_bytea_decoded, true)` (postgresql bytea_test)

`instance_variable_get`/`_set` are unambiguous — they exist only to bypass the
public interface and touch internal representation, so the true-positive rate is
high by construction. Bare `@ivar` reads/writes are correctly not flagged, and
`assigns` requires a receiverless literal call, so no false-positive category
surfaced.

## Eligibility verdict: NOT default-output eligible — stays opt-in

The bar (spec §8) is **sparse and reviewable**. The cop is accurate, but its
signal is dense on real code — reaching into internal state via ivar accessors is
pervasive in Rails-style Minitest suites, peaking at **~32 findings per 100 test
files** on Rails (even denser than `TestReachesPrivate`'s 21.7). Promoting it to
default output would flood a first scan and drown the design cops.

`Metz/TestAssertsOnInternals` stays `Enabled: false` (opt-in), consistent with
`TestReachesPrivate`. Do not promote.

## Findings-quality notes (non-blocking)

- The two RSpec targets are far sparser (0.4 / 3.3 per 100) than Rails Minitest
  (32). The density is dominated by Rails core's heavy use of ivar-level
  assertions on adapters/connections; it is not a per-framework detection
  artifact.
- Like `TestReachesPrivate`, this cop is a candidate archetype for a future
  "legacy adoption" / diff-scoped mode if one is ever built — noted, not queued.

## Verdict against the eligibility question

**Keep opt-in.** No promotion escalation requested (recommendation is to *not*
promote). No code changed this round (judge-only). Both shipped testing cops are
confirmed high-quality opt-in members of the family.
