#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "timeout"

QUERY_ID_START = 1_000
QUERY_SPECS = [
  [:search_file_classifier_view, "search_declarations", { query: "FileClassifier#view?", limit: 20 }],
  [:get_file_classifier_view, "get_declaration", { name: "Metz::FileClassifier#view?()" }],
  [:find_file_classifier_constant_references, "find_constant_references", { name: "Metz::FileClassifier", limit: 100 }],
  [:find_file_classifier_method_reference_attempt, "find_constant_references",
   { name: "Metz::FileClassifier#view?()", limit: 100 }],
  [:base_descendants, "get_descendants", { name: "RuboCop::Cop::Metz::Base", limit: 100 }],
  [:search_views_deep_navigation, "search_declarations", { query: "ViewsDeepNavigation", limit: 100 }],
  [:views_deep_navigation_references, "find_constant_references",
   { name: "RuboCop::Cop::Metz::ViewsDeepNavigation", limit: 100 }],
  [:views_deep_navigation_test_declarations, "get_file_declarations",
   { file_path: "rubocop-metz/test/cop/metz/views_deep_navigation_test.rb" }]
].freeze

class McpSession
  attr_reader :stderr_lines

  def self.open(binary, root)
    new(*Open3.popen3(binary, root))
  end

  def initialize(stdin, stdout, stderr, wait_thr)
    configure_process(stdin, stdout, stderr, wait_thr)
    @stderr_lines = []
    start_stderr_reader
  end

  def configure_process(stdin, stdout, stderr, wait_thr)
    @stdin = stdin
    @stdout = stdout
    @stderr = stderr
    @wait_thr = wait_thr
  end

  def request(id, method, params = {})
    send_message({ jsonrpc: "2.0", id: id, method: method, params: params })
  end

  def notify_initialized
    send_message({ jsonrpc: "2.0", method: "notifications/initialized" })
  end

  def send_message(message)
    @stdin.puts(JSON.generate(message))
    @stdin.flush
  end

  def read_response(expected_id)
    line = @stdout.gets
    raise "rubydex_mcp closed stdout while waiting for response #{expected_id}" unless line

    validate_response(JSON.parse(line), expected_id)
  end

  def call_tool(id, name, arguments = {})
    request(id, "tools/call", { name: name, arguments: arguments })
    text = read_response(id).fetch("result").fetch("content").fetch(0).fetch("text")
    JSON.parse(text)
  end

  def close
    close_io_streams
    @stderr_reader.join(1)
    terminate_process
  end

  private

  def start_stderr_reader
    @stderr_reader = Thread.new { @stderr.each_line { |line| @stderr_lines << line.chomp } }
  end

  def validate_response(parsed, expected_id)
    return parsed if parsed["id"] == expected_id

    raise "expected response id #{expected_id}, got #{parsed['id']}: #{parsed}"
  end

  def close_io_streams
    [@stdin, @stdout, @stderr].each { |io| io.close unless io.closed? }
  end

  def terminate_process
    Process.kill("TERM", @wait_thr.pid) if @wait_thr&.alive?
  end
end

def run_probe(binary:, root:, timeout_seconds:)
  Timeout.timeout(timeout_seconds) { puts JSON.pretty_generate(probe_results(binary, root)) }
end

def probe_results(binary, root)
  session = McpSession.open(binary, root)
  base_metadata(binary, root).merge(session_results(session), stderr: session.stderr_lines)
ensure
  session&.close
end

def base_metadata(binary, root)
  { binary: binary, root: root }
end

def session_results(session)
  initialize = initialize_session(session)
  tools = list_tools(session)
  query_payload(initialize, tools, wait_for_index(session), query_results(session))
end

def initialize_session(session)
  session.request(1, "initialize", initialize_params)
  session.read_response(1).fetch("result").tap { session.notify_initialized }
end

def initialize_params
  { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: client_info }
end

def client_info
  { name: "metz-scan-rubydex-mcp-probe", version: "0.1.0" }
end

def list_tools(session)
  session.request(2, "tools/list", {})
  session.read_response(2).fetch("result").fetch("tools").map { |tool| tool.fetch("name") }
end

def wait_for_index(session)
  stats = poll_stats(session)
  raise "indexing did not complete: #{stats}" if stats["error"]

  stats
end

def poll_stats(session)
  300.times do |offset|
    stats = session.call_tool(3 + offset, "codebase_stats", {})
    return stats unless stats["error"] == "indexing"

    sleep 0.1
  end
end

def query_results(session)
  QUERY_SPECS.each_with_index.to_h do |spec, offset|
    key, tool, arguments = spec
    [key, session.call_tool(QUERY_ID_START + offset, tool, arguments)]
  end
end

def query_payload(initialize, tools, stats, queries)
  { initialize: initialize, tools: tools, stats: stats, queries: queries }
end

repo_root = File.expand_path("..", __dir__)
run_probe(
  binary: ENV.fetch("RUBYDEX_MCP_BIN", "rubydex_mcp"),
  root: File.expand_path(ARGV.fetch(0, repo_root)),
  timeout_seconds: Integer(ENV.fetch("RUBYDEX_MCP_TIMEOUT", "120"))
)
