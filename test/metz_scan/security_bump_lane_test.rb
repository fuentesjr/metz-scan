# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "net/http"
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
  BASE_SHA = "d" * 40
  MERGE_BASE_SHA = "e" * 40
  TAGS = { "v1.342.0" => OLD_SHA, "v1.343.0" => NEW_SHA }.freeze
  PASS = "security-bump lane: version strings only"
  TYPES = %w[opened reopened synchronize edited labeled unlabeled].freeze
  WF = ".github/workflows/ruby.yml"
  NODE = ".github/workflows/node.yml"
  FAIL_PREFIX = "lane: security-bump label on a PR that changes more than version strings: "
  FAIL_SUFFIX = ". Remove the label so the normal gates run, or split the version bump into its own PR."

  def test_lane_predicate_table
    saved = stash_tokens
    assert_equal 22, rows.size
    assert_equal((1..22).to_a, rows.map { |row| row.fetch(:id) })
    assert_workflow
    rows.each do |row|
      result = decide(row)
      puts proof(row, result) if ENV["LANE_PROOF"] == "1"
      assert_result(row, result)
    end
    assert_api_error
    assert_unlabeled_run
    assert_local_diff
    assert_test_root
    assert_mise_table
    assert_mask_rejects
    assert_yaml_and_file_hardening
    assert_api_and_patch_guards
    assert_valid_compound_if
    assert_live_guards
    assert_live_changes
    assert_live_get_guards
    assert_live_tag_commit_guards
    assert_base_copy
    assert_shell_missing_unlabeled_and_error
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
                                                                     changed: 1, entries: ruby_bump, api_files: []),
      row(15, "rubygems version on an allowed line", expect: :fail, file: WF, label: true, entries: side_version),
      row(16, "label and base has no lane script", expect: :fail, file: LaneSecurityBump::SCRIPT, label: true,
                                                   entries: [], changed: 0, shell: true),
      row(17, "mode 100644 to 100755", expect: :fail, file: ".ruby-version", label: true, entries: mode_change),
      row(18, "label and zero changed files", expect: :files, label: true, changed: 0, entries: []),
      row(19, "workflow if: moved to another step in one hunk", expect: :fail, file: WF, label: true,
                                                                entries: cross_context_if),
      row(20, "workflow if: inside action with:", expect: :fail, file: WF, label: true, entries: action_with_if),
      row(21, "duplicate uses: key in workflow step", expect: :fail, file: WF, label: true,
                                                      entries: duplicate_uses_key),
      row(22, "test line moves unintroduced version into assertion", expect: :fail, file: "test/version_test.rb",
                                                                     label: true, entries: swapped_test_token)
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
      api_files: spec[:api_files],
      label: spec.fetch(:label),
      lane: spec.fetch(:lane, false),
      status: %i[pass noop].include?(expect) ? 0 : 1,
      file: spec[:file],
      changed: spec.fetch(:changed, entries.size),
      tags: TAGS,
      shell: spec[:shell]
    }
  end

  def decide(row)
    return shell_missing(label: true) if row[:shell]

    client = row[:label] ? StubClient.new(row[:entries], row[:tags], api_files: row[:api_files]) : ClosedClient.new
    assert_mode_fields(client) if row[:id] == 17
    LaneSecurityBump.check(event_for(row), client: client)
  end

  def assert_mode_fields(client)
    assert_equal({ "old" => "100644", "new" => "100755" }, client.modes.fetch(".ruby-version"))
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
    assert_base_reset_before_setup_ruby(document)
    assert File.file?(File.join(ROOT, LaneSecurityBump::SCRIPT))
    uses = text.scan(/uses:\s*\S+/)
    refute_empty uses
    assert(uses.all? { |line| line.match?(/@[0-9a-f]{40}\b/) })
    ruby_lines = text.each_line.map(&:strip).select { |line| line.start_with?("ruby ") }
    assert_equal [%(ruby "$RUNNER_TEMP/security_bump.rb")], ruby_lines
    refute_includes text, PASS
  end

  def assert_base_reset_before_setup_ruby(document)
    steps = document.dig("jobs", "security-bump-lane", "steps")
    reset_idx = steps.index { |step| step["run"].to_s.include?('git checkout --force --detach "$BASE_SHA"') }
    setup_idx = steps.index { |step| step["uses"].to_s.start_with?("ruby/setup-ruby@") }
    refute_nil reset_idx, "expected a step resetting working tree to BASE_SHA"
    refute_nil setup_idx, "expected ruby/setup-ruby step"
    assert_operator reset_idx, :<, setup_idx, "working tree must reset to BASE_SHA before ruby/setup-ruby reads files"
    assert_reset_step_restores_base(steps[reset_idx].fetch("run"))
  end

  def assert_reset_step_restores_base(script)
    Dir.mktmpdir do |dir|
      git_in(dir, "init", "-q")
      File.write(File.join(dir, ".ruby-version"), "4.0.9\n")
      git_in(dir, "add", ".")
      git_in(dir, "-c", "user.email=dev@example.com", "-c", "user.name=dev", "commit", "-q", "-m", "base")
      base_sha, status = Open3.capture2("git", "-C", dir, "rev-parse", "HEAD")
      raise "git rev-parse failed" unless status.success?

      File.write(File.join(dir, ".ruby-version"), "9.9.9\n")
      git_in(dir, "add", ".")
      git_in(dir, "-c", "user.email=dev@example.com", "-c", "user.name=dev", "commit", "-q", "-m", "head")
      File.write(File.join(dir, "untracked.txt"), "noise\n")

      env = { "BASE_SHA" => base_sha.strip, "PATH" => ENV.fetch("PATH") }
      _stdout, stderr, wait = Open3.capture3(env, "bash", "-c", script, chdir: dir)
      assert wait.success?, stderr
      assert_equal "4.0.9\n", File.read(File.join(dir, ".ruby-version"))
      refute File.exist?(File.join(dir, "untracked.txt"))
    end
  end

  def assert_api_error
    result = LaneSecurityBump.check(labeled_event(1), client: RaisingClient.new)
    assert_equal false, result[:lane]
    assert_equal 1, result[:status]
    assert_equal "#{FAIL_PREFIX}api:0#{FAIL_SUFFIX}", result[:message]
  end

  def assert_unlabeled_run
    row = rows.find { |item| item.fetch(:id) == 4 }
    Dir.mktmpdir do |dir|
      path = File.join(dir, "event.json")
      File.write(path, JSON.generate(event_for(row)))
      assert_equal [0, ""], LaneSecurityBump.run("GITHUB_EVENT_PATH" => path)
    end
  end

  def labeled_event(changed)
    {
      "pull_request" => {
        "labels" => [{ "name" => "lane: security-bump" }],
        "changed_files" => changed
      }
    }
  end

  def assert_local_diff
    api = [entry(".ruby-version", "4.0.9\n", "4.0.10\n")]
    real = [entry("Gemfile", "gem \"rake\", \"13.0.0\"\n", "gem \"rake\", \"13.1.0\"\n")]
    result = LaneSecurityBump.check(labeled_event(1), client: StubClient.new(real, TAGS, api_files: api))
    assert_equal 1, result[:status]
    assert_equal false, result[:lane]
    assert_match(fail_pattern("Gemfile"), result[:message])
  end

  def assert_test_root
    entries = [
      entry(".ruby-version", "4.0.9\n", "4.0.10\n"),
      entry("lib/test/pin_test.rb", pin_assertion("4.0.9"), pin_assertion("4.0.10"))
    ]
    result = LaneSecurityBump.check(labeled_event(2), client: StubClient.new(entries, TAGS))
    assert_equal 1, result[:status]
    assert_match(fail_pattern("lib/test/pin_test.rb"), result[:message])
  end

  def assert_mise_table
    loose = [entry("mise.toml", "ruby = \"4.0.9\"\n", "ruby = \"4.0.10\"\n")]
    result = LaneSecurityBump.check(labeled_event(1), client: StubClient.new(loose, TAGS))
    assert_equal 1, result[:status]
    assert_match(fail_pattern("mise.toml"), result[:message])
  end

  def assert_mask_rejects
    [node_version_line, gem_install_line, second_comparison].each do |entries|
      result = LaneSecurityBump.check(labeled_event(1), client: StubClient.new(entries, TAGS))
      assert_equal 1, result[:status], result[:message]
      assert_equal false, result[:lane]
    end
  end

  def assert_yaml_and_file_hardening
    hardening_cases.each do |name, entries|
      result = LaneSecurityBump.check(labeled_event(entries.size), client: StubClient.new(entries, TAGS))
      assert_equal 1, result[:status], "#{name}: #{result[:message]}"
      assert_equal false, result[:lane], name
    end
    eof_block = "name: CI\njobs:\n  test:\n    steps:\n      - run: |\n          echo 4.0.9"
    marks = LaneSecurityBump.workflow_marks(eof_block)
    assert marks[:forbidden][6], "expected EOF block scalar body line 6 to be forbidden"
  end

  def hardening_cases
    {
      "cross-context Dockerfile ARG move" => docker_stage_move,
      "Dockerfile line continuation" => docker_continuation,
      "Dockerfile backtick escape continuation" => docker_backtick_continuation,
      "Dockerfile syntax plus backtick escape" => docker_syntax_and_escape,
      "Dockerfile heredoc ARG-shaped line" => docker_heredoc_arg,
      "Dockerfile continued-line heredoc" => docker_continued_heredoc,
      "Dockerfile comment-only version change" => docker_comment_change,
      "multiline flow env: last line" => env_flow_multiline,
      "action with.strategy.matrix.ruby" => action_with_matrix,
      "YAML expression in ruby-version" => yaml_expression_ruby_version,
      "workflow if: comparison text inside string literal" => workflow_if_string_literal,
      "V-placeholder literal collision" => placeholder_v_collision,
      "Gemfile.lock non-ruby line in RUBY VERSION" => lock_non_ruby_line,
      "Gemfile.lock unindented terminator" => lock_unindented_section_end,
      "mise.toml inline comment version change" => mise_comment_change,
      ".ruby-version arbitrary text with version" => ruby_version_arbitrary_text,
      "test line with code and # assert comment" => comment_assert_bypass,
      "test line changing call argument instead of asserted string" => nested_call_arg_bypass,
      "test assertion text inside Ruby heredoc" => heredoc_assertion_bypass,
      "EOF newline added alongside version bump" => eof_newline_change,
      "reverse mode change 100755 to 100644" => reverse_mode_change
    }
  end

  def assert_api_and_patch_guards
    # API omits patch (too large) even when local diff is clean
    clean = ruby_bump
    omitted = [{ "filename" => ".ruby-version", "status" => "modified", "patch" => nil }]
    res = LaneSecurityBump.check(labeled_event(1), client: StubClient.new(clean, TAGS, raw_api_files: omitted))
    assert_equal 1, res[:status], "expected omitted API patch to fail closed"
    assert_equal "#{FAIL_PREFIX}files:0#{FAIL_SUFFIX}", res[:message]

    # API lists a different filename than local diff
    other = [{ "filename" => "README.md", "status" => "modified", "patch" => "@@ -1 +1 @@\n-a\n+b\n" }]
    res2 = LaneSecurityBump.check(labeled_event(1), client: StubClient.new(clean, TAGS, raw_api_files: other))
    assert_equal 1, res2[:status], "expected API/local filename mismatch to fail closed"
    assert_equal "#{FAIL_PREFIX}files:0#{FAIL_SUFFIX}", res2[:message]

    # Truncated hunk where declared count exceeds actual lines
    assert_nil LaneSecurityBump.parse_patch("@@ -1,3 +1,3 @@\n-4.0.9\n+4.0.10\n")
  end

  def assert_valid_compound_if
    before = "name: CI\njobs:\n  test:\n    steps:\n      - if: matrix.ruby == '4.0.9' && runner.os == 'Linux'\n"
    after = "name: CI\njobs:\n  test:\n    steps:\n      - if: matrix.ruby == '4.0.10' && runner.os == 'Linux'\n"
    result = LaneSecurityBump.check(labeled_event(1), client: StubClient.new([entry(WF, before, after)], TAGS))
    assert_equal 0, result[:status], result[:message]
    assert_equal true, result[:lane]
  end

  def node_version_line
    before = flow_workflow("with: { ruby-version: '4.0.9', node-version: '20.11.0' }")
    after = flow_workflow("with: { ruby-version: '4.0.10', node-version: '22.12.1' }")
    [entry(WF, before, after)]
  end

  def gem_install_line
    before = "name: CI\njobs:\n  test:\n    steps:\n      - run: gem install foo -v 4.0.9\n"
    after = "name: CI\njobs:\n  test:\n    steps:\n      - run: gem install foo -v 4.0.10\n"
    [entry(WF, before, after)]
  end

  def second_comparison
    before = "name: CI\njobs:\n  test:\n    steps:\n      - if: matrix.ruby == '4.0.9' && matrix.node == '20.11.0'\n"
    after = "name: CI\njobs:\n  test:\n    steps:\n      - if: matrix.ruby == '4.0.10' && matrix.node == '22.12.1'\n"
    [entry(WF, before, after)]
  end

  def assert_live_guards
    args = ["token", "owner/name", OLD_SHA, NEW_SHA, 1]
    ["http://api.github.com", "https://example.com", "https://api.github.com/bad url"].each do |url|
      assert_raises(LaneSecurityBump::Error) { LaneSecurityBump::Live.new(*args, url, Dir.pwd) }
    end
    bad_event = {
      "repository" => { "full_name" => "../evil" },
      "pull_request" => { "base" => { "sha" => OLD_SHA }, "head" => { "sha" => NEW_SHA }, "number" => 1 }
    }
    assert_raises(LaneSecurityBump::Error) { LaneSecurityBump::Live.build({ "GITHUB_TOKEN" => "t" }, bad_event) }
    assert_live_pagination_guard(args)
  end

  def assert_live_pagination_guard(args)
    live = LaneSecurityBump::Live.new(*args, "https://api.github.com", Dir.pwd)
    calls = 0
    live.define_singleton_method(:get) do |_path|
      calls += 1
      response = Object.new
      response.define_singleton_method(:body) { "[]" }
      response.define_singleton_method(:[]) { |_key| '<https://api.github.com/x>; rel="next"' }
      response
    end
    assert_raises(LaneSecurityBump::Error) { live.files }
    assert_equal 31, calls
  end

  def assert_live_changes
    live = LaneSecurityBump::Live.new("token", "owner/name", BASE_SHA, NEW_SHA, 1, "https://api.github.com", Dir.pwd)
    raw = ":100644 100755 aaaaaaa bbbbbbb M\t.ruby-version\n"
    diff = "diff --git a/.ruby-version b/.ruby-version\n--- a/.ruby-version\n+++ b/.ruby-version\n" \
           "#{unified("4.0.9\n", "4.0.10\n")}"
    seen_commands = []
    live.define_singleton_method(:get) { |_path| raise "Live#changes must not call the API" }
    live.define_singleton_method(:git) do |*cmd|
      seen_commands << cmd
      case cmd
      when ["merge-base", BASE_SHA, NEW_SHA] then "#{MERGE_BASE_SHA}\n"
      when ["diff", "--raw", "#{MERGE_BASE_SHA}..#{NEW_SHA}"] then raw
      when ["diff", "--no-color", "--no-ext-diff", "--src-prefix=a/", "--dst-prefix=b/",
            "#{MERGE_BASE_SHA}..#{NEW_SHA}"]
        diff
      else raise "unexpected git #{cmd.inspect}"
      end
    end
    changes = live.changes
    assert_equal 1, changes.size
    assert_equal ".ruby-version", changes.first["filename"]
    assert_equal "modified", changes.first["status"]
    assert_includes changes.first["patch"], "-4.0.9"
    assert_equal({ "old" => "100644", "new" => "100755" }, live.modes.fetch(".ruby-version"))
    assert_equal 3, seen_commands.size
    assert_live_changes_key_mismatch
  end

  def assert_live_changes_key_mismatch
    live = LaneSecurityBump::Live.new("token", "owner/name", BASE_SHA, NEW_SHA, 1, "https://api.github.com", Dir.pwd)
    live.define_singleton_method(:git) do |*cmd|
      case cmd.first
      when "merge-base" then "#{MERGE_BASE_SHA}\n"
      when "diff"
        cmd.include?("--raw") ? ":100644 100644 aaaaaaa bbbbbbb M\t.ruby-version\n" : ""
      end
    end
    assert_raises(LaneSecurityBump::Error) { live.changes }
  end

  def assert_live_get_guards
    live = LaneSecurityBump::Live.new("secret-token", "owner/name", OLD_SHA, NEW_SHA, 1,
                                      "https://api.github.com", Dir.pwd)
    calls = []
    stub_http(calls, Net::HTTPOK.new("1.1", "200", "OK")) do
      response = live.get("/repos/owner/name/pulls/1/files?per_page=100&page=1")
      assert_equal "200", response.code
      ["https://evil.example/repos/x", "//evil.example/repos/x", "/users/owner"].each do |bad_path|
        assert_raises(LaneSecurityBump::Error) { live.get(bad_path) }
      end
    end
    assert_equal 1, calls.size
    assert_equal "api.github.com", calls.first[:host]
    assert_equal 443, calls.first[:port]
    assert_equal true, calls.first[:opts][:use_ssl]
    assert_equal "Bearer secret-token", calls.first[:request]["Authorization"]

    redirect = Net::HTTPFound.new("1.1", "302", "Found")
    redirect["Location"] = "https://evil.example/steal"
    redirect_calls = []
    stub_http(redirect_calls, redirect) do
      assert_raises(LaneSecurityBump::Error) { live.get("/repos/owner/name/pulls/1/files") }
    end
    assert_equal 1, redirect_calls.size
    assert_equal "api.github.com", redirect_calls.first[:host]
  end

  def assert_live_tag_commit_guards
    live = LaneSecurityBump::Live.new("token", "owner/name", OLD_SHA, NEW_SHA, 1, "https://api.github.com", Dir.pwd)
    # Invalid HTTP JSON response body must raise LaneSecurityBump::Error through real get/get_json
    bad_http = Net::HTTPOK.new("1.1", "200", "OK")
    bad_http.define_singleton_method(:body) { "{not json" }
    stub_http([], bad_http) do
      assert_raises(LaneSecurityBump::Error) { live.tag_commit("v1.343.0") }
      assert_raises(LaneSecurityBump::Error) { live.files }
    end
    # Malformed 200 JSON must raise LaneSecurityBump::Error (not KeyError/NoMethodError)
    [{}, { "object" => nil }, { "object" => { "type" => "commit" } }].each do |bad_body|
      live.define_singleton_method(:get_json) { |_path| bad_body }
      assert_raises(LaneSecurityBump::Error) { live.tag_commit("v1.343.0") }
    end
    # Nested annotated tag peeling
    tag_sha1 = "1" * 40
    tag_sha2 = "2" * 40
    live.define_singleton_method(:get_json) do |path|
      case path
      when "/repos/ruby/setup-ruby/git/ref/tags/v1.343.0"
        { "object" => { "type" => "tag", "sha" => tag_sha1 } }
      when "/repos/ruby/setup-ruby/git/tags/#{tag_sha1}"
        { "object" => { "type" => "tag", "sha" => tag_sha2 } }
      when "/repos/ruby/setup-ruby/git/tags/#{tag_sha2}"
        { "object" => { "type" => "commit", "sha" => NEW_SHA } }
      else
        raise "unexpected #{path}"
      end
    end
    assert_equal NEW_SHA, live.tag_commit("v1.343.0")
  end

  def stub_http(calls, response)
    singleton = Net::HTTP.singleton_class
    original = Net::HTTP.method(:start)
    singleton.define_method(:start) do |host, port, **opts, &block|
      http = Object.new
      http.define_singleton_method(:request) do |req|
        calls << { host: host, port: port, opts: opts, request: req }
        response
      end
      block.call(http)
    end
    yield
  ensure
    singleton.define_method(:start, original)
  end

  def assert_base_copy
    script = workflow_run
    Dir.mktmpdir do |dir|
      git_in(dir, "init", "-q")
      FileUtils.mkdir_p(File.join(dir, "tools/lane"))
      script_path = File.join(dir, LaneSecurityBump::SCRIPT)
      File.write(script_path, "puts 'from-base'\n")
      git_in(dir, "add", ".")
      git_in(dir, "-c", "user.email=dev@example.com", "-c", "user.name=dev", "commit", "-q", "-m", "base")
      base_sha, status = Open3.capture2("git", "-C", dir, "rev-parse", "HEAD")
      raise "git rev-parse failed" unless status.success?

      File.write(script_path, "puts 'from-head'\n")
      git_in(dir, "add", ".")
      git_in(dir, "-c", "user.email=dev@example.com", "-c", "user.name=dev", "commit", "-q", "-m", "head")

      event = File.join(dir, "event.json")
      File.write(event, JSON.generate(labeled_event(0)))
      env = {
        "BASE_SHA" => base_sha.strip,
        "GITHUB_EVENT_PATH" => event,
        "RUNNER_TEMP" => dir,
        "PATH" => ENV.fetch("PATH")
      }
      stdout, stderr, wait = Open3.capture3(env, "bash", "-c", script, chdir: dir)
      raise stderr unless wait.success?

      assert_includes stdout, "from-base"
      refute_includes stdout, "from-head"
      refute_includes stdout, PASS
    end
  end

  def assert_shell_missing_unlabeled_and_error
    unlabeled = shell_missing(label: false)
    assert_equal 0, unlabeled[:status]
    assert_equal "", unlabeled[:message]

    broken = shell_missing(event_body: "{not json")
    assert_equal 1, broken[:status]
    assert_equal "#{FAIL_PREFIX}api:0#{FAIL_SUFFIX}", broken[:message]
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
    previous = extras[:previous]
    old_path = previous || path
    patch = unified(base, head)
    {
      "filename" => path,
      "raw_line" => raw_diff_line(path, extras),
      "diff_block" => "diff --git a/#{old_path} b/#{path}\n--- a/#{old_path}\n+++ b/#{path}\n#{patch}",
      "base" => base,
      "head" => head
    }
  end

  def raw_diff_line(path, extras)
    modes = "#{extras.fetch(:old_mode, '100644')} #{extras.fetch(:new_mode, '100644')}"
    previous = extras[:previous]
    case extras.fetch(:status, "modified")
    when "renamed" then ":#{modes} aaaaaaa bbbbbbb R095\t#{previous}\t#{path}\n"
    when "copied" then ":#{modes} aaaaaaa bbbbbbb C095\t#{previous}\t#{path}\n"
    when "added" then ":#{modes} aaaaaaa bbbbbbb A\t#{path}\n"
    when "removed" then ":#{modes} aaaaaaa bbbbbbb D\t#{path}\n"
    else ":#{modes} aaaaaaa bbbbbbb M\t#{path}\n"
    end
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

  def side_version
    before = flow_workflow("with: { ruby-version: '4.0.9', rubygems: '3.5.11' }")
    after = flow_workflow("with: { ruby-version: '4.0.10', rubygems: '3.6.12' }")
    [entry(WF, before, after)]
  end

  def mode_change
    [entry(".ruby-version", "4.0.9\n", "4.0.10\n", { old_mode: "100644", new_mode: "100755" })]
  end

  def reverse_mode_change
    [entry(".ruby-version", "4.0.9\n", "4.0.10\n", { old_mode: "100755", new_mode: "100644" })]
  end

  def cross_context_if
    before = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - name: safe
              if: matrix.ruby == '4.0.9'
              run: echo safe
            - name: release
              run: echo release
    YAML
    after = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - name: safe
              run: echo safe
            - name: release
              if: matrix.ruby == '4.0.10'
              run: echo release
    YAML
    [entry(WF, before, after)]
  end

  def action_with_if
    before = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: other/action@#{OLD_SHA}
              with:
                if: "matrix.ruby == '4.0.9'"
    YAML
    after = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: other/action@#{OLD_SHA}
              with:
                if: "matrix.ruby == '4.0.10'"
    YAML
    [entry(WF, before, after)]
  end

  def duplicate_uses_key
    before = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: ruby/setup-ruby@#{OLD_SHA} # v1.342.0
              with:
                ruby-version: "4.0.9"
              uses: evil/action@#{OLD_SHA}
    YAML
    after = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: ruby/setup-ruby@#{OLD_SHA} # v1.342.0
              with:
                ruby-version: "4.0.10"
              uses: evil/action@#{OLD_SHA}
    YAML
    [entry(WF, before, after)]
  end

  def swapped_test_token
    [
      entry(".ruby-version", "4.0.9\n", "4.0.10\n"),
      entry("test/version_test.rb", "assert_equal \"4.0.9\", pinned # 9.9.9\n",
            "assert_equal \"9.9.9\", pinned # 4.0.10\n")
    ]
  end

  def docker_stage_move
    before = "FROM ruby:4.0 AS build\nARG RUBY_VERSION=4.0.9\nFROM alpine AS runtime\nRUN echo hi\n"
    after = "FROM ruby:4.0 AS build\nFROM alpine AS runtime\nARG RUBY_VERSION=4.0.10\nRUN echo hi\n"
    [entry("Dockerfile", before, after)]
  end

  def docker_continuation
    before = "FROM ruby:4.0\nRUN echo \\\nARG RUBY_VERSION=4.0.9\n"
    after = "FROM ruby:4.0\nRUN echo \\\nARG RUBY_VERSION=4.0.10\n"
    [entry("Dockerfile", before, after)]
  end

  def docker_backtick_continuation
    before = "# escape=`\nFROM ruby:4.0\nRUN echo `\nARG RUBY_VERSION=4.0.9\n"
    after = "# escape=`\nFROM ruby:4.0\nRUN echo `\nARG RUBY_VERSION=4.0.10\n"
    [entry("Dockerfile", before, after)]
  end

  def docker_syntax_and_escape
    before = "# syntax=docker/dockerfile:1\n# escape=`\nFROM ruby:4.0\nRUN echo `\nARG RUBY_VERSION=4.0.9\n"
    after = "# syntax=docker/dockerfile:1\n# escape=`\nFROM ruby:4.0\nRUN echo `\nARG RUBY_VERSION=4.0.10\n"
    [entry("Dockerfile", before, after)]
  end

  def docker_heredoc_arg
    before = "FROM ruby:4.0\nRUN <<EOF\nARG RUBY_VERSION=4.0.9\nEOF\n"
    after = "FROM ruby:4.0\nRUN <<EOF\nARG RUBY_VERSION=4.0.10\nEOF\n"
    [entry("Dockerfile", before, after)]
  end

  def docker_continued_heredoc
    before = "FROM ruby:4.0\nRUN \\\n<<EOF\nARG RUBY_VERSION=4.0.9\nEOF\n"
    after = "FROM ruby:4.0\nRUN \\\n<<EOF\nARG RUBY_VERSION=4.0.10\nEOF\n"
    [entry("Dockerfile", before, after)]
  end

  def docker_comment_change
    before = "FROM ruby:4.0\nARG RUBY_VERSION=latest # 4.0.9\n"
    after = "FROM ruby:4.0\nARG RUBY_VERSION=latest # 4.0.10\n"
    [entry("Dockerfile", before, after)]
  end

  def env_flow_multiline
    before = "name: CI\njobs:\n  test:\n    env: {\n      FOO: bar,\n      if: \"matrix.ruby == '4.0.9'\" }\n"
    after = "name: CI\njobs:\n  test:\n    env: {\n      FOO: bar,\n      if: \"matrix.ruby == '4.0.10'\" }\n"
    [entry(WF, before, after)]
  end

  def action_with_matrix
    before = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: other/action@#{OLD_SHA}
              with:
                strategy:
                  matrix:
                    ruby:
                      - "4.0.9"
    YAML
    after = <<~YAML
      name: CI
      jobs:
        test:
          steps:
            - uses: other/action@#{OLD_SHA}
              with:
                strategy:
                  matrix:
                    ruby:
                      - "4.0.10"
    YAML
    [entry(WF, before, after)]
  end

  def yaml_expression_ruby_version
    before = flow_workflow("with: { ruby-version: \"${{ env.RUBY || '4.0.9' }}\" }")
    after = flow_workflow("with: { ruby-version: \"${{ env.RUBY || '4.0.10' }}\" }")
    [entry(WF, before, after)]
  end

  def workflow_if_string_literal
    before = "name: CI\njobs:\n  test:\n    steps:\n      - if: \"contains(x, '&& matrix.ruby == 4.0.9')\"\n"
    after = "name: CI\njobs:\n  test:\n    steps:\n      - if: \"contains(x, '&& matrix.ruby == 4.0.10')\"\n"
    [entry(WF, before, after)]
  end

  def placeholder_v_collision
    before = flow_workflow("with: { ruby-version: '4.0.9-V' }")
    after = flow_workflow("with: { ruby-version: 'V-4.0.10' }")
    [entry(WF, before, after)]
  end

  def lock_non_ruby_line
    before = "RUBY VERSION\n   ruby 4.0.9p0\n   extra 4.0.9\n\nBUNDLED WITH\n   4.0.8\n"
    after = "RUBY VERSION\n   ruby 4.0.9p0\n   extra 4.0.10\n\nBUNDLED WITH\n   4.0.8\n"
    [entry("Gemfile.lock", before, after)]
  end

  def lock_unindented_section_end
    before = "RUBY VERSION\n   ruby 4.0.9p0\nother-section\n   ruby 4.0.9p0\n"
    after = "RUBY VERSION\n   ruby 4.0.9p0\nother-section\n   ruby 4.0.10p0\n"
    [entry("Gemfile.lock", before, after)]
  end

  def mise_comment_change
    before = "[tools]\nruby = \"latest\" # 4.0.9\n"
    after = "[tools]\nruby = \"latest\" # 4.0.10\n"
    [entry("mise.toml", before, after)]
  end

  def ruby_version_arbitrary_text
    [entry(".ruby-version", "echo 4.0.9\n", "echo 4.0.10\n")]
  end

  def comment_assert_bypass
    [
      entry(".ruby-version", "4.0.9\n", "4.0.10\n"),
      entry("test/version_test.rb", "system(\"curl https://evil/4.0.9\") # assert\n",
            "system(\"curl https://evil/4.0.10\") # assert\n")
    ]
  end

  def nested_call_arg_bypass
    [
      entry(".ruby-version", "4.0.9\n", "4.0.10\n"),
      entry("test/version_test.rb", "assert_equal \"4.0.9\", system(\"curl 4.0.9\")\n",
            "assert_equal \"4.0.9\", system(\"curl 4.0.10\")\n")
    ]
  end

  def heredoc_assertion_bypass
    before = "SCRIPT = <<~SH\n  assert_equal \"4.0.9\", pinned\nSH\n"
    after = "SCRIPT = <<~SH\n  assert_equal \"4.0.10\", pinned\nSH\n"
    [entry(".ruby-version", "4.0.9\n", "4.0.10\n"), entry("test/version_test.rb", before, after)]
  end

  def eof_newline_change
    [entry(".ruby-version", "4.0.9", "4.0.10\n")]
  end

  def shell_missing(label: true, event_body: nil)
    script = workflow_run
    Dir.mktmpdir do |dir|
      git_in(dir, "init", "-q")
      git_in(dir, "-c", "user.email=dev@example.com", "-c", "user.name=dev", "commit", "--allow-empty", "-q", "-m",
             "base")
      sha, status = Open3.capture2("git", "-C", dir, "rev-parse", "HEAD")
      raise "git rev-parse failed" unless status.success?

      event = File.join(dir, "event.json")
      payload = event_body || JSON.generate(
        "pull_request" => { "labels" => label ? [{ "name" => "lane: security-bump" }] : [], "changed_files" => 0 }
      )
      File.write(event, payload)
      env = {
        "BASE_SHA" => sha.strip,
        "GITHUB_EVENT_PATH" => event,
        "RUNNER_TEMP" => dir,
        "PATH" => ENV.fetch("PATH"),
        "HOME" => Dir.home
      }
      stdout, stderr, wait = Open3.capture3(env, "bash", "-c", script, chdir: dir)
      raise stderr unless wait.exited?

      { lane: false, status: wait.exitstatus, message: stdout.strip }
    end
  end

  def workflow_run
    text = File.read(File.join(ROOT, LaneSecurityBump::WORKFLOW))
    document = YAML.safe_load(text)
    steps = document.dig("jobs", "security-bump-lane", "steps")
    steps.find { |step| step["name"] == "Check security-bump lane" }.fetch("run")
  end

  def git_in(dir, *args)
    _stdout, status = Open3.capture2("git", "-C", dir, *args)
    raise "git #{args.first} failed" unless status.success?
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
      entry("mise.toml", "[tools]\nruby = \"4.0.9\"\n", "[tools]\nruby = \"4.0.10\"\n"),
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
    def initialize(entries, tags, api_files: nil, raw_api_files: nil)
      @entries = entries
      @tags = tags
      @api_files = api_files
      @raw_api_files = raw_api_files
    end

    def files
      return @raw_api_files unless @raw_api_files.nil?

      parse_entries(@api_files || @entries).first
    end

    def changes
      parsed.first
    end

    def modes
      parsed.last
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

    private

    def parsed
      @parsed ||= parse_entries(@entries)
    end

    def parse_entries(list)
      raw_text = list.map { |item| item.fetch("raw_line") }.join
      diff_text = list.map { |item| item.fetch("diff_block") }.join
      LaneSecurityBump.parse_changes(raw_text, diff_text)
    end
  end

  class RaisingClient
    def files
      raise LaneSecurityBump::Error, "api"
    end

    def changes
      raise LaneSecurityBump::Error, "api"
    end

    def contents(*)
      raise "contents"
    end

    def tag_commit(*)
      raise "tag"
    end

    def modes
      raise "modes"
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
