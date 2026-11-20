# frozen_string_literal: true
# rubocop:disable all

require "json"
require "net/http"
require "open3"
require "psych"
require "uri"

# One file: the workflow loads this path from the base commit with git show.
module LaneSecurityBump
  Error = Class.new(StandardError)
  LABEL = "lane: security-bump"
  SCRIPT = "tools/lane/security_bump.rb"
  WORKFLOW = ".github/workflows/security-bump-lane.yml"
  PASS = "security-bump lane: version strings only"
  GUARDED = [SCRIPT, WORKFLOW].freeze
  VERSION_TOKEN = /(?<![\w.])\d+\.\d+\.\d+(?:p\d+|[-.](?:preview|rc|beta|alpha)\d+)?(?![\w.])/
  SHA_TOKEN = /(?<![0-9a-f])[0-9a-f]{40}(?![0-9a-f])/
  USES_LINE = /\A\s*-?\s*uses:\s*ruby\/setup-ruby@([0-9a-f]{40})\s+#\s*v(\d+\.\d+\.\d+)\s*\z/
  MISE_LINE = /\A\s*(?:ruby|"ruby"|'ruby')\s*=\s*(?:(["'])[^"']+\1|\S+)\s*(?:#.*)?\z/
  DOCKER_LINE = /\A\s*ARG\s+(?:RUBY_VERSION|RUBY_VER|ruby(?:_version|_ver)?)\s*=\s*(?:(["'])[^"']+\1|\S+)\s*(?:#.*)?\z/i
  HUNK = /\A@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/
  MATRIX_RUBY = /matrix\.ruby(?![\w.])|matrix\s*\[\s*['"]ruby['"]\s*\]/
  COMPARE = /==|!=|>=|<=|>|</
  ASSERTION = /\b(?:assert(?:_[A-Za-z0-9_]+)?|refute(?:_[A-Za-z0-9_]+)?|expect)\b/
  SETUP_PREFIX = "ruby/setup-ruby@"
  BLOCK_STYLES = [4, 5].freeze

  module_function

  def lane_security_bump?(event, client:)
    check(event, client: client)[:lane]
  end

  def check(event, client:)
    request = pull_request(event)
    return noop unless labeled?(request)
    listed = client.files
    changed = request["changed_files"]
    return fail_at("files:0") unless listed.is_a?(Array) && changed.is_a?(Integer) && listed.size == changed
    return fail_at("files:0") unless listed.all? { |file| file.is_a?(Hash) && file["filename"].is_a?(String) }
    names = listed.map { |file| file["filename"] }
    return fail_at("files:0") unless names.uniq.size == names.size
    judge(listed, client) || pass
  rescue Error
    fail_at("api:0")
  end

  def run(env = ENV)
    event = JSON.parse(File.read(env.fetch("GITHUB_EVENT_PATH")))
    request = event["pull_request"]
    raise Error unless request.is_a?(Hash)
    return [0, ""] unless labeled?(request)
    result = check(event, client: Live.build(env, event))
    [result[:status], result[:message]]
  rescue Error, JSON::ParserError, Errno::ENOENT, KeyError
    [1, fail_at("api:0")[:message]]
  end

  def pull_request(event)
    request = event.is_a?(Hash) ? event["pull_request"] : nil
    request.is_a?(Hash) ? request : {}
  end

  def labeled?(request)
    Array(request["labels"]).any? { |label| label_name(label) == LABEL }
  end

  def label_name(label)
    label.is_a?(Hash) ? label["name"] : label
  end

  def pass
    { lane: true, status: 0, message: PASS }
  end

  def noop
    { lane: false, status: 0, message: "" }
  end

  def fail_at(place)
    {
      lane: false,
      status: 1,
      message: "lane: security-bump label on a PR that changes more than version strings: " \
               "#{place}. Remove the label so the normal gates run, or split the version bump into its own PR."
    }
  end

  def judge(files, client)
    introduced = []
    others, tests = files.partition { |file| place(file["filename"]) != :test }
    others.each do |file|
      problem = inspect_file(file, client, introduced, collect: true)
      return problem if problem
    end
    tests.each do |file|
      problem = inspect_file(file, client, introduced, collect: false)
      return problem if problem
    end
    nil
  end

  def inspect_file(file, client, introduced, collect:)
    return fail_line(file, blame(file)) if guarded?(file) || !modified_file?(file)
    return fail_line(file, 1) unless safe_path?(file["filename"])
    base = client.contents("base", file["filename"])
    head = client.contents("head", file["filename"])
    return fail_line(file, blame(file)) unless base.is_a?(String) && head.is_a?(String)
    case place(file["filename"])
    when :ruby_version then version_pairs(file, base, head, introduced, collect)
    when :mise then pattern_pairs(file, base, head, MISE_LINE, introduced, collect)
    when :docker then pattern_pairs(file, base, head, DOCKER_LINE, introduced, collect)
    when :lock then lock_pairs(file, base, head, introduced, collect)
    when :workflow then workflow_pairs(file, base, head, client, introduced, collect)
    when :test then test_pairs(file, base, head, introduced)
    else fail_line(file, blame(file))
    end
  end

  def guarded?(file)
    [file["filename"], file["previous_filename"]].compact.any? { |name| GUARDED.include?(name) }
  end

  def modified_file?(file)
    file["status"] == "modified" && file["patch"].is_a?(String) && !file["patch"].empty? && blank?(file["previous_filename"])
  end

  def blank?(value)
    value.nil? || value == ""
  end

  def safe_path?(path)
    path.is_a?(String) && path.match?(/\A[A-Za-z0-9._\/-]+\z/) && !path.include?("..") && !path.start_with?("/")
  end

  def place(path)
    return :ruby_version if path == ".ruby-version"
    return :mise if path == "mise.toml"
    return :docker if path == "Dockerfile"
    return :lock if path == "Gemfile.lock"
    return :workflow if path.match?(%r{\A\.github/workflows/[^/]+\.ya?ml\z})
    return :test if path.match?(%r{(?:\A|/)test/})
    :other
  end

  def version_pairs(file, base, head, introduced, collect)
    each_problem(file) do |removed, added|
      if aligned?(base, removed) && aligned?(head, added) && same_version?(removed, added, uses: false)
        introduced.concat(fresh_tokens(removed[:text], added[:text])) if collect
        nil
      else
        fail_line(file, added[:line])
      end
    end
  end

  def pattern_pairs(file, base, head, regex, introduced, collect)
    each_problem(file) do |removed, added|
      ok = aligned?(base, removed) && aligned?(head, added) &&
           regex.match?(removed[:text]) && regex.match?(added[:text]) &&
           same_version?(removed, added, uses: false)
      if ok
        introduced.concat(fresh_tokens(removed[:text], added[:text])) if collect
        nil
      else
        fail_line(file, added[:line])
      end
    end
  end

  def lock_pairs(file, base, head, introduced, collect)
    base_lines = lock_lines(base)
    head_lines = lock_lines(head)
    each_problem(file) do |removed, added|
      ok = aligned?(base, removed) && aligned?(head, added) &&
           base_lines.include?(removed[:line]) && head_lines.include?(added[:line]) &&
           same_version?(removed, added, uses: false)
      if ok
        introduced.concat(fresh_tokens(removed[:text], added[:text])) if collect
        nil
      else
        fail_line(file, added[:line])
      end
    end
  end

  def workflow_pairs(file, base, head, client, introduced, collect)
    base_marks = workflow_marks(base)
    head_marks = workflow_marks(head)
    return fail_line(file, blame(file)) if base_marks.nil? || head_marks.nil?
    each_problem(file) do |removed, added|
      problem = workflow_pair(file, base, head, base_marks, head_marks, removed, added, client, introduced, collect)
      problem
    end
  end

  def workflow_pair(file, base, head, base_marks, head_marks, removed, added, client, introduced, collect)
    return fail_line(file, added[:line]) unless aligned?(base, removed) && aligned?(head, added)
    removed_kinds = kinds(base_marks, removed[:line])
    added_kinds = kinds(head_marks, added[:line])
    return fail_line(file, added[:line]) if removed_kinds.nil? || added_kinds.nil?
    uses = removed_kinds.include?(:uses) || added_kinds.include?(:uses)
    return fail_line(file, added[:line]) if uses && !(removed_kinds.include?(:uses) && added_kinds.include?(:uses))
    return fail_line(file, added[:line]) unless same_version?(removed, added, uses: uses)
    return fail_line(file, added[:line]) if uses && !pin_ok?(added[:text], client)
    introduced.concat(fresh_tokens(removed[:text], added[:text])) if collect
    nil
  end

  def test_pairs(file, base, head, introduced)
    each_problem(file) do |removed, added|
      fresh = fresh_tokens(removed[:text], added[:text])
      ok = aligned?(base, removed) && aligned?(head, added) &&
           assertion?(removed[:text]) && assertion?(added[:text]) &&
           mask_test(removed[:text]) == mask_test(added[:text]) &&
           removed[:text] != added[:text] &&
           fresh.any? && fresh.all? { |token| introduced.include?(token) }
      ok ? nil : fail_line(file, added[:line])
    end
  end

  def each_problem(file)
    hunks = parse_patch(file["patch"])
    return fail_line(file, 1) if hunks.nil? || hunks.empty?
    saw = false
    hunks.each do |hunk|
      removed = hunk[:removed]
      added = hunk[:added]
      if removed.size != added.size
        extra = added[removed.size] || removed[added.size]
        return fail_line(file, extra[:line])
      end
      removed.zip(added) do |old_line, new_line|
        saw = true
        problem = yield(old_line, new_line)
        return problem if problem
      end
    end
    saw ? nil : fail_line(file, 1)
  end

  def same_version?(removed, added, uses:)
    removed[:text] != added[:text] && mask(removed[:text], uses: uses) == mask(added[:text], uses: uses)
  end

  def aligned?(content, entry)
    text_at(content, entry[:line]) == entry[:text]
  end

  def text_at(content, line)
    row = content.lines[line - 1]
    return nil unless row
    row.delete_suffix("\n").delete_suffix("\r")
  end

  def mask(text, uses:)
    masked = text.gsub(VERSION_TOKEN, "V")
    return masked unless uses
    masked.gsub(SHA_TOKEN, "S").gsub(/#\s*v\d+\.\d+\.\d+/, "# T")
  end

  def mask_test(text)
    text.gsub(VERSION_TOKEN, "V").gsub(SHA_TOKEN, "S")
  end

  def tokens(text)
    text.scan(VERSION_TOKEN) + text.scan(SHA_TOKEN)
  end

  def fresh_tokens(removed, added)
    pool = tokens(removed).dup
    tokens(added).reject do |token|
      index = pool.index(token)
      next false unless index
      pool.delete_at(index)
      true
    end
  end

  def assertion?(text)
    text.match?(ASSERTION)
  end

  def pin_ok?(text, client)
    match = USES_LINE.match(text)
    return false unless match
    commit = client.tag_commit("v#{match[2]}")
    commit.is_a?(String) && commit.match?(/\A[0-9a-f]{40}\z/) && commit.downcase == match[1]
  end

  def lock_lines(content)
    rows = content.to_s.lines
    start = rows.index { |row| row.strip == "RUBY VERSION" }
    return [] unless start
    stop = ((start + 1)...rows.size).find { |index| rows[index].match?(/\A[A-Z][A-Z0-9 ]+\r?\n?\z/) } || rows.size
    ((start + 1)...stop).map { |index| index + 1 }
  end

  def workflow_marks(content)
    stream = Psych.parse_stream(content)
    docs = Array(stream.children)
    return nil unless docs.size == 1
    document = docs.first
    return nil if alias_node?(document)
    allowed = {}
    forbidden = {}
    return nil unless walk_node(document, [], allowed, forbidden)
    { allowed: allowed, forbidden: forbidden }
  rescue Psych::SyntaxError
    nil
  end

  def alias_node?(node)
    return false if node.nil?
    return true if node.is_a?(Psych::Nodes::Alias)
    Array(node.children).any? { |child| alias_node?(child) }
  end

  def walk_node(node, path, allowed, forbidden)
    case node
    when Psych::Nodes::Document
      children = Array(node.children)
      return false unless children.size == 1
      walk_node(children.first, path, allowed, forbidden)
    when Psych::Nodes::Mapping
      walk_mapping(node, path, allowed, forbidden)
    when Psych::Nodes::Sequence
      Array(node.children).all? { |child| walk_node(child, path, allowed, forbidden) }
    else
      true
    end
  end

  def walk_mapping(node, path, allowed, forbidden)
    list = pairs(node)
    return false if list.nil?
    mark_uses(list, allowed)
    list.all? do |key, value|
      name = scalar_text(key)
      next false if name.nil?
      forbid_span(value, forbidden) if name == "env"
      forbid_block(value, forbidden)
      mark_matrix(path, name, value, allowed)
      mark_if(name, value, allowed)
      walk_node(value, path + [name], allowed, forbidden)
    end
  end

  def pairs(mapping)
    children = Array(mapping.children)
    return nil unless children.size.even?
    children.each_slice(2).to_a
  end

  def scalar_text(node)
    node.value if node.is_a?(Psych::Nodes::Scalar)
  end

  def mark_uses(list, allowed)
    _key, value = list.find { |key, _value| scalar_text(key) == "uses" }
    return unless value.is_a?(Psych::Nodes::Scalar) && value.value.start_with?(SETUP_PREFIX)
    allow_line(allowed, value, :uses)
    _with, body = list.find { |key, _value| scalar_text(key) == "with" }
    return unless body.is_a?(Psych::Nodes::Mapping)
    ruby = pairs(body)&.find { |key, _value| scalar_text(key) == "ruby-version" }
    return unless ruby && ruby[1].is_a?(Psych::Nodes::Scalar)
    allow_line(allowed, ruby[1], :ruby_version)
  end

  def mark_matrix(path, name, value, allowed)
    return unless name == "ruby" && path.last == "matrix" && path[-2] == "strategy"
    each_scalar(value) { |scalar| allow_line(allowed, scalar, :matrix) }
  end

  def mark_if(name, value, allowed)
    return unless name == "if" && value.is_a?(Psych::Nodes::Scalar)
    return if BLOCK_STYLES.include?(value.style)
    return unless value.value.match?(MATRIX_RUBY) && value.value.match?(COMPARE)
    allow_line(allowed, value, :if)
  end

  def each_scalar(node, &block)
    case node
    when Psych::Nodes::Scalar
      yield node
    when Psych::Nodes::Sequence
      Array(node.children).each { |child| each_scalar(child, &block) }
    end
  end

  def allow_line(allowed, node, kind)
    line = node.start_line + 1
    (allowed[line] ||= []) << kind
  end

  def forbid_block(node, forbidden)
    return unless node.is_a?(Psych::Nodes::Scalar) && BLOCK_STYLES.include?(node.style)
    first = node.start_line + 1
    last = node.end_line - 1
    return if last < first
    (first..last).each { |line| forbidden[line + 1] = true }
  end

  def forbid_span(node, forbidden)
    return if node.nil?
    start = node.start_line
    finish = node.end_line
    finish -= 1 if finish > start
    (start..finish).each { |line| forbidden[line + 1] = true }
  end

  def kinds(marks, line)
    return nil if marks[:forbidden][line]
    marks[:allowed][line]
  end

  def parse_patch(patch)
    return nil unless patch.is_a?(String) && !patch.empty?
    hunks = []
    current = nil
    old_no = nil
    new_no = nil
    patch.each_line do |raw|
      line = raw.delete_suffix("\n")
      return nil if line.include?("\r")
      if (match = HUNK.match(line))
        current = { removed: [], added: [] }
        hunks << current
        old_no = match[1].to_i
        new_no = match[2].to_i
      elsif current.nil? || old_no.nil?
        return nil
      elsif line.start_with?("\\")
        next
      elsif line.start_with?("+")
        current[:added] << { text: line[1..], line: new_no }
        new_no += 1
      elsif line.start_with?("-")
        current[:removed] << { text: line[1..], line: old_no }
        old_no += 1
      elsif line.start_with?(" ")
        old_no += 1
        new_no += 1
      else
        return nil
      end
    end
    hunks
  end

  def blame(file)
    hunks = parse_patch(file["patch"].to_s)
    return 1 if hunks.nil?
    first = hunks.flat_map { |hunk| hunk[:added] + hunk[:removed] }.first
    first ? first[:line] : 1
  end

  def fail_line(file, line)
    fail_at("#{file["filename"]}:#{line}")
  end

  class Live
    def self.build(env, event)
      token = env["GITHUB_TOKEN"].to_s
      raise Error if token.empty?
      request = event.fetch("pull_request")
      base = request.dig("base", "sha")
      head = request.dig("head", "sha")
      repo = event.dig("repository", "full_name")
      number = request["number"]
      raise Error unless sha?(base) && sha?(head) && number.is_a?(Integer)
      raise Error unless repo.is_a?(String) && repo.match?(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/)
      api = env["GITHUB_API_URL"] || "https://api.github.com"
      dir = env["GITHUB_WORKSPACE"] || Dir.pwd
      new(token, repo, base, head, number, api, dir)
    end

    def self.sha?(value)
      value.is_a?(String) && value.match?(/\A[0-9a-f]{40}\z/)
    end

    def initialize(token, repo, base, head, number, api, dir)
      @token = token
      @repo = repo
      @base = base
      @head = head
      @number = number
      @dir = dir
      uri = URI(api)
      raise Error unless uri.scheme == "https" && uri.host == "api.github.com" && uri.port == 443
    end

    def files
      page = 1
      collected = []
      loop do
        response = get("/repos/#{@repo}/pulls/#{@number}/files?per_page=100&page=#{page}")
        batch = JSON.parse(response.body)
        raise Error unless batch.is_a?(Array)
        collected.concat(batch)
        break unless next_page?(response["Link"])
        page += 1
        raise Error if page > 31
      end
      collected
    rescue Error
      raise
    rescue StandardError
      raise Error
    end

    def contents(side, path)
      raise Error unless side == "base" || side == "head"
      sha = side == "base" ? merge_base_sha : @head
      raise Error unless self.class.sha?(sha) && LaneSecurityBump.safe_path?(path)
      git("show", "#{sha}:#{path}")
    rescue Error
      nil
    end

    def tag_commit(tag)
      raise Error unless tag.match?(/\Av\d+\.\d+\.\d+\z/)
      body = get_json("/repos/ruby/setup-ruby/git/ref/tags/#{tag}")
      object = body.fetch("object")
      sha = object.fetch("sha")
      raise Error unless self.class.sha?(sha)
      case object.fetch("type")
      when "commit"
        sha.downcase
      when "tag"
        peeled = get_json("/repos/ruby/setup-ruby/git/tags/#{sha}")
        target = peeled.fetch("object")
        raise Error unless target.fetch("type") == "commit" && self.class.sha?(target.fetch("sha"))
        target.fetch("sha").downcase
      else
        raise Error
      end
    end

    def merge_base_sha
      return @merge_base_sha if @merge_base_sha
      sha = git("merge-base", @base, @head).strip
      raise Error unless self.class.sha?(sha)
      @merge_base_sha = sha
    end

    def git(*args)
      stdout, status = Open3.capture2("git", *args, chdir: @dir)
      raise Error unless status.success?
      stdout
    rescue Error
      raise
    rescue StandardError
      raise Error
    end

    def get(path)
      raise Error unless path.start_with?("/repos/")
      uri = URI("https://api.github.com#{path}")
      raise Error unless uri.host == "api.github.com"
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/vnd.github+json"
      request["User-Agent"] = "metz-scan"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
        http.request(request)
      end
      raise Error unless response.is_a?(Net::HTTPSuccess)
      response
    rescue Error
      raise
    rescue StandardError
      raise Error
    end

    def get_json(path)
      JSON.parse(get(path).body)
    rescue JSON::ParserError
      raise Error
    end

    def next_page?(header)
      header.to_s.split(",").any? { |part| part.match?(/;\s*rel="?next"?/i) }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  status, message = LaneSecurityBump.run
  $stdout.puts(message) unless message.empty?
  exit status
end
