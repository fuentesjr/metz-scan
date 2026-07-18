# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

module MetzScan
  class AgentWorkspaceDocsTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    CANONICAL_SKILLS_DIR = File.join(REPO_ROOT, ".claude/skills")
    CODEX_SKILLS_LINK = File.join(REPO_ROOT, ".agents/skills")
    SKILL_NAMES = %w[dogfood-round extract-approach land-slice release].freeze
    OPERATOR_PLAYBOOK = ".claude/guides/operator-playbook.md"
    GOAL_BACKLOG = ".claude/guides/goal-backlog.md"
    HARNESS_SLASH_INVOCATION = %r{`/(?:dogfood-round|extract-approach|land-slice|release)`}

    def test_codex_skills_symlink_resolves_to_canonical_skills
      assert File.symlink?(CODEX_SKILLS_LINK), "#{CODEX_SKILLS_LINK} must be a symlink"
      assert_equal File.realpath(CANONICAL_SKILLS_DIR), File.realpath(CODEX_SKILLS_LINK)
    end

    def test_each_skill_has_portable_frontmatter
      SKILL_NAMES.each do |name|
        assert_equal name, skill_frontmatter(name).fetch("name")
        refute_empty skill_frontmatter(name).fetch("description").strip
      end
    end

    def test_skills_avoid_harness_specific_invocation_syntax
      SKILL_NAMES.each do |name|
        refute_match HARNESS_SLASH_INVOCATION, skill_body(name)
      end
    end

    def test_claude_brief_routes_both_harnesses
      SKILL_NAMES.each { |name| assert_includes claude_brief, name }
      assert_includes claude_brief, OPERATOR_PLAYBOOK
      assert_includes claude_brief, "AGENTS.md"
    end

    def test_codex_entrypoint_routes_to_shared_brief
      ["CLAUDE.md", ".trk/", ".agents/skills", OPERATOR_PLAYBOOK, GOAL_BACKLOG].each do |ref|
        assert_includes codex_entrypoint, ref
      end
    end

    private

    def skill_body(name)
      File.read(File.join(CANONICAL_SKILLS_DIR, name, "SKILL.md"))
    end

    def skill_frontmatter(name)
      YAML.safe_load(skill_body(name)[/\A---\n(.*?)\n---/m, 1])
    end

    def claude_brief
      @claude_brief ||= File.read(File.join(REPO_ROOT, "CLAUDE.md"))
    end

    def codex_entrypoint
      @codex_entrypoint ||= File.read(File.join(REPO_ROOT, "AGENTS.md"))
    end
  end
end
