# frozen_string_literal: true

require "minitest/autorun"

module MetzScan
  class ReadmeWorkflowDocsTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_readme_documents_ci_parity_failure_inspection
      assert_includes readme, "bin/check_ci_parity"
      assert_includes readme, "clean clone preserved at"
      assert_includes readme, "next action:"
    end

    # Owner-approved 2026-10-13: exit 1 means only "findings reported"; every path where
    # scan could not check the code exits 2.
    EXIT_TWO_CASES = ["rubocop error", "invalid configuration", "nested", "internal error", "no files scanned"].freeze

    def test_readme_states_every_case_where_scan_exits_two
      exit_two_text = readme.split(/\n\s*\n/).grep(/exit\s+`2`/i).join("\n").downcase

      refute_empty exit_two_text, "README must state what exit `2` means"
      EXIT_TWO_CASES.each do |fact|
        assert_includes exit_two_text, fact, "README exit `2` paragraph must mention: #{fact}"
      end
    end

    private

    def readme
      @readme ||= File.read(File.join(REPO_ROOT, "README.md"))
    end
  end
end
