# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      # Emits a one-line stderr note when a non-empty `.rubocop` file or
      # `RUBOCOP_OPTS` environment variable is present, since `metz-scan`
      # invokes RuboCop::Runner directly and ignores RuboCop CLI option files.
      module IgnoredCliOptionsNote
        module_function

        def print_note(stderr)
          sources = active_sources
          stderr.puts(note(sources)) unless sources.empty?
        end

        def active_sources
          sources = []
          sources << ".rubocop" if dot_rubocop_active?
          sources << "RUBOCOP_OPTS" unless ENV["RUBOCOP_OPTS"].to_s.strip.empty?
          sources
        end

        def dot_rubocop_active?
          File.file?(".rubocop") && !File.binread(".rubocop").strip.empty?
        end

        def note(sources)
          "metz-scan: note: ignoring RuboCop CLI options from #{sources.join(' and ')}; " \
            "configure settings in .rubocop.yml instead"
        end
      end
    end
  end
end
