#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "timeout"

repo_root = File.expand_path("..", __dir__)
root = File.expand_path(ARGV.fetch(0, repo_root))
binary = ENV.fetch("RUBYDEX_MCP_BIN", "rubydex_mcp")
timeout_seconds = Integer(ENV.fetch("RUBYDEX_MCP_TIMEOUT", "120"))

def send_message(stdin, message)
  stdin.puts(JSON.generate(message))
  stdin.flush
end

def request(stdin, id, method, params = {})
  send_message(stdin, { jsonrpc: "2.0", id: id, method: method, params: params })
end

def read_response(stdout, expected_id)
  line = stdout.gets
  raise "rubydex_mcp closed stdout while waiting for response #{expected_id}" unless line

  parsed = JSON.parse(line)
  return parsed if parsed["id"] == expected_id

  raise "expected response id #{expected_id}, got #{parsed["id"]}: #{parsed}"
end

def call_tool(stdin, stdout, id, name, arguments = {})
  request(stdin, id, "tools/call", { name: name, arguments: arguments })
  response = read_response(stdout, id)
  text = response.fetch("result").fetch("content").fetch(0).fetch("text")

  JSON.parse(text)
end

stdin = stdout = stderr = wait_thr = nil
stderr_lines = []

begin
  Timeout.timeout(timeout_seconds) do
    stdin, stdout, stderr, wait_thr = Open3.popen3(binary, root)

    stderr_reader = Thread.new do
      stderr.each_line { |line| stderr_lines << line.chomp }
    end

    request(stdin, 1, "initialize", {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "metz-scan-rubydex-mcp-probe", version: "0.1.0" }
    })
    initialize_response = read_response(stdout, 1)

    send_message(stdin, {
      jsonrpc: "2.0",
      method: "notifications/initialized"
    })

    request(stdin, 2, "tools/list", {})
    tools_response = read_response(stdout, 2)

    id = 3
    stats = nil
    300.times do
      stats = call_tool(stdin, stdout, id, "codebase_stats", {})
      id += 1
      break unless stats["error"] == "indexing"

      sleep 0.1
    end

    raise "indexing did not complete: #{stats}" if stats["error"]

    results = {
      binary: binary,
      root: root,
      initialize: initialize_response.fetch("result"),
      tools: tools_response.fetch("result").fetch("tools").map { |tool| tool.fetch("name") },
      stats: stats,
      queries: {
        search_file_classifier_view: call_tool(stdin, stdout, id += 1, "search_declarations", {
          query: "FileClassifier#view?",
          limit: 20
        }),
        get_file_classifier_view: call_tool(stdin, stdout, id += 1, "get_declaration", {
          name: "Metz::FileClassifier#view?()"
        }),
        find_file_classifier_constant_references: call_tool(stdin, stdout, id += 1, "find_constant_references", {
          name: "Metz::FileClassifier",
          limit: 100
        }),
        find_file_classifier_method_reference_attempt: call_tool(stdin, stdout, id += 1, "find_constant_references", {
          name: "Metz::FileClassifier#view?()",
          limit: 100
        }),
        base_descendants: call_tool(stdin, stdout, id += 1, "get_descendants", {
          name: "RuboCop::Cop::Metz::Base",
          limit: 100
        }),
        search_views_deep_navigation: call_tool(stdin, stdout, id += 1, "search_declarations", {
          query: "ViewsDeepNavigation",
          limit: 100
        }),
        views_deep_navigation_references: call_tool(stdin, stdout, id += 1, "find_constant_references", {
          name: "RuboCop::Cop::Metz::ViewsDeepNavigation",
          limit: 100
        }),
        views_deep_navigation_test_declarations: call_tool(stdin, stdout, id += 1, "get_file_declarations", {
          file_path: "rubocop-metz/test/cop/metz/views_deep_navigation_test.rb"
        })
      },
      stderr: stderr_lines
    }

    puts JSON.pretty_generate(results)

    stdin.close
    stderr_reader.join(1)
  end
ensure
  stdin.close if stdin && !stdin.closed?
  stdout.close if stdout && !stdout.closed?
  stderr.close if stderr && !stderr.closed?
  Process.kill("TERM", wait_thr.pid) if wait_thr&.alive?
end
