# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      # Every way `scan` can fail to check the code ends here: the cause goes to stderr, stdout
      # gets no report, and the exit status is 2, even when findings were also found.
      class CheckFailure
        EXIT_STATUS = 2
        # Every exception except SystemExit and signals (Interrupt), which must pass through.
        INTERNAL_ERRORS = [StandardError, ScriptError, SystemStackError, NoMemoryError, SecurityError].freeze

        class NoFilesScanned < StandardError
          def initialize(paths)
            super("no files scanned in #{paths.join(', ')}")
          end
        end

        def initialize(stderr)
          @stderr = stderr
        end

        def report(error)
          stderr.puts "metz-scan scan: #{description(error)}"
          EXIT_STATUS
        end

        private

        attr_reader :stderr

        def description(error)
          case error
          when Runner::Error then "RuboCop failed: #{error.message}"
          when NoFilesScanned then error.message
          else ["internal error: #{error.class}: #{error.message}", *error.backtrace].join("\n")
          end
        end
      end
    end
  end
end
