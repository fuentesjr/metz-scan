# frozen_string_literal: true
# rubocop:disable all
require "json"
require "net/http"
require "time"
require "uri"
require "yaml"
# Docs is the only class. The command line reads the allowlist from disk.
# Nothing in the environment, the arguments, or a repo variable turns another class on.
module Fasttrack
  class ApiError < StandardError; end
  REPO = "fuentesjr/metz-scan"
  DEPENDABOT_LOGIN = "dependabot[bot]"
  DEPENDABOT_ID = 49699333
  GUARDS = [
    ".github/workflows/fasttrack-allowlist.yml",
    "tools/fasttrack/fasttrack_allowlist.rb",
    "tools/fasttrack/allowlist.yml",
    "tools/fasttrack/fasttrack_allowlist_test.rb",
    "tools/fasttrack/fixtures",
  ].freeze
  PHRASES = [
    "permissions:", "on:", "pull_request_target", "workflow_run", "secrets.",
    "GITHUB_TOKEN", "id-token", "persist-credentials", "run:", "env:", "if:", "with:", "token",
  ].freeze
  BIDI = [
    "\u202A", "\u202B", "\u202C", "\u202D", "\u202E", "\u2066", "\u2067", "\u2068", "\u2069",
    "\u200E", "\u200F", "\u200B", "\u200C", "\u200D", "\uFEFF", "\u2060",
  ].freeze
  module_function
  def report(input, client: nil)
    summary = decide(input, client: client)
    [summary.start_with?("cleared:") ? 0 : 1, summary]
  rescue ApiError
    [1, "not cleared: api error"]
  rescue StandardError
    [1, "not cleared: error"]
  end
  def decide(input, client: nil)
    client ||= FixtureClient.new(input)
    now = parse_time(input["now"])
    return problem("error") if now.nil? || input["allow_repo"] != REPO
    return problem("repo") if input.dig("event", "repo") != REPO
    return problem("error") unless sha?(input.dig("event", "head_sha")) && sha?(input.dig("event", "base_sha"))
    pull = client.pull
    return problem("api error") if pull.nil?
    return problem("head moved") if pull["head_sha"] != input.dig("event", "head_sha")
    files = client.files
    return problem("api error") if files.nil?
    return problem("file count") if files.size > 300
    files.each do |file|
      hit = status_problem(file)
      return problem(hit) if hit
      delta = changed_delta(file["patch"])
      return problem("truncated patch") if delta.nil?
      hit = text_problem(delta)
      return problem(hit) if hit
    end
    return problem("workflow") if files.any? { |file| workflow_file?(file["filename"]) || workflow_file?(file["previous_filename"].to_s) }
    guards = GUARDS | Array(input["guard_paths"])
    return problem("guard path") if files.any? { |file| guarded?(file, guards) }
    phrases = PHRASES | Array(input["never_clear"])
    files.each do |file|
      added, removed = changed_delta(file["patch"])
      return problem("never-clear") if (added + removed).any? { |line| phrases.any? { |phrase| line.include?(phrase) } }
    end
    summary = class_summary(input, files, client, now, pull)
    again = client.pull
    return problem("head moved") if summary.start_with?("cleared:") && again["head_sha"] != input.dig("event", "head_sha")
    summary
  end
  def static_ok?(workflow_text, allow_text)
    workflow_ok?(workflow_text) && switches_off?(allow_text)
  end
  def workflow_ok?(text)
    doc = YAML.safe_load(text, aliases: false)
    return false unless doc.is_a?(Hash)
    return false if forbidden_key?(doc)
    return false if doc.key?("on") && doc.key?(true)
    trigger = doc.key?("on") ? doc["on"] : doc[true]
    return false unless trigger.is_a?(Hash) && trigger.keys == ["pull_request"]
    pull_request = trigger["pull_request"]
    return false unless pull_request.is_a?(Hash)
    return false unless pull_request["types"] == %w[opened synchronize reopened labeled unlabeled]
    return false unless doc["permissions"] == { "contents" => "read", "pull-requests" => "read" }
    jobs = doc["jobs"]
    return false unless jobs.is_a?(Hash) && jobs.keys == ["fasttrack-allowlist"]
    job = jobs["fasttrack-allowlist"]
    return false unless job.is_a?(Hash) && !job.key?("permissions")
    return false unless job["if"] == "contains(github.event.pull_request.labels.*.name, 'fast-track')"
    steps = job["steps"]
    return false unless steps.is_a?(Array)
    checks = steps.select { |step| step.is_a?(Hash) && step["uses"].to_s.start_with?("actions/checkout@") }
    return false if checks.empty?
    script = steps.find { |step| step.is_a?(Hash) && step["run"].to_s.include?("fasttrack_allowlist.rb") }
    return false unless script.is_a?(Hash) && script.dig("env", "GITHUB_TOKEN") == "${{ github.token }}"
    checks.all? do |step|
      with = step["with"]
      with.is_a?(Hash) && with["ref"] == "${{ github.event.pull_request.base.sha }}" && with["persist-credentials"] == false
    end
  rescue StandardError
    false
  end
  def switches_off?(text)
    doc = YAML.safe_load(text, aliases: false)
    doc.is_a?(Hash) && !doc.key?("pins") && !doc.key?("lockfiles") && doc["repo"] == REPO
  rescue StandardError
    false
  end
  def run_cli(env = ENV)
    return [1, "not cleared: error"] unless ARGV.empty?
    allow = load_allowlist
    return [1, "not cleared: error"] if allow.nil?
    input = live_input(env, allow)
    report(input, client: input.delete("client"))
  rescue ApiError => error
    [1, error.message == "token" ? "not cleared: token" : "not cleared: api error"]
  end
  def load_allowlist
    data = YAML.safe_load(File.read(File.join(__dir__, "allowlist.yml")), aliases: false)
    return nil unless data.is_a?(Hash) && data["repo"] == REPO
    return nil if data.key?("pins") || data.key?("lockfiles")
    return nil unless data["docs_exclude"].is_a?(Array) && data["never_clear"].is_a?(Array)
    data
  rescue StandardError
    nil
  end
  def live_input(env, allow)
    token = env["GITHUB_TOKEN"].to_s
    raise ApiError, "token" if token.empty?
    event = JSON.parse(File.read(env.fetch("GITHUB_EVENT_PATH")))
    repo = event.dig("repository", "full_name")
    pr = event["pull_request"] || {}
    raise ApiError, "event" if repo != REPO || pr["number"].nil?
    client = GithubClient.new(token, repo, env["GITHUB_API_URL"] || "https://api.github.com")
    client.bind(pr["number"], pr.dig("base", "sha"), pr.dig("head", "sha"))
    {
      "now" => Time.now.utc.iso8601,
      "allow_repo" => allow["repo"],
      "docs_exclude" => allow["docs_exclude"],
      "guard_paths" => allow["guard_paths"],
      "never_clear" => allow["never_clear"],
      "event" => {
        "repo" => repo,
        "number" => pr["number"],
        "base_sha" => pr.dig("base", "sha"),
        "head_sha" => pr.dig("head", "sha"),
      },
      "client" => client,
    }
  end
  def class_summary(input, files, client, _now, pull)
    return problem("outside class") if files.empty?
    return docs_summary(input, files, pull, client) if files.all? { |file| docs_path?(file["filename"]) }
    problem("outside class")
  end
  def docs_summary(input, files, pull, client)
    return problem("outside class") unless files.all? { |file| file["status"] == "added" || file["status"] == "modified" }
    excludes = input["docs_exclude"]
    return problem("error") unless excludes.is_a?(Array)
    return problem("docs exclude") if files.any? { |file| excluded?(file["filename"], excludes) }
    tree = client.base_tree
    return problem("error") if tree.nil?
    return problem("docs reference") if files.any? { |file| referenced?(file["filename"], tree) }
    return problem("docs author") if dependabot?(pull)
    return problem("docs label") if risk_above_low?(pull["labels"])
    "cleared: docs"
  end
  def status_problem(file)
    status = file["status"]
    previous = file["previous_filename"]
    return "rename" if status == "renamed" || (previous.is_a?(String) && !previous.empty?)
    return "copy" if status == "copied"
    return "delete" if status == "removed"
    return "symlink" if file["new_mode"] == "120000" || file["type"] == "symlink"
    return "submodule" if file["new_mode"] == "160000" || file["type"] == "submodule" || file["type"] == "commit"
    return "binary" if file["binary"] == true
    return "mode" if file["new_mode"] != "100644"
    return "mode" if file["old_mode"] && file["old_mode"] != file["new_mode"]
    nil
  end
  def text_problem(delta)
    added, removed = delta
    return "bidi" if added.any? { |line| bidi?(line) }
    changed = added + removed
    return "line ending" if changed.any? { |line| line.include?("\r") }
    return "tab" if changed.any? { |line| line.include?("\t") }
    return "non-ascii" unless changed.all? { |line| ascii?(line) }
    nil
  end
  def changed_delta(patch)
    return nil unless patch.is_a?(String) && !patch.empty?
    added = []
    removed = []
    patch.each_line do |raw|
      body = raw.delete_suffix("\n")
      next if body.start_with?("@@", "\\")
      if body.start_with?("+")
        added << body[1..]
      elsif body.start_with?("-")
        removed << body[1..]
      elsif body.start_with?(" ") || body.empty?
        next
      else
        return nil
      end
    end
    [added, removed]
  end
  def docs_path?(path)
    return false if path.nil? || path.empty? || path.include?("\\") || path.start_with?("/")
    parts = path.split("/")
    return false if parts.any? { |part| part.empty? || part == "." || part == ".." || part.start_with?(".") }
    return true if path == "README.md"
    parts.length >= 2 && parts[0] == "docs" && path.end_with?(".md")
  end
  def workflow_file?(path)
    path.start_with?(".github/workflows/") && (path.end_with?(".yml") || path.end_with?(".yaml"))
  end
  def excluded?(path, patterns)
    patterns.any? do |pattern|
      if pattern.end_with?("/**")
        root = pattern.delete_suffix("/**")
        path == root || path.start_with?("#{root}/")
      else
        path == pattern
      end
    end
  end
  def referenced?(path, tree)
    needle = path.b
    tree.any? do |entry|
      name = entry["path"]
      next false unless reference_scan?(name)
      entry["text"].to_s.b.include?(needle)
    end
  end
  def reference_scan?(name)
    return true if name == "AGENTS.md" || name == "CLAUDE.md"
    return true if [".agents/", ".cursor/", ".claude/", ".github/"].any? { |prefix| name.start_with?(prefix) }
    !name.end_with?(".md")
  end
  def dependabot?(pull)
    pull["user_login"] == DEPENDABOT_LOGIN || pull["user_id"] == DEPENDABOT_ID
  end
  def risk_above_low?(labels)
    Array(labels).any? do |label|
      prefix, level = label.to_s.split(":", 2)
      next false unless prefix&.downcase == "risk"
      level.to_s.strip.downcase != "low"
    end
  end
  def parse_time(value)
    return nil if value.nil?
    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
  def sha?(value)
    value.is_a?(String) && value.length == 40 && value.each_char.all? { |char| hex_char?(char) }
  end
  def hex_char?(char)
    (char >= "0" && char <= "9") || (char >= "a" && char <= "f")
  end
  def ascii?(line)
    line.each_byte.all? { |byte| byte < 128 }
  end
  def bidi?(line)
    BIDI.any? { |char| line.include?(char) }
  end
  def indent_of(line)
    count = 0
    line.each_char do |char|
      break unless char == " "
      count += 1
    end
    count
  end
  def guarded?(file, guards)
    [file["filename"], file["previous_filename"]].any? { |name| guard_path?(name, guards) }
  end
  def guard_path?(name, guards)
    return false if !name.is_a?(String) || name.empty?
    guards.any? { |guard| name == guard || name.start_with?("#{guard}/") }
  end
  def problem(rule)
    "not cleared: #{rule}"
  end
  def forbidden_key?(object)
    case object
    when Hash
      object.any? { |key, value| key.to_s == "pull_request_target" || key.to_s == "workflow_run" || forbidden_key?(value) }
    when Array
      object.any? { |value| forbidden_key?(value) }
    else
      false
    end
  end
  class FixtureClient
    def initialize(input)
      @input = input
      @pulls = 0
    end
    def pull
      rows = [@input["pull"], @input["pull_after"]].compact
      row = rows[@pulls] || rows.last
      @pulls += 1
      row
    end
    def files = @input["files"]
    def base_tree = @input["tree"]
    def look(key, id)
      @input.fetch(key, {})[id]
    end
  end
  class GithubClient
    def initialize(token, repo, api)
      @token = token
      @repo = repo
      @api = api.sub(%r{/\z}, "")
      @trees = {}
    end
    def bind(number, base_sha, head_sha)
      @number = number
      @base_sha = base_sha
      @head_sha = head_sha
      self
    end
    def pull
      data = json("/repos/#{@repo}/pulls/#{@number}")
      raise ApiError if data.nil?
      {
        "head_sha" => data.dig("head", "sha"), "user_login" => data.dig("user", "login"),
        "user_id" => data.dig("user", "id"), "fork" => data.dig("head", "repo", "fork") == true,
        "head_repo" => data.dig("head", "repo", "full_name"), "base_repo" => data.dig("base", "repo", "full_name"),
        "labels" => Array(data["labels"]).map { |label| label["name"] },
      }
    end
    def files
      raise ApiError if @base_sha.nil?
      paginate("/repos/#{@repo}/pulls/#{@number}/files?per_page=100").map { |row| normalize(row) }
    end
    def base_tree = Fasttrack.read_tree(Dir.pwd)
    def normalize(row)
      path = row["filename"]
      old = tree(@base_sha)[row["previous_filename"] || path]
      entry = tree(@head_sha)[path]
      file = {
        "filename" => path, "status" => row["status"], "previous_filename" => row["previous_filename"],
        "patch" => row["patch"], "old_mode" => old && old["mode"], "new_mode" => entry && entry["mode"],
        "type" => entry && entry["type"], "binary" => false,
      }
      if file["patch"].nil? && entry && entry["type"] == "blob"
        raw = decode(json("/repos/#{@repo}/git/blobs/#{entry["sha"]}"))
        file["binary"] = raw.nil? || raw.include?("\0") || !raw.dup.force_encoding("UTF-8").valid_encoding?
      end
      file["type"] = "symlink" if file["new_mode"] == "120000"
      file["type"] = "submodule" if file["new_mode"] == "160000" || file["type"] == "commit"
      file
    end
    def decode(data)
      return nil if data.nil? || data["encoding"] != "base64"
      decoded = data["content"].to_s.delete("\n").unpack1("m")
      return nil if decoded.nil?
      decoded.force_encoding("UTF-8")
    end
    def tree(sha)
      @trees[sha] ||= begin
        data = json("/repos/#{@repo}/git/trees/#{sha}?recursive=1")
        raise ApiError if data.nil? || data["truncated"]
        Array(data["tree"]).to_h { |entry| [entry["path"], entry] }
      end
    end
    def paginate(path)
      items = []
      url = path
      5.times do
        data, nxt = request(url.start_with?("http") ? URI(url) : URI("#{@api}#{url}"), true)
        raise ApiError if data.nil? || !data.is_a?(Array)
        items.concat(data)
        return items if nxt.nil? || items.size > 300
        url = nxt
      end
      raise ApiError
    end
    def json(path)
      data, = request(URI("#{@api}#{path}"), true)
      data
    end
    def request(uri, auth)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["User-Agent"] = "metz-scan-fasttrack"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["Authorization"] = "Bearer #{@token}" if auth
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 10) { |http| http.request(request) }
      return [nil, nil] if response.code == "404"
      raise ApiError unless response.is_a?(Net::HTTPSuccess)
      [JSON.parse(response.body), next_link(response["link"])]
    rescue Timeout::Error, SocketError, SystemCallError, JSON::ParserError
      raise ApiError
    end
    def next_link(header)
      return nil if header.nil?
      header.split(",").each do |part|
        link, rel = part.split(";", 2)
        next unless rel&.include?("next")
        found = link&.match(/<([^>]+)>/)
        return found[1] if found
      end
      nil
    end
  end
  def read_tree(root)
    output = IO.popen(["git", "-C", root, "ls-files", "-z"], err: File::NULL, &:read)
    return nil unless $?.success?
    output.split("\0").filter_map do |path|
      next if path.empty?
      full = File.join(root, path)
      info = File.lstat(full)
      next unless info.file?
      { "path" => path, "text" => File.binread(full) }
    end
  rescue StandardError
    nil
  end
end
if $PROGRAM_NAME == __FILE__
  code = 1
  summary = "not cleared: error"
  begin
    code, summary = Fasttrack.run_cli
  rescue StandardError
    code = 1
    summary = "not cleared: error"
  end
  $stdout.puts(summary)
  step = ENV["GITHUB_STEP_SUMMARY"]
  File.write(step, "#{summary}\n") if step.is_a?(String) && !step.empty?
  exit code
end
