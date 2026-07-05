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

    private

    def readme
      @readme ||= File.read(File.join(REPO_ROOT, "README.md"))
    end
  end
end
