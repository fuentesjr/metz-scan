# frozen_string_literal: true

require "json"
require "stringio"

module MetzScan
  module Commands
    class Scan
      module Runner
        FORMATTER = "RuboCop::Formatter::MetzJsonFormatter"

        def self.invoke(paths)
          require "rubocop-metz"
          argv = ["--plugin", "rubocop-metz", "--format", FORMATTER, *paths]
          JSON.parse(capture_stdout(argv))
        end

        def self.capture_stdout(argv)
          buf = StringIO.new
          with_stdout(buf) { RuboCop::CLI.new.run(argv) }
          buf.string
        end

        def self.with_stdout(buf)
          original = $stdout
          $stdout = buf
          yield
        ensure
          $stdout = original
        end

        def self.exit_code_for(parsed)
          offenses?(parsed) ? 1 : 0
        end

        def self.offenses?(parsed)
          Array(parsed["files"]).any? { |f| Array(f["offenses"]).any? }
        end
      end
    end
  end
end
