# frozen_string_literal: true
# rubocop:disable all

require "json"
require "net/http"
require "open3"
require "prism"
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
  TEST_TOKEN = Regexp.union(VERSION_TOKEN, SHA_TOKEN)
  RUBY_SCALAR = /\A(?:ruby[- ]?)?#{VERSION_TOKEN}\z/
  RUBY_VERSION_LINE = /\A\s*(?:ruby[- ]?)?(#{VERSION_TOKEN})\s*\z/
  USES_LINE = /\A(\s*-?\s*uses:\s*ruby\/setup-ruby@)([0-9a-f]{40})(\s+#\s*v)(\d+\.\d+\.\d+)(\s*)\z/
  MISE_LINE = /\A\s*(?:ruby|"ruby"|'ruby')\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s#]+))\s*(?:#.*)?\z/
  DOCKER_LINE = /\A\s*ARG\s+(?:RUBY_VERSION|RUBY_VER|ruby(?:_version|_ver)?)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s#]+))\s*(?:#.*)?\z/i
  DOCKER_DIRECTIVE = /\A#\s*([a-z][a-z0-9_-]*)\s*=\s*(.*?)\s*\z/i
  DOCKER_HEREDOC = /<<(-?)['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?/
  LOCK_RUBY_LINE = /\A\s+ruby\s+(#{VERSION_TOKEN})\s*\z/
  HUNK = /\A@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/
  IF_COMPARE_AT = /
    \G
    (?:matrix\.ruby(?![\w.])|matrix\s*\[\s*['"]ruby['"]\s*\])
    \s*(?:==|!=|>=|<=|>|<)\s*
    (['"]?)
    (\d+\.\d+\.\d+(?:p\d+|[-.](?:preview|rc|beta|alpha)\d+)?)
    \1
    (?=\s*(?:\z|\}\}|&&|\|\||\)))
  /x
  ASSERTION_CALL = /\A(?:assert|refute)(?:_[A-Za-z0-9_]+)?\z/
  RSPEC_EXPECT_TO = %i[to not_to to_not].freeze
  RSPEC_MATCHERS = %i[eq eql equal include match be start_with end_with].freeze
  SETUP_PREFIX = "ruby/setup-ruby@"
  QUOTED_STYLES = [2, 3].freeze
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
    return fail_at("files:0") unless valid_api_files?(listed, changed)
    changes = client.changes
    return fail_at("files:0") unless changes.is_a?(Array) && changes.size == changed
    return fail_at("files:0") unless changes.all? { |file| file.is_a?(Hash) && file["filename"].is_a?(String) }
    names = changes.map { |file| file["filename"] }
    return fail_at("files:0") unless names.uniq.size == names.size
    problem = mode_problem(changes, client.modes)
    return problem if problem
    problem = judge(changes, client)
    return problem if problem
    listed_names = listed.map { |file| file["filename"] }
    return fail_at("files:0") unless listed_names.sort == names.sort
    pass
  rescue Error
    fail_at("api:0")
  end

  def valid_api_files?(listed, changed)
    return false unless listed.is_a?(Array) && changed.is_a?(Integer) && changed.positive? && listed.size == changed
    return false unless listed.all? { |file| api_file_entry?(file) }
    names = listed.map { |file| file["filename"] }
    names.uniq.size == names.size
  end

  def api_file_entry?(file)
    file.is_a?(Hash) &&
      file["filename"].is_a?(String) && !file["filename"].empty? &&
      file["patch"].is_a?(String) && !file["patch"].empty?
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

  def mode_problem(files, modes)
    return fail_at("files:0") unless modes.is_a?(Hash)
    files.each do |file|
      info = modes[file["filename"]]
      old_mode = info.is_a?(Hash) ? info["old"] : nil
      new_mode = info.is_a?(Hash) ? info["new"] : nil
      return fail_line(file, blame(file)) unless old_mode == "100644" && new_mode == "100644"
    end
    nil
  end

  def parse_changes(raw_text, diff_text)
    info = parse_raw(raw_text)
    patches = split_diff(diff_text)
    raise Error unless patches.keys.sort == info.keys.sort
    modes = info.transform_values { |row| { "old" => row["old"], "new" => row["new"] } }
    rows = info.map do |path, row|
      {
        "filename" => path,
        "status" => row["status"],
        "previous_filename" => row["previous"],
        "patch" => patches[path]
      }
    end
    [rows, modes]
  end

  def parse_raw(text)
    result = {}
    text.to_s.each_line do |raw|
      line = raw.delete_suffix("\n")
      next if line.empty?
      head, paths = line.split("\t", 2)
      raise Error if paths.nil? || paths.empty?
      match = head.match(/\A:(\d{6}) (\d{6}) \S+ \S+ ([A-Z])\d*\z/)
      raise Error unless match
      names = paths.split("\t")
      raise Error if names.empty? || names.any? { |name| name.empty? || name.start_with?('"') }
      status = git_status(match[3])
      raise Error if status.nil?
      previous = nil
      if status == "renamed" || status == "copied"
        raise Error unless names.size == 2
        previous = names[0]
        path = names[1]
      else
        raise Error unless names.size == 1
        path = names[0]
      end
      result[path] = { "old" => match[1], "new" => match[2], "status" => status, "previous" => previous }
    end
    result
  end

  def git_status(letter)
    { "A" => "added", "D" => "removed", "M" => "modified", "T" => "modified", "R" => "renamed", "C" => "copied" }[letter]
  end

  def split_diff(text)
    parts = text.to_s.split(/^(?=diff --git )/)
    parts.each_with_object({}) do |part, map|
      next if part.empty?
      match = part.match(/\Adiff --git a\/(\S+) b\/(\S+)\n/)
      raise Error unless match
      hunks = part.lines.drop_while { |line| !line.start_with?("@@") }.join
      map[match[2]] = hunks.empty? ? nil : hunks
    end
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
    return fail_line(file, blame(file)) unless base.end_with?("\n") == head.end_with?("\n")
    case place(file["filename"])
    when :ruby_version then version_pairs(file, base, head, introduced, collect)
    when :mise then mise_pairs(file, base, head, introduced, collect)
    when :docker then docker_pairs(file, base, head, introduced, collect)
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
    return :test if path.start_with?("test/")
    :other
  end

  def version_pairs(file, base, head, introduced, collect)
    each_problem(file) do |removed, added|
      old_span = capture_span(removed[:text], RUBY_VERSION_LINE, 1)
      new_span = capture_span(added[:text], RUBY_VERSION_LINE, 1)
      changed = old_span && new_span ? same_version_changes(removed, added, [old_span], [new_span]) : nil
      if aligned?(base, removed) && aligned?(head, added) && changed
        introduced.concat(changed) if collect
        nil
      else
        fail_line(file, added[:line])
      end
    end
  end

  def docker_pairs(file, base, head, introduced, collect)
    base_lines = docker_arg_lines(base)
    head_lines = docker_arg_lines(head)
    return fail_line(file, blame(file)) if base_lines.nil? || head_lines.nil?
    each_problem(file) do |removed, added|
      old_span = docker_value_span(removed[:text])
      new_span = docker_value_span(added[:text])
      changed = old_span && new_span ? same_version_changes(removed, added, [old_span], [new_span]) : nil
      ok = aligned?(base, removed) && aligned?(head, added) &&
           base_lines.include?(removed[:line]) && head_lines.include?(added[:line]) &&
           changed
      if ok
        introduced.concat(changed) if collect
        nil
      else
        fail_line(file, added[:line])
      end
    end
  end

  def docker_arg_lines(content)
    escape = "\\"
    escape_seen = false
    directives = true
    heredoc = nil
    instruction = nil
    found = []
    content.to_s.lines.each_with_index do |raw, index|
      line = raw.delete_suffix("\n").delete_suffix("\r")
      if heredoc
        candidate = heredoc[:strip_tabs] ? line.sub(/\A\t+/, "") : line
        heredoc = nil if candidate == heredoc[:delimiter]
        next
      end
      if directives
        if (match = DOCKER_DIRECTIVE.match(line))
          if match[1].downcase == "escape"
            return nil if escape_seen || !(match[2] == "\\" || match[2] == "`")
            escape = match[2]
            escape_seen = true
          end
          next
        end
        directives = false
      end
      next if line.strip.empty? || line.lstrip.start_with?("#")
      continues = line.rstrip.end_with?(escape)
      chunk = continues ? line.rstrip.delete_suffix(escape) : line
      if instruction.nil?
        instruction = { start_line: index + 1, count: 1, chunks: [chunk] }
      else
        instruction[:count] += 1
        instruction[:chunks] << chunk
      end
      next if continues
      logical = instruction[:chunks].join(" ")
      heredocs = logical.scan(DOCKER_HEREDOC)
      return nil if heredocs.size > 1
      if heredocs.size == 1
        heredoc = { strip_tabs: heredocs.first[0] == "-", delimiter: heredocs.first[1] }
      elsif instruction[:count] == 1 && DOCKER_LINE.match?(logical)
        found << instruction[:start_line]
      end
      instruction = nil
    end
    return nil if heredoc || instruction
    found
  end

  def docker_value_span(text)
    rhs_value_span(text, DOCKER_LINE)
  end

  def mise_pairs(file, base, head, introduced, collect)
    base_lines = mise_tools_lines(base)
    head_lines = mise_tools_lines(head)
    return fail_line(file, blame(file)) if base_lines.nil? || head_lines.nil?
    each_problem(file) do |removed, added|
      old_span = mise_value_span(removed[:text])
      new_span = mise_value_span(added[:text])
      changed = old_span && new_span ? same_version_changes(removed, added, [old_span], [new_span]) : nil
      ok = aligned?(base, removed) && aligned?(head, added) &&
           base_lines.include?(removed[:line]) && head_lines.include?(added[:line]) &&
           changed
      if ok
        introduced.concat(changed) if collect
        nil
      else
        fail_line(file, added[:line])
      end
    end
  end

  def mise_value_span(text)
    span = rhs_value_span(text, MISE_LINE)
    return nil unless span
    value = text[span[0]...span[1]]
    value.match?(RUBY_SCALAR) ? span : nil
  end

  def rhs_value_span(text, regex)
    match = regex.match(text)
    return nil unless match
    group = match[1] ? 1 : (match[2] ? 2 : 3)
    [match.begin(group), match.end(group)]
  end

  def capture_span(text, regex, group)
    match = regex.match(text)
    return nil unless match
    [match.begin(group), match.end(group)]
  end

  def mise_tools_lines(content)
    table = nil
    found = []
    content.to_s.lines.each_with_index do |raw, index|
      line = raw.strip
      next if line.empty? || line.start_with?("#")
      return nil if line.include?('"""') || line.include?("'''")
      if (header = line.match(/\A\[\s*([A-Za-z0-9_.-]+)\s*\]\z/))
        table = header[1]
        next
      end
      return nil if line.start_with?("[")
      found << (index + 1) if table == "tools" && line.match?(/\A(?:ruby|"ruby"|'ruby')\s*=/)
    end
    found
  end

  def lock_pairs(file, base, head, introduced, collect)
    base_lines = lock_lines(base)
    head_lines = lock_lines(head)
    each_problem(file) do |removed, added|
      old_span = capture_span(removed[:text], LOCK_RUBY_LINE, 1)
      new_span = capture_span(added[:text], LOCK_RUBY_LINE, 1)
      changed = old_span && new_span ? same_version_changes(removed, added, [old_span], [new_span]) : nil
      ok = aligned?(base, removed) && aligned?(head, added) &&
           base_lines.include?(removed[:line]) && head_lines.include?(added[:line]) &&
           changed
      if ok
        introduced.concat(changed) if collect
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
      workflow_pair(file, base, head, base_marks, head_marks, removed, added, client, introduced, collect)
    end
  end

  def workflow_pair(file, base, head, base_marks, head_marks, removed, added, client, introduced, collect)
    return fail_line(file, added[:line]) unless aligned?(base, removed) && aligned?(head, added)
    removed_kinds = kinds(base_marks, removed[:line])
    added_kinds = kinds(head_marks, added[:line])
    return fail_line(file, added[:line]) if removed_kinds.nil? || added_kinds.nil?
    removed_names = kind_names(removed_kinds)
    added_names = kind_names(added_kinds)
    return fail_line(file, added[:line]) unless removed_names.sort == added_names.sort
    changed = if removed_names.include?(:uses)
                uses_change(removed, added, client)
              else
                same_version_changes(removed, added, column_spans(removed_kinds), column_spans(added_kinds))
              end
    return fail_line(file, added[:line]) unless changed
    introduced.concat(changed) if collect
    nil
  end

  def uses_change(removed, added, client)
    old_match = USES_LINE.match(removed[:text])
    new_match = USES_LINE.match(added[:text])
    return nil unless old_match && new_match
    return nil unless [old_match[1], old_match[3], old_match[5]] == [new_match[1], new_match[3], new_match[5]]
    return nil if old_match[2] == new_match[2]
    commit = client.tag_commit("v#{new_match[4]}")
    return nil unless commit.is_a?(String) && commit.match?(/\A[0-9a-f]{40}\z/) && commit.downcase == new_match[2]
    [new_match[2]]
  end

  def test_pairs(file, base, head, introduced)
    base_spans = test_file_assertion_spans(base)
    head_spans = test_file_assertion_spans(head)
    return fail_line(file, blame(file)) if base_spans.nil? || head_spans.nil?
    each_problem(file) do |removed, added|
      old_spans = base_spans[removed[:line]]
      new_spans = head_spans[added[:line]]
      changed = old_spans && new_spans ? test_line_changes(removed[:text], added[:text], old_spans, new_spans) : nil
      ok = aligned?(base, removed) && aligned?(head, added) &&
           changed && changed.any? && changed.all? { |token| introduced.include?(token) }
      ok ? nil : fail_line(file, added[:line])
    end
  end

  def test_line_changes(removed_text, added_text, old_spans, new_spans)
    return nil if removed_text == added_text
    old_segments, old_tokens = tokenize_test_spans(removed_text, old_spans)
    new_segments, new_tokens = tokenize_test_spans(added_text, new_spans)
    return nil unless old_segments == new_segments && old_tokens.size == new_tokens.size
    return nil unless old_tokens.zip(new_tokens).all? { |old_tok, new_tok| old_tok[0] == new_tok[0] }
    old_tokens.zip(new_tokens).filter_map { |old_tok, new_tok| new_tok[1] if old_tok[1] != new_tok[1] }
  end

  def test_file_assertion_spans(content)
    parsed = Prism.parse(content)
    return nil unless parsed.errors.empty?
    by_line = {}
    walk_prism_assertions(parsed.value, by_line)
    by_line
  end

  def walk_prism_assertions(node, by_line)
    return if node.nil?
    if node.is_a?(Prism::CallNode)
      if node.receiver.nil? && node.name.to_s.match?(ASSERTION_CALL)
        collect_literal_string_spans(node.arguments, by_line, allow_matcher: false)
        return
      elsif rspec_expect_assertion?(node)
        collect_literal_string_spans(node.receiver.arguments, by_line, allow_matcher: false)
        collect_literal_string_spans(node.arguments, by_line, allow_matcher: true)
        return
      end
    end
    node.compact_child_nodes.each { |child| walk_prism_assertions(child, by_line) }
  end

  def rspec_expect_assertion?(stmt)
    RSPEC_EXPECT_TO.include?(stmt.name) &&
      stmt.receiver.is_a?(Prism::CallNode) &&
      stmt.receiver.receiver.nil? &&
      stmt.receiver.name == :expect
  end

  def collect_literal_string_spans(node, by_line, allow_matcher:)
    case node
    when Prism::ArgumentsNode
      node.arguments.each { |arg| collect_literal_string_spans(arg, by_line, allow_matcher: allow_matcher) }
    when Prism::StringNode
      loc = node.content_loc
      if loc.start_line == loc.end_line
        (by_line[loc.start_line] ||= []) << [loc.start_character_column, loc.end_character_column]
      end
    when Prism::ArrayNode
      node.elements.each { |el| collect_literal_string_spans(el, by_line, allow_matcher: false) }
    when Prism::HashNode, Prism::KeywordHashNode
      node.elements.each { |el| collect_literal_string_spans(el, by_line, allow_matcher: false) }
    when Prism::AssocNode
      collect_literal_string_spans(node.value, by_line, allow_matcher: false)
    when Prism::ParenthesesNode
      inner = node.body.is_a?(Prism::StatementsNode) && node.body.body.size == 1 ? node.body.body.first : nil
      collect_literal_string_spans(inner, by_line, allow_matcher: false) if inner
    when Prism::CallNode
      if allow_matcher && node.receiver.nil? && RSPEC_MATCHERS.include?(node.name)
        collect_literal_string_spans(node.arguments, by_line, allow_matcher: false)
      end
    end
  end

  def each_problem(file)
    blocks = parse_patch(file["patch"])
    return fail_line(file, 1) if blocks.nil? || blocks.empty?
    saw = false
    blocks.each do |block|
      removed = block[:removed]
      added = block[:added]
      if removed.size != added.size
        extra = added[removed.size] || removed[added.size]
        return fail_line(file, extra[:line])
      end
      removed.zip(added) do |old_line, new_line|
        return fail_line(file, new_line[:line]) unless old_line[:line] == new_line[:line]
        saw = true
        problem = yield(old_line, new_line)
        return problem if problem
      end
    end
    saw ? nil : fail_line(file, 1)
  end

  def same_version_changes(removed, added, removed_spans, added_spans)
    return nil if removed[:text] == added[:text]
    old_segments, old_tokens = tokenize_spans(removed[:text], VERSION_TOKEN, removed_spans)
    new_segments, new_tokens = tokenize_spans(added[:text], VERSION_TOKEN, added_spans)
    return nil unless old_segments == new_segments && old_tokens.size == new_tokens.size
    changed = old_tokens.zip(new_tokens).filter_map { |old_tok, new_tok| new_tok if old_tok != new_tok }
    changed.any? ? changed : nil
  end

  def tokenize_spans(text, pattern, spans)
    segments = []
    tokens = []
    cursor = 0
    text.scan(pattern) do
      match = Regexp.last_match
      next unless cover?(spans, match.begin(0), match.end(0))
      segments << text[cursor...match.begin(0)]
      tokens << match[0]
      cursor = match.end(0)
    end
    segments << text[cursor..]
    [segments, tokens]
  end

  def tokenize_test_spans(text, spans)
    segments = []
    tokens = []
    cursor = 0
    text.scan(TEST_TOKEN) do
      match = Regexp.last_match
      next unless cover?(spans, match.begin(0), match.end(0))
      segments << text[cursor...match.begin(0)]
      kind = match[0].match?(/\A[0-9a-f]{40}\z/) ? :sha : :version
      tokens << [kind, match[0]]
      cursor = match.end(0)
    end
    segments << text[cursor..]
    [segments, tokens]
  end

  def aligned?(content, entry)
    text_at(content, entry[:line]) == entry[:text]
  end

  def text_at(content, line)
    row = content.lines[line - 1]
    return nil unless row
    row.delete_suffix("\n").delete_suffix("\r")
  end

  def cover?(spans, start, finish)
    Array(spans).any? { |left, right| start >= left && finish <= right }
  end

  def lock_lines(content)
    rows = content.to_s.lines
    start = rows.index { |row| row.match?(/\ARUBY VERSION\r?\n?\z/) }
    return [] unless start
    stop = ((start + 1)...rows.size).find { |index| rows[index].match?(/\A\S/) } || rows.size
    ((start + 1)...stop).filter_map { |index| (index + 1) if rows[index].match?(LOCK_RUBY_LINE) }
  end

  def workflow_marks(content)
    stream = Psych.parse_stream(content)
    docs = Array(stream.children)
    return nil unless docs.size == 1
    document = docs.first
    return nil if alias_node?(document)
    allowed = {}
    forbidden = {}
    return nil unless walk_node(document, [], allowed, forbidden, content.lines)
    { allowed: allowed, forbidden: forbidden }
  rescue Psych::SyntaxError
    nil
  end

  def alias_node?(node)
    return false if node.nil?
    return true if node.is_a?(Psych::Nodes::Alias)
    Array(node.children).any? { |child| alias_node?(child) }
  end

  def walk_node(node, path, allowed, forbidden, lines)
    case node
    when Psych::Nodes::Document
      children = Array(node.children)
      return false unless children.size == 1
      walk_node(children.first, path, allowed, forbidden, lines)
    when Psych::Nodes::Mapping
      walk_mapping(node, path, allowed, forbidden, lines)
    when Psych::Nodes::Sequence
      Array(node.children).all? { |child| walk_node(child, path + [:item], allowed, forbidden, lines) }
    else
      true
    end
  end

  def walk_mapping(node, path, allowed, forbidden, lines)
    list = pairs(node)
    return false if list.nil?
    seen = {}
    list.each do |key, _value|
      name = scalar_text(key)
      return false if name.nil? || seen[name]
      seen[name] = true
    end
    mark_uses(path, list, allowed)
    list.all? do |key, value|
      name = scalar_text(key)
      if name == "env"
        forbid_span(value, forbidden)
        next true
      end
      forbid_block(value, forbidden)
      mark_matrix(path, name, value, allowed)
      mark_if(path, name, value, allowed, lines)
      walk_node(value, path + [name], allowed, forbidden, lines)
    end
  end

  def job_mapping?(path)
    path.size == 2 && path[0] == "jobs" && path[1].is_a?(String)
  end

  def step_mapping?(path)
    path.size == 4 && path[0] == "jobs" && path[1].is_a?(String) && path[2] == "steps" && path[3] == :item
  end

  def matrix_mapping?(path)
    path.size == 4 && path[0] == "jobs" && path[1].is_a?(String) && path[2] == "strategy" && path[3] == "matrix"
  end

  def pairs(mapping)
    children = Array(mapping.children)
    return nil unless children.size.even?
    children.each_slice(2).to_a
  end

  def scalar_text(node)
    node.value if node.is_a?(Psych::Nodes::Scalar)
  end

  def mark_uses(path, list, allowed)
    return unless step_mapping?(path)
    _key, value = list.find { |key, _value| scalar_text(key) == "uses" }
    return unless value.is_a?(Psych::Nodes::Scalar) && value.value.start_with?(SETUP_PREFIX)
    allow_line(allowed, value, :uses)
    _with, body = list.find { |key, _value| scalar_text(key) == "with" }
    return unless body.is_a?(Psych::Nodes::Mapping)
    body_pairs = pairs(body)
    return if body_pairs.nil?
    ruby_entries = body_pairs.select { |key, _value| scalar_text(key)&.downcase == "ruby-version" }
    return unless ruby_entries.size == 1 && scalar_text(ruby_entries.first[0]) == "ruby-version"
    ruby_value = ruby_entries.first[1]
    return unless ruby_value.is_a?(Psych::Nodes::Scalar) && ruby_value.value.match?(RUBY_SCALAR)
    allow_line(allowed, ruby_value, :ruby_version)
  end

  def mark_matrix(path, name, value, allowed)
    return unless matrix_mapping?(path) && name == "ruby" && value.is_a?(Psych::Nodes::Sequence)
    Array(value.children).each do |child|
      next unless child.is_a?(Psych::Nodes::Scalar) && child.value.match?(RUBY_SCALAR)
      allow_line(allowed, child, :matrix)
    end
  end

  def mark_if(path, name, value, allowed, lines)
    return unless (job_mapping?(path) || step_mapping?(path)) && name == "if" && value.is_a?(Psych::Nodes::Scalar)
    return if BLOCK_STYLES.include?(value.style) || value.end_line != value.start_line
    raw = lines[value.start_line].to_s.delete_suffix("\n").delete_suffix("\r")
    quoted = QUOTED_STYLES.include?(value.style)
    col_start = quoted ? value.start_column + 1 : value.start_column
    col_end = quoted ? value.end_column - 1 : value.end_column
    return if col_end <= col_start
    region = raw[col_start...col_end]
    return if region.nil?
    scan_if_expression(region).each do |span_start, span_end|
      (allowed[value.start_line + 1] ||= []) << { kind: :if, span: [col_start + span_start, col_start + span_end] }
    end
  end

  def scan_if_expression(region)
    spans = []
    index = 0
    expect_operand = true
    while index < region.length
      if (ws = region.match(/\G\s+/, index))
        index = ws.end(0)
      elsif region[index] == "'"
        index = skip_actions_string(region, index)
        return [] if index.nil?
        expect_operand = false
      elsif region[index, 3] == "${{"
        index += 3
        expect_operand = true
      elsif region[index, 2] == "&&" || region[index, 2] == "||"
        index += 2
        expect_operand = true
      elsif region[index] == "!" || region[index] == "("
        index += 1
        expect_operand = true
      elsif expect_operand && (match = IF_COMPARE_AT.match(region, index))
        spans << [match.begin(2), match.end(2)]
        index = match.end(0)
        expect_operand = false
      else
        index += 1
        expect_operand = false
      end
    end
    spans
  end

  def skip_actions_string(region, start)
    index = start + 1
    while index < region.length
      if region[index] == "'"
        if region[index + 1] == "'"
          index += 2
        else
          return index + 1
        end
      else
        index += 1
      end
    end
    nil
  end

  def allow_line(allowed, node, kind)
    return unless node.is_a?(Psych::Nodes::Scalar) && node.end_line == node.start_line
    line = node.start_line + 1
    (allowed[line] ||= []) << { kind: kind, span: [node.start_column, node.end_column] }
  end

  def kind_names(entries)
    Array(entries).map { |entry| entry[:kind] }
  end

  def column_spans(entries)
    Array(entries).filter_map { |entry| entry[:span] }
  end

  def last_node_line(node)
    return node.start_line if node.end_line <= node.start_line
    node.end_column.zero? ? node.end_line - 1 : node.end_line
  end

  def forbid_block(node, forbidden)
    return unless node.is_a?(Psych::Nodes::Scalar) && BLOCK_STYLES.include?(node.style)
    finish = last_node_line(node)
    (node.start_line..finish).each { |line| forbidden[line + 1] = true }
  end

  def forbid_span(node, forbidden)
    return if node.nil?
    finish = last_node_line(node)
    (node.start_line..finish).each { |line| forbidden[line + 1] = true }
  end

  def kinds(marks, line)
    return nil if marks[:forbidden][line]
    marks[:allowed][line]
  end

  def parse_patch(patch)
    return nil unless patch.is_a?(String) && !patch.empty?
    blocks = []
    current = nil
    hunk = nil
    old_no = nil
    new_no = nil
    patch.each_line do |raw|
      line = raw.delete_suffix("\n")
      return nil if line.include?("\r")
      if (match = HUNK.match(line))
        return nil if hunk && !hunk_complete?(hunk)
        hunk = {
          expected_old: match[2] ? match[2].to_i : 1,
          expected_new: match[4] ? match[4].to_i : 1,
          seen_old: 0,
          seen_new: 0
        }
        current = nil
        old_no = match[1].to_i
        new_no = match[3].to_i
      elsif hunk.nil? || old_no.nil?
        return nil
      elsif line.start_with?("\\")
        next
      elsif line.start_with?("-")
        current = nil if current && !current[:added].empty?
        if current.nil?
          current = { removed: [], added: [] }
          blocks << current
        end
        current[:removed] << { text: line[1..], line: old_no }
        old_no += 1
        hunk[:seen_old] += 1
      elsif line.start_with?("+")
        if current.nil?
          current = { removed: [], added: [] }
          blocks << current
        end
        current[:added] << { text: line[1..], line: new_no }
        new_no += 1
        hunk[:seen_new] += 1
      elsif line.start_with?(" ")
        current = nil
        old_no += 1
        new_no += 1
        hunk[:seen_old] += 1
        hunk[:seen_new] += 1
      else
        return nil
      end
    end
    return nil if hunk.nil? || !hunk_complete?(hunk)
    blocks
  end

  def hunk_complete?(hunk)
    hunk[:seen_old] == hunk[:expected_old] && hunk[:seen_new] == hunk[:expected_new]
  end

  def blame(file)
    blocks = parse_patch(file["patch"].to_s)
    return 1 if blocks.nil?
    first = blocks.flat_map { |block| block[:added] + block[:removed] }.first
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
      raise Error unless valid_repo?(repo)
      api = env["GITHUB_API_URL"] || "https://api.github.com"
      dir = env["GITHUB_WORKSPACE"] || Dir.pwd
      new(token, repo, base, head, number, api, dir)
    end

    def self.valid_repo?(repo)
      return false unless repo.is_a?(String) && repo.match?(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/)
      repo.split("/").none? { |part| part == "." || part == ".." }
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
    rescue URI::InvalidURIError
      raise Error
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

    def changes
      return @changes if @changes
      spec = "#{merge_base_sha}..#{@head}"
      raw_text = git("diff", "--raw", spec)
      diff_text = git("diff", "--no-color", "--no-ext-diff", "--src-prefix=a/", "--dst-prefix=b/", spec)
      @changes, @modes = LaneSecurityBump.parse_changes(raw_text, diff_text)
      @changes
    end

    def modes
      changes unless @modes
      @modes
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
      peel_tag_object(body)
    rescue KeyError, TypeError, NoMethodError
      raise Error
    end

    def peel_tag_object(body)
      current = body
      5.times do
        raise Error unless current.is_a?(Hash)
        object = current.fetch("object")
        raise Error unless object.is_a?(Hash)
        sha = object.fetch("sha")
        type = object.fetch("type")
        raise Error unless self.class.sha?(sha)
        return sha.downcase if type == "commit"
        raise Error unless type == "tag"
        current = get_json("/repos/ruby/setup-ruby/git/tags/#{sha}")
      end
      raise Error
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
