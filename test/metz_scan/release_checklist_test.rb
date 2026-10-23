# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

module MetzScan
  class ReleaseChecklistTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    CI_PARITY_CHECK = "bin/check_ci_parity"
    CI_PARITY_NEXT_ACTION = "next action:"
    CI_PARITY_PRESERVED_CLONE = "clean clone preserved at"
    READ_ONLY_GUARD = "bin/check_read_only_commands"
    CALIBRATION_SMOKE = "bundle exec ruby bin/check_project_analyzer_calibration --text --no-write " \
                        "test/fixtures/sample_app"
    GITHUB_ANNOTATIONS_ASSERTION = "grep -q '^::warning file=.*MetzProject/ServiceSoup'"
    RELEASE_METADATA_SMOKE = "bundle exec ruby -Ilib -Itest test/metz_scan/release_metadata_test.rb"
    RELEASE_ISSUE_SMOKE = "bundle exec ruby -Ilib -Itest test/metz_scan/create_release_issue_test.rb"
    RELEASE_ISSUE_DRY_RUN = "bin/create_release_issue --dry-run"
    PART_P_PLANTS = [
      ["P1", "permissions:\n  contents: read\n\n", "", false],
      ["P2", "contents: read", "\"contents\": \"write\"", false],
      ["P4", "permissions:\n  contents: read\n", "permissions: {contents: read, pull-requests: write}\n", false],
      ["P6", "  rubydex:\n", "  rubydex:\n    permissions: read-all\n", false],
      ["P7", "name: CI", "name: CI", true]
    ].freeze

    def test_issue_template_body_matches_release_checklist
      assert_equal canonical_checklist_body, issue_template_body
    end

    def test_release_checklists_include_calibration_smoke
      release_checklists.each { |path| assert_includes File.read(path), CALIBRATION_SMOKE, path }
    end

    def test_release_checklists_include_release_metadata_smokes
      release_checklists.each { |path| assert_release_metadata_smokes(path) }
    end

    def test_release_checklists_document_issue_dry_run
      release_checklists.each { |path| assert_includes File.read(path), RELEASE_ISSUE_DRY_RUN, path }
    end

    def test_ci_runs_calibration_smoke
      assert_includes File.read(repo_path(".github/workflows/ci.yml")), CALIBRATION_SMOKE
    end

    def test_github_annotations_smoke_is_documented_and_run_by_ci
      release_checklists.each { |path| assert_includes File.read(path), GITHUB_ANNOTATIONS_ASSERTION, path }
      assert_includes File.read(repo_path(".github/workflows/ci.yml")), GITHUB_ANNOTATIONS_ASSERTION
    end

    def test_release_checklists_document_ci_parity_check
      release_checklists.each { |path| assert_includes File.read(path), CI_PARITY_CHECK, path }
    end

    def test_release_checklists_document_ci_parity_failure_inspection
      release_checklists.each { |path| assert_ci_parity_failure_inspection(path) }
    end

    def test_release_checklists_document_read_only_guard
      release_checklists.each { |path| assert_includes File.read(path), READ_ONLY_GUARD, path }
    end

    def test_ci_parity_script_covers_ci_single_command_steps
      script = normalized_ruby_script(File.read(repo_path(CI_PARITY_CHECK)))

      refute_empty ci_single_command_steps
      ci_single_command_steps.each { |command| assert_includes script, command }
    end

    def test_ci_permissions_are_contents_read
      text = File.read(repo_path(".github/workflows/ci.yml"))
      assert_equal 5, PART_P_PLANTS.size
      PART_P_PLANTS.each { |plant| assert_contents_read_plant(text, plant) }
    end

    private

    def ci_single_command_steps
      workflow = YAML.safe_load_file(repo_path(".github/workflows/ci.yml"))
      steps = workflow.fetch("jobs").fetch("test").fetch("steps")
      steps.filter_map { |step| step["run"]&.strip }.reject { |run| run.include?("\n") }
    end

    def assert_contents_read_plant(text, plant)
      name, pattern, replacement, pass = plant
      workflow = YAML.safe_load(text.sub(pattern, replacement))
      assert_equal(pass, workflow["permissions"] == { "contents" => "read" } &&
        workflow.fetch("jobs").none? { |_, job| job.key?("permissions") }, name)
    end

    def release_checklists
      [repo_path("RELEASE_CHECKLIST.md"), repo_path(".github/ISSUE_TEMPLATE/release_checklist.md")]
    end

    def assert_release_metadata_smokes(path)
      checklist = File.read(path)

      assert_includes checklist, RELEASE_METADATA_SMOKE, path
      assert_includes checklist, RELEASE_ISSUE_SMOKE, path
    end

    def assert_ci_parity_failure_inspection(path)
      checklist = File.read(path)

      assert_includes checklist, CI_PARITY_PRESERVED_CLONE, path
      assert_includes checklist, CI_PARITY_NEXT_ACTION, path
    end

    def canonical_checklist_body
      body_from(File.read(repo_path("RELEASE_CHECKLIST.md")))
    end

    def issue_template_body
      body_from(File.read(repo_path(".github/ISSUE_TEMPLATE/release_checklist.md")))
    end

    def body_from(markdown)
      markdown[markdown.index("## Verification")..]
    end

    def normalized_ruby_script(script)
      script.gsub(/"\s*\\\n\s*"/, "")
    end

    def repo_path(path)
      File.join(REPO_ROOT, path)
    end
  end

  class CiActionPinTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    CI_WORKFLOW = ".github/workflows/ci.yml"
    CHECKOUT_PIN = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"
    RUBYDEX_CHECKOUT = "BUNDLE_WITH: rubydex\n\n    steps:\n      - name: Checkout\n        uses: "
    PINNED_ACTION = %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}\z}
    PART_S_PLANTS = [
      ["S1", CHECKOUT_PIN, "actions/checkout@v7.0.1 # v7.0.1", false],
      ["S3", "#{RUBYDEX_CHECKOUT}#{CHECKOUT_PIN}", "#{RUBYDEX_CHECKOUT}actions/checkout@v7.0.1 # v7.0.1", false],
      ["S4", CHECKOUT_PIN, "actions/checkout@3d3c42e # v7.0.1", false],
      ["S5", CHECKOUT_PIN, "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1", false],
      ["S6", "    steps:\n", "    steps:\n      - { uses: actions/cache@v4 } # v4\n", false],
      ["S7", "name: CI", "name: CI", true],
      ["S8", "    steps:\n", "    steps:\n      - \"uses\": actions/cache@v4 # v4\n", false],
      ["S9", "jobs:\n", "jobs:\n  reusable:\n    uses: fuentesjr/x/.github/workflows/y.yml@main # v1\n", false]
    ].freeze

    def test_ci_actions_are_sha_pinned
      text = File.read(repo_path(CI_WORKFLOW))
      assert_equal 8, PART_S_PLANTS.size
      PART_S_PLANTS.each { |plant| assert_sha_pinned_plant(text, plant) }
    end

    private

    def assert_sha_pinned_plant(text, plant)
      name, pattern, replacement, pass = plant
      planted = text.sub(pattern, replacement)
      assert_equal(pass, sha_pinned_actions?(planted), name)
    end

    def sha_pinned_actions?(text) = action_uses(YAML.safe_load(text)).all?(PINNED_ACTION) && uses_comments?(text)

    def uses_comments?(text) = text.lines.grep(/["']?uses["']?\s*:/).all?(/# v[0-9]+(?:\.[0-9]+)*\s*$/)

    def action_uses(workflow) = workflow.fetch("jobs").values.flat_map { |job| job_uses(job) }.compact

    def job_uses(job) = [job["uses"], *Array(job["steps"]).filter_map { |step| step["uses"] }]

    def repo_path(path) = File.join(REPO_ROOT, path)
  end

  module PrDescriptionWorkflow
    JOB_VALUE = "a step before the check or a job value differs from its pinned literal"
    EXPECTED_IF = "github.event_name == 'pull_request'"
    EXPECTED_ON = {
      "push" => { "branches" => ["main"] },
      "pull_request" => { "types" => %w[opened edited synchronize reopened] }
    }.freeze
    OUTPUTS = { "docs_only" => "${{ steps.scope.outputs.docs_only }}" }.freeze
    CHECKOUT_WITH = { "fetch-depth" => 0, "persist-credentials" => false }.freeze
    CHECKOUT = {
      "name" => "Checkout",
      "uses" => "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
      "with" => CHECKOUT_WITH
    }.freeze
    JOB_KEYS = %w[outputs runs-on steps].freeze
    STEP_KEYS = %w[if name run].freeze

    module_function

    def violations(text)
      collect(YAML.safe_load(text)).uniq
    end

    def collect(workflow)
      job = workflow.dig("jobs", "test")
      trigger_violations(workflow) + job_violations(job) + step_violations(job) +
        PrDescriptionWorkflowText.text_violations(job)
    end

    def trigger_violations(workflow)
      flags = []
      flags << "workflow env present" if workflow.key?("env")
      flags << "workflow defaults present" if workflow.key?("defaults")
      flags << "on differs" unless workflow[true] == EXPECTED_ON
      flags
    end

    def job_violations(job)
      shape_flags(job) + value_flags(job)
    end

    def shape_flags(job)
      [
        *flag(job.key?("if"), "job if present"),
        *flag(job.key?("defaults"), "job defaults present"),
        *flag(job.dig("strategy", "matrix"), "matrix present")
      ]
    end

    def value_flags(job)
      messages = []
      messages << JOB_VALUE unless job_values_match?(job)
      messages << "job continue-on-error" if job.key?("continue-on-error")
      messages.concat(PrDescriptionWorkflowText.step_continue_flags(job))
      messages
    end

    def job_values_match?(job)
      job["runs-on"] == "ubuntu-24.04" && job["outputs"] == OUTPUTS && keys_match?(job.keys, JOB_KEYS)
    end

    def step_violations(job)
      steps = Array(job["steps"])
      step = find_check(steps)
      return ["step missing"] unless step

      step_flags(steps, step)
    end

    def find_check(steps)
      found = steps.select { |step| step["run"].to_s.include?("check_pr_description") }
      found.first if found.size == 1
    end

    def step_flags(steps, step)
      index = steps.index(step)
      key_flags(step) + run_flags(step) + place_flags(steps, index)
    end

    def key_flags(step)
      flags = []
      flags << "step keys differ" unless keys_match?(step.keys, STEP_KEYS)
      flags << "step if differs" unless step["if"] == EXPECTED_IF
      flags
    end

    def run_flags(step)
      run = step["run"].to_s
      flags = []
      flags << "run differs" unless run == PrDescriptionWorkflowText::EXPECTED_RUN
      flags << "expression in run" if run.include?("${{")
      flags
    end

    def place_flags(steps, index)
      flags = []
      flags << "step order differs" unless index == 1
      flags.concat(PrDescriptionWorkflowText.before_flags(steps, index))
      flags.concat(PrDescriptionWorkflowText.checkout_with_flags(steps))
      flags
    end

    def keys_match?(actual, expected)
      PrDescriptionWorkflowText.keys_match?(actual, expected)
    end

    def flag(present, message)
      PrDescriptionWorkflowText.flag(present, message)
    end
  end

  module PrDescriptionWorkflowText
    SECRET = ["github.event.pull_request.body", "github.event.pull_request.title"].freeze
    EXPECTED_RUN = <<~RUN
      if git cat-file -e HEAD^1:bin/check_pr_description; then
        git show HEAD^1:bin/check_pr_description > "$RUNNER_TEMP/check_pr_description"
        git show HEAD^1:.cursor/rules/opening-a-pr.mdc > "$RUNNER_TEMP/opening-a-pr.mdc" || {
          echo "fail: playbook copy not found in base"
          exit 1
        }
      elif git rev-parse -q --verify HEAD^1 >/dev/null; then
        cp bin/check_pr_description "$RUNNER_TEMP/check_pr_description"
        cp .cursor/rules/opening-a-pr.mdc "$RUNNER_TEMP/opening-a-pr.mdc" || {
          echo "fail: playbook copy not found in base"
          exit 1
        }
      else
        exit 1
      fi
      git show HEAD^1:.claude/skills/unslop/SKILL.md > "$RUNNER_TEMP/unslop-SKILL.md" || true
      ruby "$RUNNER_TEMP/check_pr_description"
    RUN

    module_function

    def text_violations(job)
      Array(job["steps"]).flat_map { |step| step_text_flags(step) }
    end

    def step_text_flags(step)
      flags = []
      flags << "event body in env" if secret_text?(joined(step["env"]))
      flags << "expression in run" if secret_text?(joined(step["with"])) || secret_text?(joined(step["run"]))
      flags
    end

    def secret_text?(text)
      SECRET.any? { |needle| text.include?(needle) }
    end

    def joined(value)
      strings(value).join("\n")
    end

    def strings(value)
      return [value] if value.is_a?(String)
      return value.flat_map { |child| strings(child) } if value.is_a?(Array)
      return value.values.flat_map { |child| strings(child) } if value.is_a?(Hash)

      []
    end

    def keys_match?(actual, expected)
      (actual - expected).empty? && (expected - actual).empty?
    end

    def flag(present, message)
      present ? [message] : []
    end

    def step_continue_flags(job)
      steps = Array(job["steps"])
      flag(steps.any? { |step| step.key?("continue-on-error") }, "step continue-on-error")
    end

    def before_flags(steps, index)
      checkout = [PrDescriptionWorkflow::CHECKOUT]
      return [PrDescriptionWorkflow::JOB_VALUE] unless steps[0...index] == checkout

      []
    end

    def checkout_with_flags(steps)
      return [] if steps[0] && steps[0]["with"] == PrDescriptionWorkflow::CHECKOUT_WITH

      ["checkout with differs"]
    end
  end

  module PrDescriptionWorkflowPlants
    JOB_VALUE = PrDescriptionWorkflow::JOB_VALUE

    module_function

    def rows
      opening + middle + closing
    end

    def opening
      first + second
    end

    def middle
      third + fourth
    end

    def closing
      fifth + sixth + seventh
    end

    def first
      [
        ["W1", [edit(:remove_check)], "step missing"],
        ["W2", [edit(:add_matrix)], "matrix present"],
        ["W3", [edit(:drop_if)], "step if differs"]
      ]
    end

    def second
      [
        ["W4", [edit(:gate_docs)], "step if differs"],
        ["W5", [edit(:move_after_setup)], "step order differs"],
        ["W6", [edit(:shallow_fetch)], "checkout with differs"]
      ]
    end

    def third
      [
        ["W7", [edit(:keep_credentials)], "checkout with differs"],
        ["W8", [edit(:leak_body)], "event body in env"],
        ["W9", [edit(:echo_title)], "expression in run"]
      ]
    end

    def fourth
      [
        ["W10", [edit(:drop_base_skill)], "run differs"],
        ["W11", [edit(:worktree_checker)], "run differs"],
        ["W12", w12_plants, nil]
      ]
    end

    def w12_plants
      [[edit(:use_pr_types), :pass], *trigger_fails]
    end

    def trigger_fails
      [
        [edit(:add_pull_request_target), "on differs"],
        [edit(:add_workflow_run), "on differs"],
        [edit(:add_labeled_type), "on differs"]
      ]
    end

    def fifth
      [
        ["W13", [edit(:continue_on_error)], "step keys differ"],
        ["W14", [edit(:job_if)], "job if present"],
        ["W15", [edit(:unchanged)], :pass]
      ]
    end

    def sixth
      [
        ["W16", [edit(:job_defaults)], "job defaults present"],
        ["W17", [edit(:workflow_env)], "workflow env present"],
        ["W18", [edit(:insert_setup), edit(:self_hosted)], JOB_VALUE]
      ]
    end

    def seventh
      [["W19", [edit(:classify_continue)], "step continue-on-error"]]
    end

    def edit(name)
      PrDescriptionWorkflowEdits.method(name)
    end
  end

  module PrDescriptionWorkflowEdits
    CHECK = %r{      - name: Check PR description\n.*?ruby "\$RUNNER_TEMP/check_pr_description"\n}m
    IF_LINE = "        if: github.event_name == 'pull_request'\n"
    SETUP = [
      "      - name: Setup Ruby",
      "        uses: ruby/setup-ruby@v1",
      "        with:",
      "          ruby-version: .ruby-version",
      "          bundler-cache: true\n"
    ].join("\n")

    module_function

    def remove_check(text)
      text.sub(CHECK, "")
    end

    def add_matrix(text)
      text.sub(runs_on, "#{runs_on}    strategy:\n      matrix:\n        ruby: [\"3.4\", \"4.0\"]\n")
    end

    def drop_if(text)
      text.sub(IF_LINE, "")
    end

    def gate_docs(text)
      text.sub(IF_LINE, "        if: github.event_name == 'pull_request' && steps.scope.outputs.docs_only != 'true'\n")
    end

    def move_after_setup(text)
      block = text[CHECK]
      text.sub(block, "").sub(cache_line, "#{cache_line}#{block}")
    end

    def shallow_fetch(text)
      text.sub("fetch-depth: 0", "fetch-depth: 1")
    end

    def keep_credentials(text)
      text.sub("          persist-credentials: false\n", "")
    end

    def leak_body(text)
      env = "        env:\n          PR_BODY: ${{ github.event.pull_request.body }}\n"
      text.sub(IF_LINE, "#{IF_LINE}#{env}")
    end

    def echo_title(text)
      echo = "          echo \"${{ github.event.pull_request.title }}\"\n"
      text.sub(ruby_line, "#{ruby_line}#{echo}")
    end

    def drop_base_skill(text)
      text.sub(skill_line, "          cp .claude/skills/unslop/SKILL.md \"$RUNNER_TEMP/unslop-SKILL.md\"\n")
    end

    def worktree_checker(text)
      replacement = "            cp bin/check_pr_description \"$RUNNER_TEMP/check_pr_description\"\n"
      text.sub(checker_line, replacement)
    end

    def use_pr_types(text) = text.sub(/  pull_request:\n(?:    types: \[.*?\]\n)?/, pr_types)

    def add_pull_request_target(text) = text.sub(pr_types, "#{pr_types}  pull_request_target:\n")

    def add_workflow_run(text) = text.sub(pr_types, "#{pr_types}  workflow_run:\n")

    def add_labeled_type(text) = text.sub("synchronize, reopened]", "synchronize, reopened, labeled]")

    def pr_types = "  pull_request:\n    types: [opened, edited, synchronize, reopened]\n"

    def continue_on_error(text)
      text.sub(check_name, "#{check_name}        continue-on-error: true\n")
    end

    def classify_continue(text)
      name = "      - name: Classify change scope\n"
      text.sub(name, "#{name}        continue-on-error: true\n")
    end

    def job_if(text)
      text.sub(test_job, "#{test_job}    if: false\n")
    end

    def unchanged(text)
      text
    end

    def job_defaults(text)
      text.sub(test_job, "#{test_job}    defaults: { run: { shell: \"true {0}\" } }\n")
    end

    def workflow_env(text)
      text.sub("jobs:\n", "env: { BASH_ENV: x.sh }\n\njobs:\n")
    end

    def insert_setup(text)
      text.sub(check_name, "#{SETUP}#{check_name}")
    end

    def self_hosted(text)
      text.sub(runs_on, "    runs-on: self-hosted\n")
    end

    def runs_on
      "    runs-on: ubuntu-24.04\n"
    end

    def cache_line
      "          bundler-cache: true\n"
    end

    def ruby_line
      "          ruby \"$RUNNER_TEMP/check_pr_description\"\n"
    end

    def skill_line
      "          git show HEAD^1:.claude/skills/unslop/SKILL.md > \"$RUNNER_TEMP/unslop-SKILL.md\" || true\n"
    end

    def checker_line
      "            git show HEAD^1:bin/check_pr_description > \"$RUNNER_TEMP/check_pr_description\"\n"
    end

    def check_name
      "      - name: Check PR description\n"
    end

    def test_job
      "  test:\n"
    end
  end

  class PrDescriptionWorkflowTest < Minitest::Test
    def test_part_w_workflow_rows
      text = File.read(File.expand_path("../../.github/workflows/ci.yml", __dir__))
      rows = PrDescriptionWorkflowPlants.rows
      assert_equal 19, rows.size
      rows.each { |row| assert_workflow_row(text, row) }
    end

    def assert_workflow_row(text, row)
      name, plants, expected = row
      return assert_mixed_plants(text, name, plants) if expected.nil?

      plants.each { |plant| assert_workflow_plant(name, plant.call(text), expected) }
    end

    def assert_mixed_plants(text, name, plants)
      plants.each do |plant, expected|
        assert_workflow_plant(name, plant.call(text), expected)
      end
    end

    def assert_workflow_plant(name, planted, expected)
      violations = PrDescriptionWorkflow.violations(planted)
      return assert_empty violations, name if expected == :pass

      assert_includes violations, expected, name
    end
  end
end
