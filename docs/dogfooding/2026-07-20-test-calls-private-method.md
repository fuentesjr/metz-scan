# Per-cop calibration round — `MetzProject/TestCallsPrivateMethod` (2026-07-20)

Focused dogfooding round for the Tier 2 index-backed testing analyzer from
`docs/design/testing-cops.md` §8. The analyzer landed after `v0.5.3`, so this
round uses the working-tree wrapper with the optional Rubydex group. It does not
represent a released-gem smoke test.

## Method

The harness instantiated `MetzProject/TestCallsPrivateMethod` with
`ProjectIndex.build` and `BUNDLE_WITH=rubydex`. The index backend reported
`rubydex` for every counted target. The scan included `app`, `lib`, and `spec` for Mastodon, Forem, and
OpenFoodNetwork. Rails Action Pack, Active Record, and Active Support runs used
their `lib` and `test` directories. Test-file counts use the analyzer's
`*_test.rb`, `test_*.rb`, and `*_spec.rb` patterns.

The Mastodon run also used the user-facing command:

```text
BUNDLE_GEMFILE=<repo>/Gemfile BUNDLE_WITH=rubydex bundle exec ruby <repo>/bin/metz-scan \
  scan . --project-analyzers --format json
```

The command returned exit status 1 because it reported findings, with no
stderr. Direct analyzer runs avoided the stock RuboCop pass while preserving the
wrapper's Rubydex index and analyzer behavior.

## Targets and results

| Target | Framework | `.rubocop.yml` | Test files | Findings | Files with findings | Density /100 files | Wall time |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Mastodon | RSpec | yes | 1,075 | 13 | 3 | 1.2 | 334s CLI run |
| OpenFoodNetwork | RSpec | yes | 643 | 22 | 3 | 3.4 | 116s direct run |
| Forem | RSpec | yes | 1,210 | 60 | 5 | 5.0 | 298s direct run |
| Rails Action Pack | Minitest | yes | 196 | 9 | 1 | 4.6 | 48s direct run |
| Rails Active Record | Minitest | yes | 748 | 11 | 2 | 1.5 | 292s direct run |
| Rails Active Support | Minitest | yes | 226 | 0 | 0 | 0.0 | 46s direct run |
| Lobsters | no matching Ruby test files | no | 0 | 0 | 0 | n/a | 3s control |

The Lobsters control used `check_rubydex_drift --json .`; it confirmed the
no-test-file case but did not contribute a density denominator. Discourse and a
larger selected Rails run exceeded their bounded review windows, so they are
not included in the counts.

## Accuracy

Spot checks across the dominant findings matched the indexed visibility and the
source call sites:

- Mastodon tests call `TranslateStatusService#source_texts`,
  `#wrap_emoji_shortcodes`, and `#unwrap_emoji_shortcodes` with `send`; the
  production methods follow `private` in `app/services/translate_status_service.rb`.
- Mastodon's request spec calls `Request#http_client`; `app/lib/request.rb`
  marks the method private.
- OpenFoodNetwork's product renderer spec calls `ProductsRenderer#products`
  with `__send__`; the production method follows `private` in
  `app/services/products_renderer.rb`.
- OpenFoodNetwork's enterprise-fee specs call
  `EnterpriseFeeCalculator#per_item_enterprise_fees_with_exchange_details`;
  the production method is in a private section.
- Forem's feed and welcome-notification specs call private methods such as
  `Articles::Feeds::Custom#calculate_dynamic_shuffle_count` and
  `Broadcasts::WelcomeNotification::Generator#send_discuss_and_ask_notification`.
- Rails Action Pack's Minitest suite calls
  `ActionDispatch::DebugView#translate_path_for_editor` nine times; the
  production method follows `private` in `debug_view.rb`.
- Rails Active Record's Minitest suite calls private
  `ActiveRecord::Migrator#generate_migrator_advisory_lock_id` and singleton
  `ActiveRecord::QueryLogs#escape_sql_comment`; both production methods are
  inside private sections.

No false-positive category appeared in these checks. Active Support produced no
findings, which is a useful silence result rather than a detection defect.

## Eligibility verdict: keep candidate-only

The signal is accurate and readable across both RSpec and Minitest. The RSpec
results reach 60 findings on Forem, which is a sizeable first-scan review queue
even though its file density is 5.0%. Promoting the analyzer to default output
would be premature.

`MetzProject/TestCallsPrivateMethod` remains candidate-only and not
default-output eligible. No threshold change, promotion, suppression, or
runtime coordination with `Metz/TestReachesPrivate` is requested.

## Verdict against the eligibility question

**Keep candidate-only.** Both framework families produce high-signal findings,
but the suite-dependent review volume does not support default output.
