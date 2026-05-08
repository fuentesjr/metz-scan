# frozen_string_literal: true

require "rubocop"
require "rubocop-ast"

module Metz
  module Test
    module CopHelper
      ANNOTATION_PATTERN = /\A\s*((?<!\\)\^+|\^\{\}) ?/
      ABBREV = "[...]\n"

      class AnnotatedSource
        def self.parse(annotated_source)
          source = []
          annotations = []

          annotated_source.each_line do |line|
            if ANNOTATION_PATTERN.match?(line)
              annotations << [source.size, line]
            else
              source << line
            end
          end
          annotations.each { |entry| entry[0] = 1 } if source.empty?
          new(source, annotations)
        end

        attr_reader :lines, :annotations

        def initialize(lines, annotations)
          @lines = lines.freeze
          @annotations = annotations.sort.freeze
        end

        def ==(other)
          other.is_a?(self.class) && other.lines == lines && match_annotations?(other)
        end

        def match_annotations?(other)
          annotations.zip(other.annotations) do |(_, actual), (_, expected)|
            next unless expected&.end_with?(ABBREV)
            next unless actual.start_with?(expected[0...-ABBREV.length])

            expected.replace(actual)
          end
          annotations == other.annotations
        end

        def to_s
          rebuilt = lines.dup
          annotations.reverse_each { |line, text| rebuilt.insert(line, text) }
          rebuilt.join
        end

        def plain_source
          lines.join
        end

        def with_offense_annotations(offenses)
          rendered = offenses.map do |offense|
            indent = " " * offense.column
            carets = offense.column_length.zero? ? "^{}" : "^" * offense.column_length
            [offense.line, "#{indent}#{carets} #{offense.message}\n"]
          end
          self.class.new(lines, rendered)
        end
      end

      module Impl
        DEFAULT_RUBY_VERSION = 3.3

        def cop
          @cop ||= cop_class.new(metz_rubocop_config)
        end

        def cop_config
          {}
        end

        def metz_rubocop_config
          @metz_rubocop_config ||= begin
            cop_name = cop_class.cop_name
            user = { "Enabled" => true }.merge(cop_config)
            RuboCop::Config.new(cop_name => user)
          end
        end

        def metz_ruby_version
          DEFAULT_RUBY_VERSION
        end

        def metz_assert_offense(source, file, **replacements)
          expected = metz_parse_annotations(source, **replacements)
          plain = expected.plain_source
          offenses = metz_inspect(plain, file)
          actual = expected.with_offense_annotations(offenses)

          actual.match_annotations?(expected)

          assert_equal(
            expected.to_s,
            actual.to_s,
            "Expected offense annotations did not match the actual offenses produced by " \
            "#{cop_class.cop_name}."
          )

          offenses.each(&method(:metz_validate_offense_range))
          @metz_offenses = offenses
        end

        def metz_refute_offense(source, file)
          offenses = metz_inspect(source, file)
          assert_empty(
            offenses,
            "Expected no offenses, got #{offenses.size}: " \
            "#{offenses.map(&:message).join('; ')}"
          )
          @metz_offenses = offenses
        end

        def metz_assert_correction(correction, loop:)
          raise "`assert_correction` must follow `assert_offense`" unless @metz_processed_source

          source = @metz_processed_source.raw_source
          raise "Use `refute_correction` if no corrections are expected" if correction == source

          iteration = 0
          new_source = loop do
            iteration += 1
            corrected = @metz_last_corrector.rewrite
            break corrected unless loop
            break corrected if @metz_last_corrector.empty?

            if iteration > RuboCop::Runner::MAX_ITERATIONS
              raise RuboCop::Runner::InfiniteCorrectionLoop.new(
                @metz_processed_source.path, [@metz_offenses]
              )
            end

            @metz_processed_source = metz_parse_source(corrected, @metz_processed_source.path)
            metz_run_cop(@metz_processed_source)
          end

          assert(new_source != source, "Expected correction but no corrections were made")
          assert_equal(correction, new_source)
          assert(@metz_processed_source.valid_syntax?, "Expected correction to be valid syntax")
        end

        def metz_inspect(source, file)
          @metz_processed_source = metz_parse_source(source, file)
          unless @metz_processed_source.valid_syntax?
            diagnostics = @metz_processed_source.diagnostics.map(&:render).join("\n")
            raise "Error parsing example code: #{diagnostics}"
          end
          metz_run_cop(@metz_processed_source)
        end

        def metz_run_cop(processed_source)
          cop.instance_variable_get(:@options)[:autocorrect] = true
          team = RuboCop::Cop::Team.new([cop], metz_rubocop_config, raise_error: true)
          report = team.investigate(processed_source)
          @metz_last_corrector = report.correctors.first ||
                                 RuboCop::Cop::Corrector.new(processed_source)
          @metz_offenses = report.offenses.reject(&:disabled?)
        end

        def metz_parse_source(source, file = nil)
          processed = RuboCop::ProcessedSource.new(source, metz_ruby_version, file)
          processed.config = metz_rubocop_config
          processed.registry = RuboCop::Cop::Registry.new([cop_class])
          processed
        end

        def metz_format_offense(source, **replacements)
          replacements.each do |keyword, raw|
            value = raw.to_s
            source = source
                     .gsub("%{#{keyword}}", value)
                     .gsub("^{#{keyword}}", "^" * value.size)
                     .gsub("_{#{keyword}}", " " * value.size)
          end
          source
        end

        def metz_parse_annotations(source, **replacements)
          source = metz_format_offense(source, **replacements)
          annotations = AnnotatedSource.parse(source)
          return annotations unless annotations.plain_source == source

          raise "Use `refute_offense` to assert that no offenses are found"
        end

        def metz_validate_offense_range(offense)
          offense.location.source_line
        rescue StandardError => e
          raise "Misconstructed offense range for #{cop_class.cop_name}: #{e.message}"
        end
      end

      def self.included(base)
        base.include(Impl)
        base.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          def assert_offense(source, file: nil, **replacements)
            metz_assert_offense(source, file, **replacements)
          end

          def refute_offense(source, file: nil)
            metz_refute_offense(source, file)
          end

          def assert_correction(correction, loop: true)
            metz_assert_correction(correction, loop: loop)
          end
        RUBY
      end
    end
  end
end
