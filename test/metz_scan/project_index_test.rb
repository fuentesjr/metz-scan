# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require "metz_scan/project_index"

module MetzScan
  class ProjectIndexTest < Minitest::Test
    def test_null_backend_is_explicitly_available_for_disabled_project_analysis
      index = ProjectIndex.build(["."], backend: :null)

      assert_equal :null, index.backend_name
      refute index.available?
      assert_equal "project index disabled", index.reason
      assert_empty_index(index)
    end

    def test_auto_backend_falls_back_to_null_when_rubydex_is_unavailable
      skip "rubydex is available in this bundle" if ProjectIndex::RubydexBackend.available?

      index = ProjectIndex.build(["."], backend: :auto)

      assert_equal :null, index.backend_name
      refute index.available?
      assert_match(/rubydex is not installed/, index.reason)
    end

    def test_requesting_rubydex_backend_fails_clearly_when_unavailable
      skip "rubydex is available in this bundle" if ProjectIndex::RubydexBackend.available?

      error = assert_raises(ProjectIndex::UnavailableBackendError) do
        ProjectIndex.build(["."], backend: :rubydex)
      end

      assert_match(/rubydex is not installed/, error.message)
    end

    def test_unknown_backend_is_rejected
      assert_raises(ProjectIndex::UnknownBackendError) do
        ProjectIndex.build(["."], backend: :missing)
      end
    end

    def test_rubydex_backend_discovers_ruby_files_under_paths
      Dir.mktmpdir do |dir|
        files = ProjectIndex::RubydexBackend.ruby_files_for(write_ruby_file_tree(dir))

        assert_equal expected_ruby_files(dir), files
      end
    end

    def test_rubydex_backend_indexes_when_available
      skip "rubydex is not installed" unless ProjectIndex::RubydexBackend.available?

      Dir.mktmpdir do |dir|
        assert_rubydex_index(index_inheritance_fixture(dir))
      end
    end

    private

    def assert_empty_index(index)
      assert_empty_core_index(index)
      assert_empty_index_queries(index)
    end

    def assert_empty_core_index(index)
      assert_empty index.declarations
      assert_empty index.method_declarations
      assert_empty index.documents
    end

    def assert_empty_index_queries(index)
      assert_empty index.descendants_of("Minitest::Test")
      assert_empty index.constant_references_to("RuboCop::Cop::Metz::OnSendCsendBridge")
      assert_empty index.search("Metz")
    end

    def write_ruby_file_tree(dir)
      nested = File.join(dir, "nested").tap { |path| Dir.mkdir(path) }
      write_ruby_file_tree_files(dir, nested)
      [dir, File.join(dir, "notes.txt")]
    end

    def write_ruby_file_tree_files(dir, nested)
      File.write(File.join(dir, "one.rb"), "class One; end\n")
      File.write(File.join(dir, "notes.txt"), "ignore me\n")
      File.write(File.join(nested, "two.rb"), "class Two; end\n")
    end

    def expected_ruby_files(dir)
      [File.join(dir, "nested", "two.rb"), File.join(dir, "one.rb")].sort
    end

    def write_inheritance_fixture(dir)
      File.write(File.join(dir, "inheritance.rb"),
                 "module SharedBehavior; end\nclass Parent; end\nclass Child < Parent; end\n")
    end

    def index_inheritance_fixture(dir)
      write_inheritance_fixture(dir)
      ProjectIndex.build([dir], backend: :rubydex)
    end

    def assert_rubydex_index(index)
      assert_equal :rubydex, index.backend_name
      assert index.available?
      assert_includes index.descendants_of("Parent"), "Child"
      assert_includes index.search("Parent"), "Parent"
      assert_declaration_kinds(index)
    end

    def assert_declaration_kinds(index)
      assert_equal :class, declaration(index, "Parent").kind
      assert_equal :module, declaration(index, "SharedBehavior").kind
    end

    def declaration(index, name)
      index.declarations.find { |candidate| candidate.name == name }
    end
  end

  class ProjectIndexMethodDeclarationsTest < Minitest::Test
    def test_rubydex_backend_indexes_method_declarations
      skip "rubydex is not installed" unless ProjectIndex::RubydexBackend.available?

      Dir.mktmpdir { |dir| assert_method_declarations(index_method_fixture(dir)) }
    end

    private

    def index_method_fixture(dir)
      write_method_fixture(dir)
      ProjectIndex.build([dir], backend: :rubydex)
    end

    def write_method_fixture(dir)
      File.write(File.join(dir, "methods.rb"), method_fixture_source)
    end

    def method_fixture_source
      <<~RUBY
        class Parent
          def perform; end
          def self.perform; end
        end

        class Child < Parent
          def perform; end
          def self.perform; end
        end
      RUBY
    end

    def assert_method_declarations(index)
      assert_method_declaration(index, method_expectation("Parent", "perform", "instance", 2))
      assert_method_declaration(index, method_expectation("Parent", "perform", "singleton", 3))
      assert_method_declaration(index, method_expectation("Child", "perform", "instance", 7))
      assert_method_declaration(index, method_expectation("Child", "perform", "singleton", 8))
    end

    def assert_method_declaration(index, expected)
      declaration = method_declaration(index, expected)
      assert declaration
      assert_method_identity(declaration, expected)
      assert_equal "#{expected.fetch(:method_name)}()", declaration.signature
      assert_equal expected.fetch(:line), declaration.line
    end

    def assert_method_identity(declaration, expected)
      assert_equal expected.fetch(:receiver_kind), declaration.receiver_kind
      assert_equal expected.fetch(:method_identity), declaration.method_identity
    end

    def method_expectation(owner_name, method_name, receiver_kind, line)
      { owner_name: owner_name, method_name: method_name, receiver_kind: receiver_kind, line: line,
        method_identity: "#{receiver_kind}:#{method_name}" }
    end

    def method_declaration(index, expected)
      index.method_declarations.find do |declaration|
        declaration.owner_name == expected.fetch(:owner_name) &&
          declaration.method_name == expected.fetch(:method_name) &&
          declaration.receiver_kind == expected.fetch(:receiver_kind)
      end
    end
  end

  class ProjectIndexWorkspaceTest < Minitest::Test
    def test_workspace_index_uses_requested_path_instead_of_current_directory
      skip "rubydex is not installed" unless ProjectIndex::RubydexBackend.available?

      with_workspace_fixture do |workspace|
        index = ProjectIndex.build([workspace], backend: :rubydex, workspace: true)
        assert_workspace_marker_index(index)
      end
    end

    private

    def with_workspace_fixture
      Dir.mktmpdir { |workspace| with_other_fixture(workspace) { yield workspace } }
    end

    def with_other_fixture(workspace, &)
      Dir.mktmpdir { |other_dir| use_other_fixture(workspace, other_dir, &) }
    end

    def use_other_fixture(workspace, other_dir, &)
      write_workspace_root_fixture(workspace)
      write_other_root_fixture(other_dir)
      Dir.chdir(other_dir, &)
    end

    def write_workspace_root_fixture(dir)
      File.write(File.join(dir, "workspace_root_marker.rb"), "class WorkspaceRootMarker; end\n")
    end

    def write_other_root_fixture(dir)
      File.write(File.join(dir, "other_root_marker.rb"), "class OtherRootMarker; end\n")
    end

    def assert_workspace_marker_index(index)
      assert_includes index.search("WorkspaceRootMarker"), "WorkspaceRootMarker"
      refute_includes index.search("OtherRootMarker"), "OtherRootMarker"
    end
  end
end
