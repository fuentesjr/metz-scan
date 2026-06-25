# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/commands/scan/offense_extractor"

module MetzScan
  module Commands
    class ScanOffenseExtractorTest < Minitest::Test
      def test_extracts_current_rubocop_location_keys
        offense = extracted_offense("location" => { "start_line" => 8, "start_column" => 2 })

        assert_equal 8, offense.fetch(:line)
        assert_equal 2, offense.fetch(:column)
      end

      def test_extracts_legacy_rubocop_location_keys
        offense = extracted_offense("location" => { "line" => 9, "column" => 3 })

        assert_equal 9, offense.fetch(:line)
        assert_equal 3, offense.fetch(:column)
      end

      def test_missing_location_keys_fail_loudly
        error = assert_raises(KeyError) { extracted_offense("location" => {}) }

        assert_match(%r{missing start_line/line}, error.message)
      end

      private

      def extracted_offense(extra)
        parsed = { "files" => [{ "path" => "app/order.rb", "offenses" => [base_offense.merge(extra)] }] }
        Scan::OffenseExtractor.offenses(parsed).fetch(0)
      end

      def base_offense
        { "cop_name" => "Metz/MethodsTooLong", "severity" => "refactor", "message" => "Too long." }
      end
    end
  end
end
