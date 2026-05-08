# frozen_string_literal: true

# Audit driver for `Metz::Test::CopHelper`.
#
# Runs `inverted_assertions.rb` in a subprocess. That file contains
# Minitest tests that DELIBERATELY use the helper macros incorrectly
# (refute_offense against an actual offense, assert_offense with the
# wrong caret pattern, etc.). If the harness is correct, every one of
# those assertions must fail and Minitest must exit non-zero.
#
# The audit succeeds (exits 0) iff Minitest exits non-zero on the
# inverted file AND its output mentions failures/errors. Conversely the
# audit fails (exits 1) if Minitest reports the inverted suite as green
# -- that would mean the helper is silently green, which is a regression.
#
# Invocation:
#   bundle exec ruby -Irubocop-metz/lib -Irubocop-metz/test \
#     rubocop-metz/test/audit/cop_helper_inverted_audit.rb

require "open3"

inverted_path = File.expand_path("inverted_assertions.rb", __dir__)
load_paths = [
  File.expand_path("../../lib", __dir__),
  File.expand_path("..", __dir__)
]

cmd = [RbConfig.ruby, *load_paths.flat_map { |p| ["-I", p] }, inverted_path]
stdout, stderr, status = Open3.capture3(*cmd)

if status.success?
  warn "AUDIT FAIL: Minitest exited 0 on the inverted-assertions file. " \
       "The helper is silently green -- it should have surfaced failures."
  warn "----- STDOUT -----"
  warn stdout
  warn "----- STDERR -----"
  warn stderr
  exit 1
end

failures_match = stdout.match(/(\d+)\s+failures?,\s+(\d+)\s+errors?/)
unless failures_match
  warn "AUDIT FAIL: could not locate Minitest failure summary in the subprocess output."
  warn "----- STDOUT -----"
  warn stdout
  warn "----- STDERR -----"
  warn stderr
  exit 1
end

failures = failures_match[1].to_i
errors = failures_match[2].to_i
total = failures + errors

if total < 1
  warn "AUDIT FAIL: subprocess returned non-zero but reported zero failures/errors."
  warn "----- STDOUT -----"
  warn stdout
  exit 1
end

puts "AUDIT PASS: helper produced #{failures} failure(s) and #{errors} error(s) " \
     "for the inverted assertions, as required."
puts "Subprocess exit status: #{status.exitstatus}"
exit 0
