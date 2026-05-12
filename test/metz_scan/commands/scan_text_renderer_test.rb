# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "metz_scan/commands/scan/text_renderer"

module MetzScan
  module Commands
    class ScanTextRendererTest < Minitest::Test
      PARSED = {
        "files" => [
          { "path" => "lib/foo.rb",
            "offenses" => [
              { "cop_name" => "Metz/MethodsTooLong",
                "message" => "Method is too long.",
                "location" => { "start_line" => 7, "start_column" => 3 },
                "why_it_matters" => "Long methods hide intent.",
                "fix_safety" => "manual",
                "suggested_next_moves" => ["Extract a private method"] },
              { "cop_name" => "Metz/MethodsTooLong",
                "message" => "Method is too long.",
                "location" => { "start_line" => 22, "start_column" => 5 },
                "why_it_matters" => "Long methods hide intent.",
                "fix_safety" => "manual",
                "suggested_next_moves" => ["Extract a private method"] },
              { "cop_name" => "Layout/IndentationWidth",
                "message" => "Use 2 spaces.",
                "location" => { "start_line" => 3, "start_column" => 1 } }
            ] }
        ]
      }.freeze

      def setup
        @stdout = StringIO.new
      end

      def test_non_tty_output_contains_no_ansi_escapes
        Scan::TextRenderer.new(@stdout, PARSED).render

        refute_match(/\e\[/, @stdout.string)
      end

      def test_non_tty_heading_appears_on_its_own_line
        Scan::TextRenderer.new(@stdout, PARSED).render
        lines = @stdout.string.lines.map(&:chomp)

        assert_includes lines, "Metz/MethodsTooLong"
        assert_includes lines, "Layout/IndentationWidth"
      end

      def test_offense_lines_are_indented_below_their_heading
        Scan::TextRenderer.new(@stdout, PARSED).render
        offense_lines = @stdout.string.lines.grep(/\.rb:\d+:\d+/)

        refute_empty offense_lines
        offense_lines.each { |line| assert_match(/\A  \S/, line) }
      end

      def test_metz_cop_block_mentions_metz_scan_explain
        Scan::TextRenderer.new(@stdout, PARSED).render

        assert_match(%r{Run `metz-scan explain Metz/MethodsTooLong` for details\.}, @stdout.string)
      end

      def test_metz_cop_block_renders_why_it_matters_line
        Scan::TextRenderer.new(@stdout, PARSED).render

        assert_match(/Why it matters: Long methods hide intent\./, @stdout.string)
      end

      def test_non_metz_cop_block_does_not_emit_explain_hint
        Scan::TextRenderer.new(@stdout, PARSED).render
        layout_block = @stdout.string.split("Layout/IndentationWidth", 2).last

        refute_match(%r{metz-scan explain Layout/IndentationWidth}, layout_block)
      end

      def test_each_cop_appears_at_most_once_as_a_heading
        Scan::TextRenderer.new(@stdout, PARSED).render

        assert_equal 1, @stdout.string.scan(%r{^Metz/MethodsTooLong$}).size
        assert_equal 1, @stdout.string.scan(%r{^Layout/IndentationWidth$}).size
      end

      def test_tty_heading_is_visually_distinct_from_offense_lines
        heading_line = render_tty.lines.find { |line| line.include?("Metz/MethodsTooLong") }

        assert_match(/\e\[1m/, heading_line, "heading should be bold in TTY mode")
        assert_match(/\e\[36m/, heading_line, "heading should be cyan in TTY mode")
        assert_match(/\e\[0m/, heading_line, "heading should reset its style")
      end

      def test_tty_offense_lines_are_not_themselves_colorized
        offense_line = render_tty.lines.find { |line| line =~ /\.rb:\d+:\d+/ }

        refute_match(/\e\[/, offense_line, "offense lines stay plain so the heading is the visible band")
      end

      def test_tty_output_contains_no_unclosed_or_malformed_escapes
        out = render_tty

        assert_operator out.scan(/\e\[(?:\d+(?:;\d+)*)m/).size, :>, 0
        assert_operator out.scan("\e[0m").size, :>, 0
      end

      private

      def render_tty
        tty_stdout = TTYStringIO.new
        Scan::TextRenderer.new(tty_stdout, PARSED).render
        tty_stdout.string
      end

      class TTYStringIO < StringIO
        def tty?
          true
        end
      end
    end
  end
end
