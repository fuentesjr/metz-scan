# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"

module MetzScan
  module CheckPrDescriptionRows
    EM = "\u2014"
    EN = "\u2013"
    UNSLOP = "Run /unslop on the PR title and body, then edit the PR."
    EDIT = "Edit the PR title and body to follow .cursor/rules/opening-a-pr.mdc."
    CLOSED = "fail: banned list not found in base unslop skill"
    PASS = "pass\n"
    VALID_TITLE = "fix(ci): clean title"
    REQUIRED = ["## Why", "## What changed", "## Scope", "## Blast Radius", "## Verification"].freeze
    PROSE = {
      "## Why" => "The change fixes the reported miss.",
      "## What changed" => "- The check reads the copy.",
      "## Scope" => "- The check covers pull request text.",
      "## Blast Radius" => "The check runs in the test job.",
      "## Verification" => "- The row shows the result."
    }.freeze
    ENTITIES = ["&mdash;", "&#8212;", "&#x2014;", "&ndash;", "&#8211;", "&#x2013;", "&#x02014;", "&#x0002013;"].freeze
    D6_TOKENS = ["PR #12", "PR#12", "pr 12", "pull request 12"].freeze
    D7_TOKENS = ["issue #12", "ISSUE#12"].freeze
    LINK = "https://github.com/fuentesjr/metz-scan/pull/12"
    D16_EXACT = ["fail: dash U+2014 at body line 1",
                 "fail: unlinked reference fuentesjr/crucible#7 at body line 1",
                 UNSLOP].join("\n").concat("\n").freeze

    module_function

    def body_fail(body, line)
      { body: body, status: 1, includes: [line] }
    end

    def token_cases(tokens)
      tokens.map { |token| body_fail("see #{token} here", "fail: unlinked reference #{token} at body line 1") }
    end

    def entity_cases
      ENTITIES.map { |entity| body_fail("see #{entity} here", "fail: dash #{entity} at body line 1") }
    end

    def rows
      early + middle + late
    end

    def sections_body(names = REQUIRED, empty: [])
      names.map { |name| section_block(name, empty.include?(name)) }.join
    end

    def section_block(name, empty)
      return "#{name}\n" if empty

      "#{name}\n#{PROSE.fetch(name)}\n"
    end

    def early
      [dash_row, en_row, entity_row, spaced_row, bare_row]
    end

    def middle
      [pull_row, issue_row, letter_row, repo_row, case_row, inflection_row]
    end

    def late
      CheckPrDescriptionTail.rows
    end

    def dash_row
      { id: "D1", cases: [prose_dash, comment_dash, fence_dash] }
    end

    def prose_dash
      body_fail("before #{EM} after", "fail: dash U+2014 at body line 1")
    end

    def comment_dash
      body_fail("<!-- a #{EM} b -->", "fail: dash U+2014 at body line 1")
    end

    def fence_dash
      body_fail("```\na #{EM} b\n```", "fail: dash U+2014 at body line 2")
    end

    def en_row
      { id: "D2", cases: [body_fail("word #{EN} word", "fail: dash U+2013 at body line 1")] }
    end

    def entity_row
      { id: "D3", cases: entity_cases }
    end

    def spaced_row
      { id: "D4", cases: [body_fail("alpha -- beta", "fail: dash -- at body line 1")] }
    end

    def bare_row
      hidden = body_fail("see [x](a #12 b) here", "fail: unlinked reference #12 at body line 1")
      { id: "D5", cases: [body_fail("see #12 here", "fail: unlinked reference #12 at body line 1"), hidden] }
    end

    def pull_row
      { id: "D6", cases: token_cases(D6_TOKENS) }
    end

    def issue_row
      { id: "D7", cases: token_cases(D7_TOKENS) }
    end

    def letter_row
      { id: "D8", cases: [body_fail("see PR A here", "fail: unlinked reference PR A at body line 1")] }
    end

    def repo_row
      token = "fuentesjr/crucible#7"
      { id: "D9", cases: [body_fail("see #{token} here", "fail: unlinked reference #{token} at body line 1")] }
    end

    def case_row
      { id: "D10", cases: [body_fail("this is PIVOTAL today", "fail: banned word pivotal at body line 1")] }
    end

    def inflection_row
      { id: "D11", cases: [body_fail("showcasing the work", "fail: banned word showcase at body line 1")] }
    end
  end

  module CheckPrDescriptionTail
    ROWS = CheckPrDescriptionRows

    module_function

    def rows
      [title_word_row, title_link_row, base_row, closed_row] + later_rows
    end

    def later_rows
      [injection_row, linked_row, abstract_row, bot_row]
    end

    def title_word_row
      plant = { title: "fix(ci): this is crucial today", status: 1, includes: ["fail: banned word crucial at title"] }
      { id: "D12", cases: [plant] }
    end

    def title_link_row
      title = "[#12](https://github.com/fuentesjr/metz-scan/issues/12)"
      plant = { title: title, status: 1, includes: ["fail: bad title", "fail: unlinked reference #12 at title", ROWS::EDIT] }
      { id: "D13", cases: [plant] }
    end

    def base_row
      fail = ROWS.body_fail("pivotal choice", "fail: banned word pivotal at body line 1")
      { id: "D14", cases: [fail.merge(tree: true)] }
    end

    def plant_tree(dir, skill)
      path = File.join(dir, ".claude/skills/unslop/SKILL.md")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, skill.sub("pivotal, ", ""))
    end

    def closed_row
      missing = { skill: :missing, status: 1, exact: "#{ROWS::CLOSED}\n" }
      empty = { skill: :empty, status: 1, exact: "#{ROWS::CLOSED}\n" }
      norule = { skill: :norule, status: 1, exact: "#{ROWS::CLOSED}\n" }
      { id: "D15", cases: [missing, empty, norule] }
    end

    def injection_row
      body = "seen #{ROWS::EM} UNIQUE_MARKER_91 ::error::$(id)fuentesjr/crucible#7"
      { id: "D16", cases: [{ action: "synchronize", body: body, status: 1, exact: ROWS::D16_EXACT }] }
    end

    def linked_row
      body = "See [#12](#{ROWS::LINK}) and [PR A](#{ROWS::LINK}) and #{ROWS::LINK}."
      { id: "D17", cases: [{ body: body, status: 0, exact: ROWS::PASS }] }
    end

    def abstract_row
      body = "The landscape and tapestry show an enhancement."
      { id: "D18", cases: [{ body: body, status: 0, exact: ROWS::PASS }] }
    end

    def bot_row
      shared = { title: "Bump x from 1 to 2", head: "dependabot/bundler/x-2", body: "a #{ROWS::EM} b" }
      bot = shared.merge(login: "dependabot[bot]", status: 0, exact: "pass: dependabot\n")
      dash = "fail: dash U+2014 at body line 1"
      human = shared.merge(login: "fuentesjr", status: 1, includes: ["fail: bad title", dash, ROWS::EDIT])
      { id: "D19", cases: [bot, human] }
    end
  end

  module CheckPrDescriptionRunner
    SKILL = File.read(File.expand_path("../../.claude/skills/unslop/SKILL.md", __dir__)).freeze
    COPY = File.read(File.expand_path("../../.cursor/rules/opening-a-pr.mdc", __dir__)).freeze
    SCRIPT = File.expand_path("../../bin/check_pr_description", __dir__).freeze
    ROWS = CheckPrDescriptionRows

    module_function

    def assert_rows(test)
      rows = ROWS.rows
      test.assert_equal 19, rows.size
      rows.each { |row| assert_row(test, row) }
    end

    def assert_row(test, row)
      row[:cases].each { |plant| assert_case(test, row[:id], plant) }
    end

    def assert_case(test, id, plant)
      stdout, stderr, status = run(plant)
      test.assert_empty stderr, id
      test.assert_equal plant[:status], status.exitstatus, id
      assert_stdout(test, id, plant, stdout)
    end

    def assert_stdout(test, id, plant, stdout)
      return test.assert_equal plant[:exact], stdout, id if plant[:exact]

      test.assert_equal plant[:includes] + [ROWS::UNSLOP], stdout.lines.map(&:chomp), id
    end

    def run(plant)
      Dir.mktmpdir { |dir| capture(dir, plant) }
    end

    def capture(dir, plant)
      Open3.capture3(child_env(*write_inputs(dir, plant)), RbConfig.ruby, SCRIPT, **chdir_for(dir, plant))
    end

    def chdir_for(dir, plant)
      return { chdir: dir } if plant[:tree] || plant[:isolate]

      {}
    end

    def write_inputs(dir, plant)
      runner = File.join(dir, "runner")
      prepare_runner(runner, plant)
      [write_event(dir, plant), runner]
    end

    def prepare_runner(runner, plant)
      Dir.mkdir(runner)
      write_skill(runner, plant)
      write_copy(runner, plant)
    end

    def write_copy(runner, plant)
      return if plant[:copy] == :missing

      File.write(File.join(runner, "opening-a-pr.mdc"), copy_body(plant))
    end

    def copy_body(plant)
      return plant[:copy] if plant.key?(:copy)

      COPY
    end

    def write_event(dir, plant)
      path = File.join(dir, "event.json")
      File.write(path, JSON.generate(payload(plant)))
      path
    end

    def write_skill(runner, plant)
      return if plant[:skill] == :missing

      File.write(File.join(runner, "unslop-SKILL.md"), skill_text(plant))
      CheckPrDescriptionTail.plant_tree(File.dirname(runner), SKILL) if plant[:tree]
    end

    def skill_text(plant)
      return "" if plant[:skill] == :empty
      return "no rule 7 here\n" if plant[:skill] == :norule

      SKILL
    end

    def payload(plant)
      { "action" => plant[:action] || "opened", "pull_request" => pull_request(plant) }
    end

    def pull_request(plant)
      { "title" => title_of(plant), "body" => body_of(plant) }.merge(actor(plant), labels_for(plant))
    end

    def labels_for(plant)
      return {} unless plant[:labels]

      { "labels" => plant[:labels].map { |name| { "name" => name } } }
    end

    def actor(plant)
      { "user" => { "login" => plant.fetch(:login, "fuentesjr") }, "head" => { "ref" => plant[:head] } }
    end

    def title_of(plant)
      plant.fetch(:title, ROWS::VALID_TITLE)
    end

    def body_of(plant)
      return plant.fetch(:body, "").to_s if plant[:raw]

      stitch(plant[:body])
    end

    def stitch(body)
      sections = ROWS.sections_body
      return sections if body.nil? || body.empty?

      "#{body}\n#{sections}"
    end

    def child_env(event, runner)
      ENV.to_h.merge("GITHUB_EVENT_PATH" => event, "RUNNER_TEMP" => runner).tap do |env|
        env.delete("GH_TOKEN")
        env.delete("GITHUB_TOKEN")
      end
    end
  end

  module CheckPrDescriptionSections
    ROWS = CheckPrDescriptionRows
    EDIT = ROWS::EDIT
    CLOSED = "fail: playbook copy not found in base\n"
    PASS = "pass\n"
    CONTROL_TITLE = "feat(ci): add section check"
    BAD_TITLES = ["Add section check", "feat: add check", "feat(ci): add check.", "feat(ci): add check. ",
                  "Feat(ci): add check"].freeze
    SWAPPED = ["## Why", "## Scope", "## What changed", "## Blast Radius", "## Verification"].freeze
    WITH_TRADEOFFS = ["## Why", "## What changed", "## Scope", "## Tradeoffs",
                      "## Blast Radius", "## Verification"].freeze
    NO_SECTIONS = "**Titles.** Conventional Commits `type(scope): subject`, no trailing period.\n"
    NO_TITLES = "- `## Why`: the problem and approach.\n"
    WRONG_TOKEN = "**Titles.** Conventional Commits `subject only`, no trailing period.\n- `## Why`: text\n"

    module_function

    def assert_rows(test)
      listed = rows
      test.assert_equal 9, listed.size
      listed.each { |row| assert_row(test, row) }
    end

    def assert_row(test, row) = row.fetch(:cases).each { |plant| assert_case(test, row.fetch(:id), plant) }

    def assert_case(test, id, plant)
      stdout, stderr, status = CheckPrDescriptionRunner.run(plant)
      test.assert_empty stderr, id
      test.assert_equal plant.fetch(:status), status.exitstatus, id
      test.assert_equal plant.fetch(:exact), stdout, id
    end

    def rows
      [missing_row, order_row, level_row, empty_row, title_row, control_row, author_row, copy_row,
       summary_row]
    end

    def missing_row
      scope = fail_plant(body: ROWS.sections_body(ROWS::REQUIRED - ["## Scope"]),
                         exact: failed("fail: missing section ## Scope"))
      why = fail_plant(body: ROWS.sections_body(ROWS::REQUIRED - ["## Why"]),
                       exact: failed("fail: missing section ## Why"))
      { id: "1", cases: [scope, why] }
    end

    def order_row
      body = ROWS.sections_body(SWAPPED)
      { id: "2", cases: [fail_plant(body: body, exact: failed("fail: section out of order ## What changed"))] }
    end

    def level_row = { id: "3", cases: [level_plant("###"), level_plant("#")] }

    def level_plant(marker)
      body = "#{marker} Why\n#{ROWS::PROSE.fetch('## Why')}\n#{ROWS.sections_body(ROWS::REQUIRED - ['## Why'])}"
      lines = ["fail: wrong heading level ## Why", "fail: missing section ## Why"]
      fail_plant(body: body, exact: failed(*lines))
    end

    def empty_row
      scope = ROWS.sections_body(ROWS::REQUIRED, empty: ["## Scope"])
      tradeoffs = ROWS.sections_body(WITH_TRADEOFFS, empty: ["## Tradeoffs"])
      { id: "4", cases: [fail_plant(body: scope, exact: failed("fail: empty section ## Scope")),
                         fail_plant(body: tradeoffs, exact: failed("fail: empty section ## Tradeoffs"))] }
    end

    def title_row = { id: "5", cases: BAD_TITLES.map { |title| title_plant(title) } }

    def title_plant(title) = fail_plant(title: title, body: ROWS.sections_body, exact: failed("fail: bad title"))

    def control_row
      body = ROWS.sections_body
      lf = pass_plant(title: CONTROL_TITLE, body: body, exact: PASS)
      crlf = pass_plant(title: CONTROL_TITLE, body: body.gsub("\n", "\r\n"), exact: PASS)
      { id: "6", cases: [lf, crlf] }
    end

    def author_row = { id: "7", cases: [bot_plant, human_plant, bot_without_copy] }

    def bot_without_copy
      pass_plant(title: "Bump x from 1 to 2", body: "", login: "dependabot[bot]", copy: :missing,
                 isolate: true, exact: "pass: dependabot\n")
    end

    def bot_plant
      pass_plant(title: "Bump x from 1 to 2", body: "", login: "dependabot[bot]", exact: "pass: dependabot\n")
    end

    def human_plant
      lines = ["fail: bad title", *ROWS::REQUIRED.map { |name| "fail: missing section #{name}" }]
      fail_plant(title: "Bump x from 1 to 2", body: "", login: "sal", head: "dependabot/bundler/x",
                 labels: ["dependencies"], exact: failed(*lines))
    end

    def copy_row
      { id: "8", cases: [nowhere_plant, worktree_plant, text_plant(NO_SECTIONS), text_plant(NO_TITLES),
                         text_plant(WRONG_TOKEN), text_plant("")] }
    end

    def nowhere_plant
      fail_plant(copy: :missing, isolate: true, title: CONTROL_TITLE, body: ROWS.sections_body, exact: CLOSED)
    end

    def worktree_plant
      fail_plant(copy: :missing, title: CONTROL_TITLE, body: ROWS.sections_body, exact: CLOSED)
    end

    def text_plant(copy)
      fail_plant(copy: copy, title: CONTROL_TITLE, body: ROWS.sections_body, exact: CLOSED)
    end

    def summary_row
      body = "## Summary\n#{ROWS.sections_body}"
      { id: "9", cases: [fail_plant(title: CONTROL_TITLE, body: body, exact: failed("fail: unknown section"))] }
    end

    def failed(*lines) = "#{lines.join("\n")}\n#{EDIT}\n"

    def fail_plant(extra) = { raw: true, status: 1 }.merge(extra)

    def pass_plant(extra) = { raw: true, status: 0 }.merge(extra)
  end

  class CheckPrDescriptionTest < Minitest::Test
    def test_part_d_description_rows
      CheckPrDescriptionRunner.assert_rows(self)
    end

    def test_opening_a_pr_section_rows
      CheckPrDescriptionSections.assert_rows(self)
    end
  end
end
