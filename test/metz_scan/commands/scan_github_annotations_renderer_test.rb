# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "metz_scan/commands/scan/github_annotations_renderer"

module MetzScan
  module Commands
    class ScanGithubAnnotationsRendererTest < Minitest::Test
      PARSED = {
        "files" => [
          { "path" => "app/models/order,thing.rb",
            "offenses" => [{ "cop_name" => "Metz/Bad:Name,One",
                             "message" => "Use 100%\nnow\rplease",
                             "severity" => "refactor",
                             "location" => { "start_line" => 12, "start_column" => 3 } }] },
          { "path" => "app/jobs/payments.rb",
            "offenses" => [{ "cop_name" => "Metz/Explodes",
                             "message" => "Stop",
                             "severity" => "error",
                             "location" => { "line" => 7, "column" => 1 } }] }
        ]
      }.freeze

      def setup
        @stdout = StringIO.new
      end

      def test_renders_one_workflow_command_per_offense
        render_annotations

        assert_equal 2, annotation_lines.size
      end

      def test_refactor_severity_maps_to_warning
        render_annotations

        assert_match(/\A::warning /, annotation_lines.first)
      end

      def test_error_severity_maps_to_error
        render_annotations

        assert_match(/\A::error /, annotation_lines.last)
      end

      def test_escapes_workflow_command_properties_and_message
        render_annotations

        assert_includes annotation_lines.first, "file=app/models/order%2Cthing.rb"
        assert_includes annotation_lines.first, "title=Metz/Bad%3AName%2COne"
        assert_match(/::Use 100%25%0Anow%0Dplease\z/, annotation_lines.first)
      end

      private

      def render_annotations
        Scan::GithubAnnotationsRenderer.new(@stdout, PARSED).render
      end

      def annotation_lines
        @stdout.string.lines.map(&:chomp)
      end
    end
  end
end
