# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"

require_relative "../../tools/lane/security_bump"

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metz/ClassesTooLong, Metz/MethodsTooLong
class SecurityBumpLaneTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  OLD_SHA = "a" * 40
  NEW_SHA = "b" * 40
  FORK_SHA = "c" * 40
  TAGS = { "v1.342.0" => OLD_SHA, "v1.343.0" => NEW_SHA }.freeze
  PASS = "security-bump lane: version strings only"
  TYPES = %w[opened reopened synchronize labeled unlabeled].freeze
  WF = ".github/workflows/ruby.yml"
  NODE = ".github/workflows/node.yml"
  FAIL_PREFIX = "lane: security-bump label on a PR that changes more than version strings: "
  FAIL_SUFFIX = ". Remove the label so the normal gates run, or split the version bump into its own PR."

  def test_lane_predicate_table
    saved = stash_tokens
    assert_equal 14, rows.size
    assert_equal((1..14).to_a, rows.map { |row| row.fetch(:id) })
    assert_workflow
    rows.each do |row|
      result = decide(row)
      puts proof(row, result) if ENV["LANE_PROOF"] == "1"
      assert_result(row, result)
    end
  ensure
    restore_tokens(saved)
  end

  def rows
    @rows ||= build_rows
  end

  def build_rows
    [
      row(1, "label and .ruby-version 4.0.9 to 4.0.10", expect: :pass, label: true, lane: true, entries: ruby_bump),
      row(2, "gem line in Gemfile.lock", expect: :fail, file: "Gemfile.lock", label: true, entries: gem_bump),
      row(3, "node-version bump", expect: :fail, file: NODE, label: true, entries: node_bump),
      row(4, "no label and .ruby-version bump", expect: :noop, label: false, lane: false, entries: ruby_bump),
      row(5, "setup-ruby ref moved to @v1", expect: :fail, file: WF, label: true, entries: tag_ref),
      row(6, "ruby-version line also adds bundler-cache", expect: :fail, file: WF, label: true, entries: extra_token),
      row(7, "added matrix cell", expect: :fail, file: WF, label: true, entries: matrix_add),
      row(8, "renamed file", expect: :fail, file: ".ruby-version", label: true, entries: renamed_version),
      row(9, "full allowed set", expect: :pass, label: true, lane: true, entries: allowed_set),
      row(10, "setup-ruby SHA is not the tag commit", expect: :fail, file: WF, label: true, entries: fork_sha),
      row(11, "version token inside run: |", expect: :fail, file: WF, label: true, entries: block_scalar),
      row(12, "test version the PR does not add", expect: :fail, file: "test/version_test.rb",
                                                  label: true, entries: version_mismatch),
      row(13, "setup-ruby pin edit in the lane workflow", expect: :fail, file: LaneSecurityBump::WORKFLOW,
                                                          label: true, entries: lane_workflow_edit),
      row(14, "files API returns no files while changed_files is 1", expect: :files, label: true,
                                                                     changed: 1, entries: [])
    ]
  end

  def row(id, input, **spec)
    expect = spec.fetch(:expect)
    entries = spec.fetch(:entries)
    {
      id: id,
      input: input,
      expect: expect,
      entries: entries,
      label: spec.fetch(:label),
      lane: spec.fetch(:lane, false),
      status: %i[pass noop].include?(expect) ? 0 : 1,
      file: spec[:file],
      changed: spec[:changed] || entries.size,
      tags: TAGS
    }
  end

  def decide(row)
    client = row[:label] ? StubClient.new(row[:entries], row[:tags]) : ClosedClient.new
    LaneSecurityBump.check(event_for(row), client: client)
  end

  def event_for(row)
    {
      "pull_request" => {
        "labels" => row[:label] ? [{ "name" => "lane: security-bump" }] : [],
        "changed_files" => row[:changed]
      }
    }
  end

  def assert_result(row, result)
    assert_equal row[:lane], result[:lane], "row #{row[:id]} lane #{result[:message]}"
    assert_equal row[:status], result[:status], "row #{row[:id]} status #{result[:message]}"
    case row[:expect]
    when :pass
      assert_equal PASS, result[:message], "row #{row[:id]}"
    when :noop
      assert_equal "", result[:message], "row #{row[:id]}"
    when :fail
      assert_match(fail_pattern(row[:file]), result[:message], "row #{row[:id]}")
    when :files
      assert_equal "#{FAIL_PREFIX}files:0#{FAIL_SUFFIX}", result[:message], "row #{row[:id]}"
    end
  end

  def fail_pattern(path)
    /\A#{Regexp.escape(FAIL_PREFIX)}#{Regexp.escape(path)}:\d+#{Regexp.escape(FAIL_SUFFIX)}\z/
  end

  def assert_workflow
    text = File.read(File.join(ROOT, LaneSecurityBump::WORKFLOW))
    document = YAML.safe_load(text)
    trigger = document["on"] || document[true]
    assert_equal TYPES, trigger.dig("pull_request", "types")
    assert_includes text, %(git show "$BASE_SHA:#{LaneSecurityBump::SCRIPT}")
    assert_includes text, 'git cat-file -e "$BASE_SHA"'
    assert File.file?(File.join(ROOT, LaneSecurityBump::SCRIPT))
    uses = text.scan(/uses:\s*\S+/)
    assert(uses.all? { |line| line.match?(/@[0-9a-f]{40}\b/) })
  end

  def proof(row, result)
    state = result[:status].zero? ? "GREEN" : "RED"
    "row #{row[:id]} #{state} #{row[:input]} | lane=#{result[:lane]} status=#{result[:status]} #{result[:message]}"
  end

  def stash_tokens
    %w[GH_TOKEN GITHUB_TOKEN].to_h { |key| [key, ENV.fetch(key, nil)] }.tap do |saved|
      saved.each_key { |key| ENV.delete(key) }
    end
  end

  def restore_tokens(saved)
    return unless saved

    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV.store(key, value) }
  end

  def entry(path, base, head, extras = {})
    {
      "filename" => path,
      "status" => extras.fetch(:status, "modified"),
      "previous_filename" => extras[:previous],
      "patch" => unified(base, head),
      "base" => base,
      "head" => head
    }
  end

  def unified(base, head)
    Dir.mktmpdir do |dir|
      File.write("#{dir}/base", base)
      File.write("#{dir}/head", head)
      stdout, status = Open3.capture2("diff", "-u", "#{dir}/base", "#{dir}/head")
      raise "plant produced no diff" unless status.exitstatus == 1

      body = stdout.lines.drop_while { |line| !line.start_with?("@@") }.join
      raise "plant patch was empty" if body.empty?

      body
    end
  end

  def ruby_bump
    [entry(".ruby-version", "4.0.9\n", "4.0.10\n")]
  end

  def gem_bump
    [entry("Gemfile.lock", lock_gem("1.80.0"), lock_gem("1.81.0"))]
  end

  def node_bump
    [entry(NODE, node_workflow("20.11.0"), node_workflow("22.11.0"))]
  end

  def tag_ref
    [entry(WF, uses_workflow(OLD_SHA, "v1.342.0"), uses_workflow_ref("@v1"))]
  end

  def extra_token
    before = flow_workflow("with: { ruby-version: '4.0.9' }")
    after = flow_workflow("with: { ruby-version: '4.0.10', bundler-cache: false }")
    [entry(WF, before, after)]
  end

  def matrix_add
    [entry(WF, matrix_workflow("4.0.9"), matrix_workflow("4.0.9", extra: true))]
  end

  def renamed_version
    [entry(".ruby-version", "4.0.9\n", "4.0.10\n", { status: "renamed", previous: "ruby-version" })]
  end

  def fork_sha
    [entry(WF, uses_workflow(OLD_SHA, "v1.342.0"), uses_workflow(FORK_SHA, "v1.343.0"))]
  end

  def block_scalar
    [entry(WF, run_workflow("4.0.9"), run_workflow("4.0.10"))]
  end

  def lane_workflow_edit
    [entry(LaneSecurityBump::WORKFLOW, uses_workflow(OLD_SHA, "v1.342.0"), uses_workflow(NEW_SHA, "v1.343.0"))]
  end

  def allowed_set
    [
      entry(".ruby-version", "4.0.9\n", "4.0.10\n"),
      entry("mise.toml", "ruby = \"4.0.9\"\n", "ruby = \"4.0.10\"\n"),
      entry("Dockerfile", "ARG RUBY_VERSION=4.0.9\n", "ARG RUBY_VERSION=4.0.10\n"),
      entry(WF, full_workflow("4.0.9", OLD_SHA, "v1.342.0"), full_workflow("4.0.10", NEW_SHA, "v1.343.0")),
      entry("Gemfile.lock", lock_ruby("4.0.9"), lock_ruby("4.0.10")),
      entry("test/pin_test.rb", pin_assertion(OLD_SHA), pin_assertion(NEW_SHA))
    ]
  end

  def version_mismatch
    [
      entry(".ruby-version", "4.0.9\n", "4.0.10\n"),
      entry("test/version_test.rb", pin_assertion("4.0.9"), pin_assertion("4.0.11"))
    ]
  end

  def full_workflow(version, sha, tag)
    <<~YAML
      name: CI
      jobs:
        test:
          strategy:
            matrix:
              ruby:
                - "#{version}"
          steps:
            - uses: ruby/setup-ruby@#{sha} # #{tag}
              with:
                ruby-version: "#{version}"
              if: matrix.ruby == '#{version}'
    YAML
  end

  def uses_workflow(sha, tag)
    <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: ruby/setup-ruby@#{sha} # #{tag}
              with:
                ruby-version: .ruby-version
    YAML
  end

  def uses_workflow_ref(ref)
    <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: ruby/setup-ruby#{ref}
              with:
                ruby-version: .ruby-version
    YAML
  end

  def flow_workflow(line)
    <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: ruby/setup-ruby@#{OLD_SHA} # v1.342.0
              #{line}
    YAML
  end

  def matrix_workflow(version, extra: false)
    added = extra ? "\n                - \"4.0.10\"" : ""
    <<~YAML
      name: CI
      jobs:
        test:
          strategy:
            matrix:
              ruby:
                - "#{version}"#{added}
    YAML
  end

  def run_workflow(version)
    <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - name: show
              run: |
                echo #{version}
    YAML
  end

  def node_workflow(version)
    <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: actions/setup-node@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa # v4.0.0
              with:
                node-version: "#{version}"
    YAML
  end

  def lock_gem(version)
    <<~LOCK
      GEM
        remote: https://rubygems.org/
        specs:
          rubocop (#{version})

      RUBY VERSION
         ruby 4.0.9p0

      BUNDLED WITH
         4.0.8
    LOCK
  end

  def lock_ruby(version)
    <<~LOCK
      GEM
        specs:
          rubocop (1.80.0)

      RUBY VERSION
         ruby #{version}p0

      BUNDLED WITH
         4.0.8
    LOCK
  end

  def pin_assertion(value)
    "def test_pin\n  assert_equal \"#{value}\", pinned\nend\n"
  end

  class StubClient
    def initialize(entries, tags)
      @entries = entries
      @tags = tags
    end

    def files
      @entries.map { |entry| entry.slice("filename", "status", "patch", "previous_filename") }
    end

    def contents(side, path)
      entry = @entries.find { |item| item["filename"] == path }
      raise KeyError, path unless entry

      entry.fetch(side == "base" ? "base" : "head")
    end

    def tag_commit(tag)
      raise LaneSecurityBump::Error, "tag" unless @tags.key?(tag)

      @tags.fetch(tag)
    end
  end

  class ClosedClient
    def files
      raise "files api"
    end

    def contents(*)
      raise "contents"
    end

    def tag_commit(*)
      raise "tag"
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metz/ClassesTooLong, Metz/MethodsTooLong
