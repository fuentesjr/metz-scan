# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      # Decides whether an in-process RuboCop run failed and describes why. RuboCop exits 1
      # for offenses and for recorded errors alike, so the error lines it warns tell them apart:
      # a cop crash or an autocorrect that never converges. Other stderr output, such as the
      # pending-cops notice, is not an error. Matching stops at an ANSI escape, so color is harmless.
      module RubocopFailure
        RECORDED_ERROR = /(?:An error occurred while|Infinite loop detected in) [^\e\n]+/
        # RuboCop prints this notice before any error raised while loading nested configs or files.
        PENDING_COPS_NOTICE = %r{\A.*?docs\.rubocop\.org/rubocop/versioning\.html[^\n]*\n}m

        module_function

        def failed?(result)
          ![0, 1].include?(result.status) || recorded_errors(result).any?
        end

        def message(result)
          errors = recorded_errors(result)
          errors.empty? ? output_message(result) : errors.join("; ")
        end

        def recorded_errors(result)
          result.stderr.scan(RECORDED_ERROR).uniq
        end

        def output_message(result)
          detail = Runner.concise_message(result.stderr.sub(PENDING_COPS_NOTICE, ""))
          detail = Runner.concise_message(result.stdout) if detail.empty?
          detail.empty? ? "RuboCop exited with status #{result.status} without JSON output" : detail
        end
      end
    end
  end
end
