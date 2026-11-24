# frozen_string_literal: true

require "rubocop"
require "stringio"

require "metz_scan/commands/scan/execution_config_store"
require "metz_scan/commands/scan/project_config_scope"

module MetzScan
  module Commands
    class Scan
      # Invokes RuboCop::Runner directly so RuboCop::Options#parse, `.rubocop`,
      # and `RUBOCOP_OPTS` are never consulted in any scan mode.
      module RuboCopInvocation
        RUBOCOP_STATE_TARGETS = {
          RuboCop::ConfigLoader => %i[
            debug ignore_parent_exclusion ignore_unrecognized_cops disable_pending_cops
            enable_pending_cops enabled_by_default disabled_by_default preview
          ].freeze,
          RuboCop::PendingCopsReporter => %i[disable_pending_cops enable_pending_cops].freeze
        }.freeze

        module_function

        def scan(paths, all_cops:, store: nil)
          run(paths, options: scan_options(all_cops), config_store: config_store(all_cops, store), all_cops: all_cops)
        end

        def auto_fix(paths, options:, report_path:, store: nil)
          all_cops = options.all_cops
          store_arg = config_store(all_cops, store, honor_suppressions: !all_cops)
          run(paths, options: auto_fix_options(options, report_path), config_store: store_arg, all_cops: all_cops)
        end

        def run(paths, options:, config_store:, all_cops: false)
          Runner.require_metz_plugin
          ProjectConfigScope.ensure_metz_defaults_loaded
          capture_runner { run_in_process(paths, options, config_store, all_cops) }
        end

        def capture_runner(&)
          out = StringIO.new
          err = StringIO.new
          status = Runner.with_redirected_io(out, err, &)
          Runner::Result.new(stdout: out.string, stderr: err.string, status: status)
        end

        def run_in_process(paths, options, config_store, all_cops)
          rescue_runner_errors do
            with_isolated_rubocop_state(options[:disable_pending_cops]) do
              run_configured(paths, options, config_store, all_cops)
            end
          end
        end

        def rescue_runner_errors
          yield
        rescue StandardError, SyntaxError, LoadError => e
          warn(e.message)
          RuboCop::CLI::STATUS_ERROR
        end

        def run_configured(paths, options, config_store, all_cops)
          configure_cache_root(config_store)
          warn_pending_cops(config_store) if all_cops && !options[:disable_pending_cops]
          execute_runner(paths, options, config_store)
        end

        def execute_runner(paths, options, config_store)
          runner = RuboCop::Runner.new(options, config_store)
          all_passed = runner.run(paths)
          report_problems(runner)
          runner_status(runner, all_passed)
        end

        def report_problems(runner)
          runner.warnings.each { |warning| warn(warning) }
          runner.errors.each { |error| warn(error) }
        end

        def runner_status(runner, all_passed)
          return RuboCop::CLI::STATUS_INTERRUPTED if runner.aborting?

          all_passed && runner.errors.empty? ? RuboCop::CLI::STATUS_SUCCESS : RuboCop::CLI::STATUS_OFFENSES
        end

        def configure_cache_root(config_store)
          TargetFileDiscovery.reset_cwd_caches
          RuboCop::ResultCache.reset_config_cache
          RuboCop::ConfigLoader.cache_root = RuboCop::ResultCache.cache_root(config_store, nil)
        end

        def warn_pending_cops(config_store) = RuboCop::PendingCopsReporter.warn_if_needed(config_store.for_pwd)

        def with_isolated_rubocop_state(disable_pending)
          snapshot = snapshot_rubocop_state
          reset_rubocop_state(disable_pending)
          yield
        ensure
          restore_rubocop_state(snapshot) if snapshot
        end

        def snapshot_rubocop_state
          RUBOCOP_STATE_TARGETS.to_h { |target, attrs| [target, attrs.to_h { |a| [a, target.public_send(a)] }] }
        end

        def reset_rubocop_state(disable_pending)
          RUBOCOP_STATE_TARGETS.each { |target, attrs| attrs.each { |attr| target.public_send(:"#{attr}=", nil) } }
          RUBOCOP_STATE_TARGETS.each_key { |target| target.disable_pending_cops = disable_pending }
        end

        def restore_rubocop_state(snapshot)
          snapshot.each { |target, values| values.each { |attr, val| target.public_send(:"#{attr}=", val) } }
        end

        def config_store(all_cops, store, honor_suppressions: false)
          return RuboCop::ConfigStore.new if all_cops

          ExecutionConfigStore.new(store || ProjectConfigScope.store, honor_suppressions: honor_suppressions)
        end

        def scan_options(all_cops)
          base = { format: Runner::FORMATTER, formatters: [[Runner::FORMATTER]] }
          return base if all_cops

          base.merge(only: ["Lint/Syntax", "Metz"], display_suppressed: true)
        end

        def auto_fix_options(options, report_path)
          base = autocorrect_options(options.unsafe).merge(
            format: "progress", formatters: [["json", report_path], ["progress"]], out: report_path
          )
          return base if options.all_cops

          base.merge(only: ["Lint/Syntax", "Metz"], disable_pending_cops: true)
        end

        def autocorrect_options(unsafe) = { autocorrect: true, (unsafe ? :autocorrect_all : :safe_autocorrect) => true }
      end
    end
  end
end
