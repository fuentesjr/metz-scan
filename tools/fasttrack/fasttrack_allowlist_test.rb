# frozen_string_literal: true

require "digest"
require "json"
require "minitest/autorun"
require "net/http"
require "open3"
require "rbconfig"
require "timeout"
require "tmpdir"

require_relative "fasttrack_allowlist"

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
# rubocop:disable Metz/ClassesTooLong, Metz/MethodsTooLong
class FasttrackAllowlistTest < Minitest::Test
  REPO = "fuentesjr/metz-scan"
  BASE_SHA = "a" * 40
  HEAD_SHA = "b" * 40
  OTHER_SHA = "c" * 40
  NOW = "2026-11-11T22:22:00Z"
  EXCLUDES = %w[
    README.md
    docs/project-analyzer-calibration.md
    docs/calibration/**
    docs/design-decision-records.md
    docs/spikes/sorbet-issue-26.md
    docs/releases/**
    docs/dogfooding/**
  ].freeze
  FORBIDDEN_NAME_DIGESTS = %w[
    340d6bb972c2bc1eb7e627ff505ae4fa90c8de05ea0c9903da7c161942b13cec
    9e723cd7deba9f7dbccd96630aeaf48224249a38ceb11b4d9210c2f8ab1b3762
    8d32e2062d706708fb26c9a5bae5d5f3e8dc03c12a53c23da39a8aa00f4d2cda
    6cb784e0f985cba22d0642283892ad0f90dcd48385524de0dec0f51624456a43
    6b4d3473e1982fd2e7bdf29615897fe2301e807da6f70a3bd6f4067dba802391
  ].freeze
  CLEAN_PATCH = "@@ -1 +1 @@\n-old note\n+A short handbook note.\n"
  ROOT = File.expand_path("../..", __dir__)

  def test_clearance_cases
    cases = JSON.parse(File.read(fixture_path))
    assert_equal 13, cases.size
    assert_equal((1..13).to_a, cases.map { |row| row.fetch("id") })
    assert_equal EXCLUDES, allowlist.fetch("docs_exclude")
    assert_equal Fasttrack::GUARDS, allowlist.fetch("guard_paths")
    assert_equal Fasttrack::PHRASES, allowlist.fetch("never_clear")
    refute_includes File.read(fixture_path), control_path
    refute_includes File.read(__FILE__), control_path
    words = File.read(fixture_path).downcase.scan(/[a-z][a-z-]*/)
    digests = words.flat_map { |word| name_digests(word) }
    assert_empty(digests & FORBIDDEN_NAME_DIGESTS)
    cases.each do |row|
      assert_equal REPO, row.fetch("repo")
      assert_case(row)
    end
    assert_live_fields_win
  end

  def test_missing_token_exits_one
    stdout, status = run_script(child_env)
    assert_equal 1, status.exitstatus
    assert_equal "not cleared: token\n", stdout
  end

  def test_missing_event_exits_one
    Dir.mktmpdir do |dir|
      env = child_env
      env["GITHUB_TOKEN"] = "dummy-token"
      env["GITHUB_EVENT_PATH"] = File.join(dir, "missing-event.json")
      stdout, status = run_script(env)
      assert_equal 1, status.exitstatus
      assert_equal "not cleared: error\n", stdout
    end
  end

  private

  def assert_case(row)
    case row.fetch("kind")
    when "decide" then assert_decide(row)
    when "http" then assert_http(row)
    when "static" then assert_static(row)
    when "cli" then assert_cli(row)
    else flunk(row.fetch("kind"))
    end
  end

  def assert_decide(row)
    row.fetch("variants").each do |variant|
      code, summary = Fasttrack.report(decide_input(variant))
      expect = variant["expect"] || row.fetch("expect")
      assert_equal expect, summary, variant.inspect
      refute_equal 0, code
    end
  end

  def assert_http(row)
    row.fetch("variants").each do |variant|
      code, summary = http_result(variant)
      assert_equal variant.fetch("expect"), summary, variant.inspect
      refute_equal 0, code
    end
  end

  def assert_static(row)
    workflow = File.read(workflow_path)
    allow = File.read(allowlist_path)
    assert Fasttrack.static_ok?(workflow, allow), "shipped workflow and allowlist"
    row.fetch("rules").each { |rule| refute_static(rule, workflow, allow) }
  end

  def refute_static(rule, workflow, allow)
    broken_workflow, broken_allow = apply_break(rule, workflow, allow)
    refute Fasttrack.static_ok?(broken_workflow, broken_allow), rule.fetch("name")
  end

  def apply_break(rule, workflow, allow)
    source = rule.fetch("file") == "workflow" ? workflow : allow
    from = rule.fetch("from")
    flunk("breakage missing #{rule.fetch('name')}") unless source.include?(from)
    changed = source.sub(from, rule.fetch("to"))
    rule.fetch("file") == "workflow" ? [changed, allow] : [workflow, changed]
  end

  def assert_cli(_row)
    saved = ARGV.dup
    ARGV.clear
    Dir.mktmpdir do |dir|
      event = File.join(dir, "event.json")
      File.write(event, JSON.generate(cli_event))
      code, summary = nil
      with_http("fault" => "clear") { code, summary = Fasttrack.run_cli(cli_env(event)) }
      assert_equal "cleared: docs", summary
      assert_equal 0, code
    end
  ensure
    ARGV.replace(saved)
  end

  def http_result(variant)
    code = nil
    summary = nil
    with_http(variant) do
      client = Fasttrack::GithubClient.new("dummy-token", REPO, "http://127.0.0.1:9")
      client.bind(4815, BASE_SHA, HEAD_SHA)
      code, summary = Fasttrack.report(decide_input({}), client: client)
    end
    [code, summary]
  end

  def with_http(script)
    @http_script = script
    @http_pulls = 0
    original = Net::HTTP.method(:start)
    test = self
    Net::HTTP.define_singleton_method(:start) do |*_args, **_kwargs, &block|
      http = Object.new
      http.define_singleton_method(:request) { |request| test.__send__(:serve, request) }
      block.call(http)
    end
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  def serve(request)
    fault = @http_script["fault"]
    raise Timeout::Error, "timeout" if fault == "timeout"
    raise "injected" if fault == "exception"
    return http_response(@http_script.fetch("status"), { "message" => "no" }) if fault == "status"

    path = request.path.to_s
    return blob_response if path.include?("/git/blobs/")
    return tree_response if path.include?("/git/trees/")
    return files_response if path.include?("/files")
    return pull_response if path.include?("/pulls/")

    raise "unexpected #{path}"
  end

  def pull_response
    @http_pulls += 1
    http_response(200, pull_body(head_sha_for_pull))
  end

  def head_sha_for_pull
    fault = @http_script["fault"]
    return OTHER_SHA if fault == "head-first"
    return OTHER_SHA if fault == "head-second" && @http_pulls > 1

    HEAD_SHA
  end

  def files_response
    http_response(200, [{
                    "filename" => control_path,
                    "status" => "added",
                    "patch" => http_patch
                  }])
  end

  def http_patch
    return bad_patch if @http_script["fault"] == "truncated-patch"
    return nil if @http_script["fault"] == "truncated" && !@http_script["patch"]

    CLEAN_PATCH
  end

  def bad_patch
    "@@ -1 +1 @@\n+A short handbook note.\nnot a diff line\n"
  end

  def tree_response
    http_response(200, {
                    "truncated" => @http_script["fault"] == "truncated",
                    "tree" => [{
                      "path" => control_path,
                      "mode" => "100644",
                      "type" => "blob",
                      "sha" => "d" * 40
                    }]
                  })
  end

  def blob_response
    http_response(200, { "encoding" => "base64", "content" => ["hello\n"].pack("m0") })
  end

  def pull_body(sha)
    script = @http_script || {}
    labels = script["labels"] || []
    {
      "head" => { "sha" => sha, "repo" => { "fork" => false, "full_name" => REPO } },
      "user" => { "login" => script["user_login"] || "octocat", "id" => script["user_id"] || 1 },
      "base" => { "repo" => { "full_name" => REPO }, "sha" => BASE_SHA },
      "labels" => labels.map { |name| { "name" => name } }
    }
  end

  def http_response(code, payload)
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s).new("1.1", code.to_s, "status")
    response.instance_variable_set(:@read, true)
    response.body = payload.is_a?(String) ? payload : JSON.generate(payload)
    response
  end

  def decide_input(variant)
    data = materialize(variant)
    pull = clearing_pull.merge(data["pull"] || {})
    pull["head_sha"] ||= HEAD_SHA
    {
      "now" => NOW,
      "allow_repo" => allowlist.fetch("repo"),
      "docs_exclude" => allowlist.fetch("docs_exclude"),
      "guard_paths" => allowlist.fetch("guard_paths"),
      "never_clear" => allowlist.fetch("never_clear"),
      "event" => event_hash,
      "pull" => pull,
      "pull_after" => pull,
      "files" => data["files"] || [],
      "tree" => data["tree"] || []
    }
  end

  def materialize(value)
    case value
    when Hash then value.transform_values { |child| materialize(child) }
    when Array then value.map { |child| materialize(child) }
    when "control" then control_path
    else value
    end
  end

  def clearing_pull
    { "user_login" => "octocat", "user_id" => 1, "labels" => [] }
  end

  def event_hash
    { "repo" => REPO, "number" => 4815, "base_sha" => BASE_SHA, "head_sha" => HEAD_SHA }
  end

  def cli_event
    {
      "repository" => { "full_name" => REPO },
      "pull_request" => {
        "number" => 4815,
        "base" => { "sha" => BASE_SHA },
        "head" => { "sha" => HEAD_SHA },
        "user" => { "login" => "octocat", "id" => 1 },
        "labels" => []
      }
    }
  end

  def assert_live_fields_win
    saved = ARGV.dup
    ARGV.clear
    Dir.mktmpdir do |dir|
      event = File.join(dir, "event.json")
      File.write(event, JSON.generate(cli_event))
      assert_equal "not cleared: docs label", live_summary(event, "labels" => ["risk: high"])
      author = live_summary(event, "user_login" => "dependabot[bot]", "user_id" => 49_699_333)
      assert_equal "not cleared: docs author", author
    end
  ensure
    ARGV.replace(saved)
  end

  def live_summary(event, script)
    with_http({ "fault" => "clear" }.merge(script)) do
      _code, summary = Fasttrack.run_cli(cli_env(event))
      summary
    end
  end

  def child_env
    env = ENV.to_h
    env.delete("GITHUB_TOKEN")
    env.delete("GH_TOKEN")
    env.delete("GITHUB_STEP_SUMMARY")
    env
  end

  def run_script(env)
    stdout, _stderr, status = Open3.capture3(env, RbConfig.ruby, script_path)
    [stdout, status]
  end

  def cli_env(event_path)
    env = ENV.to_h
    env["GITHUB_TOKEN"] = "dummy-token"
    env["GITHUB_EVENT_PATH"] = event_path
    env["GITHUB_API_URL"] = "http://127.0.0.1:9"
    env.delete("GITHUB_STEP_SUMMARY")
    env
  end

  def control_path
    ["docs", "clearance-plain-note.md"].join("/")
  end

  def allowlist
    @allowlist ||= Fasttrack.load_allowlist || flunk("allowlist did not load")
  end

  def fixture_path
    File.join(__dir__, "fixtures", "cases.json")
  end

  def name_digests(word)
    parts = word.split("-")
    pairs = parts.each_cons(2).map { |left, right| "#{left}-#{right}" }
    [word, *parts, *pairs].map { |name| Digest::SHA256.hexdigest(name) }
  end

  def script_path
    File.join(__dir__, "fasttrack_allowlist.rb")
  end

  def workflow_path
    File.join(ROOT, ".github", "workflows", "fasttrack-allowlist.yml")
  end

  def allowlist_path
    File.join(__dir__, "allowlist.yml")
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
# rubocop:enable Metz/ClassesTooLong, Metz/MethodsTooLong
