# frozen_string_literal: true

require "minitest/autorun"
require "open3"

module MetzScan
  class ReadOnlyCommandDocsTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_readme_documents_read_only_maintenance_contract
      assert_document_includes("README.md", readme_contract_terms)
    end

    def test_calibration_docs_name_read_only_guard_for_no_write_runs
      assert_document_includes("docs/project-analyzer-calibration.md", calibration_contract_terms)
    end

    private

    def readme_contract_terms
      ["bin/check_read_only_commands", "BUNDLE_FROZEN=1", "tracked files",
       *read_only_commands]
    end

    def calibration_contract_terms
      ["`--no-write` is the dry local summary mode", "bin/check_read_only_commands",
       "BUNDLE_FROZEN=1", "tracked files", *read_only_commands]
    end

    def assert_document_includes(path, terms)
      document = File.read(File.join(REPO_ROOT, path))
      terms.each { |term| assert_includes document, term }
    end

    def read_only_commands
      stdout, stderr, status = Open3.capture3(check_read_only_commands_path, "--list-default-commands")
      assert_predicate status, :success?, stderr
      stdout.lines.map(&:chomp)
    end

    def check_read_only_commands_path = File.join(REPO_ROOT, "bin/check_read_only_commands")
  end
end
