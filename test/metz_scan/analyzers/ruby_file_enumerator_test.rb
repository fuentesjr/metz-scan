# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/ruby_file_enumerator"

module MetzScan
  module Analyzers
    class RubyFileEnumeratorTest < Minitest::Test
      def test_expands_directories_and_files_to_sorted_unique_ruby_paths
        Dir.mktmpdir do |dir|
          ruby_file, nested_file = write_file_tree(dir)

          files = RubyFileEnumerator.new(paths: [dir, ruby_file]).call

          assert_equal [ruby_file, nested_file].sort, files
        end
      end

      def test_uses_available_index_when_paths_are_empty
        files = RubyFileEnumerator.new(paths: [], index: fake_index(["indexed.rb"])).call

        assert_equal ["indexed.rb"], files
      end

      def test_returns_empty_when_no_paths_and_no_available_index
        files = RubyFileEnumerator.new(paths: [], index: fake_index(["indexed.rb"], available: false)).call

        assert_empty files
      end

      private

      def write_file_tree(dir)
        nested = File.join(dir, "nested")
        FileUtils.mkdir_p(nested)
        write_files(File.join(dir, "a.rb"), File.join(nested, "b.rb"), File.join(dir, "ignored.txt"))
      end

      def write_files(*paths)
        paths.each { |path| File.write(path, "") }
        paths.first(2)
      end

      def fake_index(files, available: true)
        Struct.new(:indexed_files, :available, keyword_init: true) do
          def available? = available
        end.new(indexed_files: files, available: available)
      end
    end
  end
end
