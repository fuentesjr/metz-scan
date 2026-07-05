# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

module MetzScan
  class MetzScanSkillTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    SKILL_PATH = File.join(REPO_ROOT, "skills/metz-scan/SKILL.md")
    METADATA_PATH = File.join(REPO_ROOT, "skills/metz-scan/agents/openai.yaml")
    REQUIRED_TERMS = [
      "bundle exec metz-scan rules",
      "bundle exec metz-scan project-analyzers",
      "bundle exec metz-scan scan",
      "--project-analyzers",
      "--format json",
      "--format sarif",
      "--format gh-annotations",
      "--auto-fix --dry-run",
      "Rubydex",
      "exit status `1`"
    ].freeze
    MAINTAINER_ONLY_TERMS = [
      "PROJECT_TRACKER.md",
      "bin/check_project_analyzer_calibration",
      "bin/check_ci_parity",
      "bin/check_read_only_commands"
    ].freeze

    def test_skill_frontmatter_is_complete
      assert_equal "metz-scan", frontmatter.fetch("name")
      assert_includes frontmatter.fetch("description"), "Ruby or Rails projects"
      refute_includes skill, %w[TO DO].join
    end

    def test_skill_covers_current_cli_surface
      REQUIRED_TERMS.each { |term| assert_includes skill, term }
    end

    def test_skill_stays_consumer_facing
      MAINTAINER_ONLY_TERMS.each { |term| refute_includes skill, term }
    end

    def test_openai_metadata_names_the_skill
      assert_equal "Metz Scan", openai_metadata.dig("interface", "display_name")
      assert_includes openai_metadata.dig("interface", "default_prompt"), "$metz-scan"
    end

    def test_readme_links_to_skill
      assert_includes readme, "skills/metz-scan/SKILL.md"
    end

    private

    def skill
      @skill ||= File.read(SKILL_PATH)
    end

    def frontmatter
      @frontmatter ||= YAML.safe_load(skill[/\A---\n(.*?)\n---/m, 1])
    end

    def openai_metadata
      @openai_metadata ||= YAML.safe_load_file(METADATA_PATH)
    end

    def readme
      @readme ||= File.read(File.join(REPO_ROOT, "README.md"))
    end
  end
end
