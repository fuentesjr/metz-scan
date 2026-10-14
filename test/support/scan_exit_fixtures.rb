# frozen_string_literal: true

module MetzScan
  # Project sources and fault-injection shims shared by the `scan` exit-status specs.
  # Each shim makes one collaborator the CLI does not own (one RuboCop cop or one
  # project analyzer) raise, or breaks one step of the scan pipeline; it is loaded
  # into the subprocess with RUBYOPT. `%<lib>s` is replaced with this repo's lib dir.
  module ScanExitFixtures
    CLEAN_RUBY = "# frozen_string_literal: true\n"
    CLEAN_RUBY_FOR_STOCK_COPS = "# frozen_string_literal: true\n\nputs 'hi'\n"
    BROKEN_CONFIG = "AllCops: [unclosed\n"
    EXCLUDE_EVERYTHING_CONFIG = "AllCops:\n  Exclude:\n    - 'excluded/**/*'\n"
    SMALL_METHOD = <<~RUBY
      # frozen_string_literal: true

      # Sample.
      class Sample
        def call
          1
        end
      end
    RUBY
    # Six parameters trip Metz/MethodsTooManyParameters but not Metz/MethodsTooLong.
    TOO_MANY_PARAMETERS = <<~RUBY
      # frozen_string_literal: true
      class Sample
        def call(a, b, c, d, e, f)
          [a, b, c, d, e, f]
        end
      end
    RUBY

    COP_FAILURE_SHIM = <<~RUBY
      require "rubocop-metz"
      RuboCop::Cop::Metz::MethodsTooLong.prepend(Module.new do
        def on_def(_node) = raise("injected cop failure")
      end)
    RUBY

    ANALYZER_FAILURE_SHIM = <<~RUBY
      require "%<lib>s/metz_scan/analyzers/service_soup"
      MetzScan::Analyzers::ServiceSoup.prepend(Module.new do
        def call = raise("injected analyzer failure")
      end)
    RUBY

    PIPELINE_FAILURE_SHIM = <<~RUBY
      require "%<lib>s/metz_scan/commands/scan"
      MetzScan::Commands::Scan::ComplianceScorecard.singleton_class.prepend(Module.new do
        def add_to_summary!(_parsed) = raise("injected pipeline failure")
      end)
    RUBY

    # The suppression ledger runs inside metz-scan while the RuboCop step executes (default mode).
    LEDGER_FAILURE_SHIM = <<~RUBY
      require "%<lib>s/metz_scan/commands/scan"
      MetzScan::Commands::Scan::SuppressionLedger.singleton_class.prepend(Module.new do
        def apply(_report) = raise("injected ledger failure")
      end)
    RUBY

    # A view with no Metz offense, and Ruby that stock RuboCop would autocorrect (missing magic comment).
    CLEAN_ERB_VIEW = "<%= @user.name %>\n"
    AUTOCORRECTABLE_RUBY = "puts \"hi\"\n"

    # Renames a method in a cycle that never returns to the original name (call -> call2 -> call3 -> call2),
    # so RuboCop's autocorrect loop never converges and a dry run that fails to restore leaves a visible change.
    INFINITE_CORRECTION_SHIM = <<~RUBY
      require "rubocop-metz"
      RuboCop::Cop::Metz::MethodsTooLong.extend(RuboCop::Cop::AutoCorrector)
      RuboCop::Cop::Metz::MethodsTooLong.prepend(Module.new do
        NEXT_NAME = { "call" => "call2", "call2" => "call3", "call3" => "call2" }.freeze
        def on_def(node)
          renamed = NEXT_NAME[node.method_name.to_s] or return
          add_offense(node.loc.name, message: "cycling name") { |corrector| corrector.replace(node.loc.name, renamed) }
        end
      end)
    RUBY

    # Exceptions outside StandardError raised by metz-scan's own code.
    NOT_IMPLEMENTED_SHIM = <<~RUBY
      require "%<lib>s/metz_scan/commands/scan"
      MetzScan::Commands::Scan::ComplianceScorecard.singleton_class.prepend(Module.new do
        def add_to_summary!(_parsed) = raise(NotImplementedError, "injected not-implemented failure")
      end)
    RUBY

    STACK_OVERFLOW_SHIM = <<~RUBY
      require "%<lib>s/metz_scan/commands/scan"
      MetzScan::Commands::Scan::ComplianceScorecard.singleton_class.prepend(Module.new do
        def add_to_summary!(_parsed) = raise(SystemStackError, "injected stack failure")
      end)
    RUBY

    # Raised when --auto-fix starts, before it hands anything to RuboCop.
    AUTO_FIX_LOAD_ERROR_SHIM = <<~RUBY
      require "%<lib>s/metz_scan/commands/scan"
      MetzScan::Commands::Scan::AutoFix.prepend(Module.new do
        def run(_options) = raise(LoadError, "injected load failure")
      end)
    RUBY
  end
end
