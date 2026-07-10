# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

require "metz_scan/analyzers/test_calls_private_method"
require "support/missing_rubydex"

module MetzScan
  module Analyzers
    module TestCallsPrivateMethodSupport
      private

      def with_default_analysis(file_name, source)
        with_project(file_name => source) do |dir, paths|
          yield analyze(paths, private_index(dir)), dir
        end
      end

      def analyze(paths, index)
        TestCallsPrivateMethod.new(paths: paths, index: index).call
      end

      def assert_private_finding(finding, path, line)
        assert_private_identity(finding)
        assert_private_triage(finding)
        assert_private_location(finding, path, line)
      end

      def assert_private_identity(finding)
        assert_equal "MetzProject/TestCallsPrivateMethod", finding.rule_id
        assert_equal "secret", finding.method_name
        assert_equal "private", finding.visibility
        assert_includes finding.message, "private"
      end

      def assert_private_triage(finding)
        assert_equal "candidate", finding.project_analyzer_status
        assert_equal "high", finding.confidence
      end

      def assert_private_location(finding, path, line)
        occurrence = finding.report_occurrences.first
        assert_equal path, occurrence.path
        assert_equal line, occurrence.report_line
        assert_equal "Widget#secret", occurrence.context
      end

      def with_project(files)
        Dir.mktmpdir("metz-scan-private-method") do |dir|
          File.write(production_path(dir), "class Widget; end\n")
          yield dir, files.map { |name, source| write_file(dir, name, source) }
        end
      end

      def write_file(dir, name, source)
        File.write(path_for(dir, name), source)
        path_for(dir, name)
      end

      def path_for(dir, name)
        File.join(dir, name)
      end

      def production_path(dir)
        path_for(dir, "widget.rb")
      end

      def private_index(dir)
        index_for(dir, methods: [private_method("Widget", "secret", production_path(dir))])
      end

      def index_for(dir, declarations: [declaration("Widget", production_path(dir))], methods: [],
                    indexed_files: [])
        FakePrivateMethodIndex.new(declarations: declarations, method_declarations: methods,
                                   indexed_files: indexed_files)
      end

      def declaration(name, path)
        ProjectIndex::Declaration.new(name: name, path: path, kind: :class)
      end

      def private_method(owner_name, method_name, path)
        method_declaration(owner_name: owner_name, method_name: method_name, path: path, visibility: "private")
      end

      def protected_method(owner_name, method_name, path)
        method_declaration(owner_name: owner_name, method_name: method_name, path: path, visibility: "protected")
      end

      def public_method(owner_name, method_name, path)
        method_declaration(owner_name: owner_name, method_name: method_name, path: path, visibility: "public")
      end

      def singleton_private_method(owner_name, method_name, path)
        method_declaration(owner_name: owner_name, method_name: method_name, path: path,
                           visibility: "private", receiver_kind: "singleton")
      end

      def method_declaration(attributes)
        ProjectIndex::MethodDeclaration.new(**method_declaration_attributes(attributes))
      end

      def method_declaration_attributes(attributes)
        attributes.merge(receiver_kind: receiver_kind_for(attributes), line: 1, column: 1,
                         name: declaration_name(attributes), signature: signature_for(attributes),
                         method_identity: method_identity_for(attributes))
      end

      def receiver_kind_for(attributes)
        attributes.fetch(:receiver_kind, "instance")
      end

      def declaration_name(attributes)
        "#{attributes.fetch(:owner_name)}##{attributes.fetch(:method_name)}()"
      end

      def signature_for(attributes)
        "#{attributes.fetch(:method_name)}()"
      end

      def method_identity_for(attributes)
        "#{receiver_kind_for(attributes)}:#{attributes.fetch(:method_name)}"
      end
    end

    module TestCallsPrivateMethodRSpecCoreSources
      private

      def rspec_described_class_source(method_name: "secret")
        <<~RUBY
          RSpec.describe Widget do
            it "reaches private" do
              described_class.new.send(:#{method_name})
            end
          end
        RUBY
      end

      def rspec_safe_navigation_source
        <<~RUBY
          RSpec.describe Widget do
            it "reaches private" do
              described_class.new&.send(:secret)
            end
          end
        RUBY
      end

      def rspec_subject_source
        <<~RUBY
          describe Widget do
            it "reaches private" do
              subject.__send__("secret")
            end
          end
        RUBY
      end

      def rspec_nested_const_source
        <<~RUBY
          describe Widget do
            describe Admin::Widget do
              it "reaches private" do
                described_class.new.send(:secret)
              end
            end
          end
        RUBY
      end

      def rspec_nested_string_context_source
        <<~RUBY
          describe Widget do
            context "state" do
              it "reaches private" do
                subject.send(:secret)
              end
            end
          end
        RUBY
      end

      def rspec_root_string_describe_source
        <<~RUBY
          describe "Widget" do
            it "reaches private" do
              subject.send(:secret)
            end
          end
        RUBY
      end
    end

    module TestCallsPrivateMethodRSpecSubjectSources
      private

      def rspec_shared_examples_source
        <<~RUBY
          shared_examples "private reach" do
            it "reaches private" do
              subject.send(:secret)
            end
          end
        RUBY
      end

      def rspec_named_subject_source
        <<~RUBY
          describe Widget do
            subject(:widget) { described_class.new }
            it "reaches private" do
              widget.send(:secret)
            end
          end
        RUBY
      end

      def rspec_non_sut_subject_source
        <<~RUBY
          describe Widget do
            subject { Object.new }
            it "reaches private" do
              subject.send(:secret)
            end
          end
        RUBY
      end

      def rspec_repeated_local_assignment_source
        <<~RUBY
          RSpec.describe Widget do
            it "reaches private once" do
              widget = Widget.new
              widget.send(:secret)
            end

            it "reaches private twice" do
              widget = Widget.new
              widget.send(:secret)
            end
          end
        RUBY
      end

      def rspec_const_receiver_source
        <<~RUBY
          describe Widget do
            it "reaches private" do
              Widget.send(:secret)
              Widget.send(:class_secret)
            end
          end
        RUBY
      end
    end

    module TestCallsPrivateMethodMinitestSources
      private

      def minitest_subject_source
        <<~RUBY
          require "minitest/autorun"
          class WidgetTest < Minitest::Test
            def test_reaches_private
              subject.send(:secret)
            end
          end
        RUBY
      end

      def minitest_const_new_source
        <<~RUBY
          require "minitest/autorun"
          class WidgetTest < Minitest::Test
            def test_reaches_private
              Widget.new.send(:secret)
            end
          end
        RUBY
      end

      def minitest_describe_source
        <<~RUBY
          describe Widget do
            it "reaches private" do
              subject.send(:secret)
            end
          end
        RUBY
      end

      def minitest_single_lvar_source
        <<~RUBY
          require "minitest/autorun"
          class WidgetTest < Minitest::Test
            def test_reaches_private
              widget = Widget.new
              widget.send(:secret)
            end
          end
        RUBY
      end

      def minitest_single_ivar_source
        <<~RUBY
          require "minitest/autorun"
          class WidgetTest < Minitest::Test
            def setup
              @widget = Widget.new
            end

            def test_reaches_private
              @widget.send(:secret)
            end
          end
        RUBY
      end

      def minitest_ambiguous_assignment_source
        <<~RUBY
          require "minitest/autorun"
          class WidgetTest < Minitest::Test
            def setup
              @widget = Widget.new
              @other = build_widget
            end

            def test_reaches_private
              @widget = Widget.new
              @widget.send(:secret)
              @other.send(:secret)
            end
          end
        RUBY
      end
    end

    class TestCallsPrivateMethodRSpecTest < Minitest::Test
      include TestCallsPrivateMethodSupport
      include TestCallsPrivateMethodRSpecCoreSources
      include TestCallsPrivateMethodRSpecSubjectSources

      def test_reports_described_class_new_private_send
        assert_rspec_private_finding(rspec_described_class_source, 3)
      end

      def test_reports_safe_navigation_send
        assert_rspec_private_finding(rspec_safe_navigation_source, 3)
      end

      def test_reports_bare_subject_private_send
        assert_rspec_private_finding(rspec_subject_source, 3)
      end

      def test_nested_const_describe_uses_nearest_sut
        with_project("widget_spec.rb" => rspec_nested_const_source) do |dir, paths|
          assert_equal "Admin::Widget", analyze(paths, nested_const_index(dir)).first.owner_name
        end
      end

      def test_nested_string_context_inherits_outer_sut
        assert_rspec_private_finding(rspec_nested_string_context_source, 4)
      end

      def test_root_string_describe_has_no_sut
        assert_rspec_no_findings(rspec_root_string_describe_source)
      end

      def test_skips_shared_examples_without_fixed_sut
        assert_rspec_no_findings(rspec_shared_examples_source)
      end

      def test_reports_named_subject_when_subject_body_is_the_sut
        assert_rspec_private_finding(rspec_named_subject_source, 4)
      end

      def test_reports_repeated_sibling_local_assignments
        with_default_analysis("widget_spec.rb", rspec_repeated_local_assignment_source) do |findings, _dir|
          assert_equal 2, findings.size
        end
      end

      def test_skips_subject_redefined_to_non_sut
        assert_rspec_no_findings(rspec_non_sut_subject_source)
      end

      private

      def assert_rspec_private_finding(source, line)
        with_default_analysis("widget_spec.rb", source) do |findings, dir|
          assert_private_finding(findings.first, path_for(dir, "widget_spec.rb"), line)
        end
      end

      def assert_rspec_no_findings(source)
        with_default_analysis("widget_spec.rb", source) { |findings, _dir| assert_empty findings }
      end

      def nested_const_index(dir)
        index_for(dir, declarations: nested_const_declarations(dir), methods: nested_const_methods(dir))
      end

      def nested_const_declarations(dir)
        [declaration("Widget", production_path(dir)), declaration("Admin::Widget", production_path(dir))]
      end

      def nested_const_methods(dir)
        [private_method("Widget", "secret", production_path(dir)),
         private_method("Admin::Widget", "secret", production_path(dir))]
      end
    end

    class TestCallsPrivateMethodMinitestTest < Minitest::Test
      include TestCallsPrivateMethodSupport
      include TestCallsPrivateMethodMinitestSources

      def test_reports_class_demangled_subject
        assert_minitest_private_finding(minitest_subject_source, 4)
      end

      def test_reports_const_new_receiver
        assert_minitest_private_finding(minitest_const_new_source, 4)
      end

      def test_reports_describe_const_sut
        assert_minitest_private_finding(minitest_describe_source, 3)
      end

      def test_reports_single_assignment_local_variable_receiver
        assert_minitest_private_finding(minitest_single_lvar_source, 5)
      end

      def test_reports_single_assignment_instance_variable_receiver
        assert_minitest_private_finding(minitest_single_ivar_source, 8)
      end

      def test_skips_multi_assignment_and_non_const_rhs
        with_default_analysis("widget_test.rb", minitest_ambiguous_assignment_source) do |findings, _dir|
          assert_empty findings
        end
      end

      def test_skips_ambiguous_demangle
        with_project("widget_test.rb" => minitest_subject_source) do |dir, paths|
          assert_empty analyze(paths, ambiguous_demangle_index(dir))
        end
      end

      private

      def assert_minitest_private_finding(source, line)
        with_default_analysis("widget_test.rb", source) do |findings, dir|
          assert_private_finding(findings.first, path_for(dir, "widget_test.rb"), line)
        end
      end

      def ambiguous_demangle_index(dir)
        index_for(dir, declarations: ambiguous_declarations(dir), methods: ambiguous_methods(dir))
      end

      def ambiguous_declarations(dir)
        [declaration("Admin::Widget", production_path(dir)),
         declaration("Storefront::Widget", production_path(dir))]
      end

      def ambiguous_methods(dir)
        [private_method("Admin::Widget", "secret", production_path(dir)),
         private_method("Storefront::Widget", "secret", production_path(dir))]
      end
    end

    class TestCallsPrivateMethodVisibilityTest < Minitest::Test
      include TestCallsPrivateMethodSupport
      include TestCallsPrivateMethodRSpecCoreSources
      include TestCallsPrivateMethodRSpecSubjectSources

      def test_matches_const_receiver_against_singleton_method_only
        with_project("widget_spec.rb" => rspec_const_receiver_source) do |dir, paths|
          assert_singleton_only_finding(analyze(paths, singleton_index(dir)).first)
        end
      end

      def test_skips_reopened_class_when_visibility_conflicts_with_public
        with_project("widget_spec.rb" => rspec_described_class_source) do |dir, paths|
          assert_empty analyze(paths, conflicting_visibility_index(dir))
        end
      end

      def test_skips_when_confirming_declaration_is_in_test_file
        with_project("widget_spec.rb" => rspec_described_class_source) do |dir, paths|
          assert_empty analyze(paths, test_file_declaration_index(dir))
        end
      end

      def test_reports_protected_methods
        with_project("widget_spec.rb" => rspec_described_class_source(method_name: "guarded")) do |dir, paths|
          assert_protected_finding(analyze(paths, protected_index(dir)).first)
        end
      end

      def test_skips_when_method_is_absent_from_index
        with_project("widget_spec.rb" => rspec_described_class_source) do |dir, paths|
          assert_empty analyze(paths, index_for(dir, methods: []))
        end
      end

      private

      def assert_singleton_only_finding(finding)
        assert_equal "class_secret", finding.method_name
        assert_includes finding.message, "Widget.class_secret"
      end

      def assert_protected_finding(finding)
        assert_equal "guarded", finding.method_name
        assert_equal "protected", finding.visibility
        assert_includes finding.message, "protected"
      end

      def singleton_index(dir)
        index_for(dir, methods: [private_method("Widget", "secret", production_path(dir)),
                                 singleton_private_method("Widget", "class_secret", production_path(dir))])
      end

      def conflicting_visibility_index(dir)
        index_for(dir, methods: [private_method("Widget", "secret", production_path(dir)),
                                 public_method("Widget", "secret", production_path(dir))])
      end

      def test_file_declaration_index(dir)
        index_for(dir, methods: [private_method("Widget", "secret", path_for(dir, "widget_spec.rb"))])
      end

      def protected_index(dir)
        index_for(dir, methods: [protected_method("Widget", "guarded", production_path(dir))])
      end
    end

    class TestCallsPrivateMethodIndexInputTest < Minitest::Test
      include TestCallsPrivateMethodSupport
      include TestCallsPrivateMethodRSpecCoreSources

      def test_uses_indexed_files_when_paths_are_empty
        with_project("widget_spec.rb" => rspec_described_class_source) do |dir, paths|
          assert_private_finding(indexed_file_finding(dir, paths), path_for(dir, "widget_spec.rb"), 3)
        end
      end

      def test_skips_when_index_is_unavailable
        with_project("widget_spec.rb" => rspec_described_class_source) do |_dir, paths|
          assert_empty analyze(paths, FakePrivateMethodIndex.new(available: false))
        end
      end

      private

      def indexed_file_finding(dir, paths)
        index = index_for(dir, indexed_files: paths,
                               methods: [private_method("Widget", "secret", production_path(dir))])
        analyze([], index).first
      end
    end

    class TestCallsPrivateMethodRubydexIntegrationTest < Minitest::Test
      include MissingRubydexSupport

      REPO_ROOT = File.expand_path("../../..", __dir__)

      def test_auto_index_reports_findings_when_rubydex_is_available
        skip "rubydex is not installed" unless ProjectIndex::RubydexBackend.available?

        assert_equal ["secret"], rubydex_fixture_findings.map(&:method_name)
      end

      def test_auto_index_contributes_zero_findings_when_rubydex_is_missing
        stdout, stderr, status = capture_missing_rubydex_probe

        assert_predicate status, :success?, stderr
        assert_equal({ "finding_count" => 0 }, JSON.parse(stdout))
      end

      private

      def rubydex_fixture_findings
        Dir.mktmpdir("metz-scan-rubydex-private") do |dir|
          write_rubydex_fixture(dir)
          TestCallsPrivateMethod.new(paths: [dir]).call
        end
      end

      def write_rubydex_fixture(dir)
        write_rubydex_production_file(dir)
        write_rubydex_spec_file(dir)
      end

      def write_rubydex_production_file(dir)
        File.write(File.join(dir, "widget.rb"), "class Widget\n  private def secret; end\nend\n")
      end

      def write_rubydex_spec_file(dir)
        File.write(File.join(dir, "widget_spec.rb"), rubydex_spec_source)
      end

      def rubydex_spec_source
        "RSpec.describe Widget do\n  it { described_class.new.send(:secret) }\nend\n"
      end

      def capture_missing_rubydex_probe
        with_missing_rubydex_shim do |env|
          Open3.capture3(env, RbConfig.ruby, "-Ilib", "-Itest", "-rjson", "-e", missing_rubydex_probe,
                         chdir: REPO_ROOT)
        end
      end

      def missing_rubydex_probe
        <<~RUBY
          require "tmpdir"
          require "metz_scan/analyzers/test_calls_private_method"

          Dir.mktmpdir do |dir|
            File.write(File.join(dir, "widget.rb"), "class Widget\\n  private def secret; end\\nend\\n")
            File.write(File.join(dir, "widget_spec.rb"),
                       "RSpec.describe Widget do\\n  it { described_class.new.send(:secret) }\\nend\\n")
            findings = MetzScan::Analyzers::TestCallsPrivateMethod.new(paths: [dir]).call
            puts JSON.dump("finding_count" => findings.size)
          end
        RUBY
      end
    end

    class FakePrivateMethodIndex
      def initialize(available: true, declarations: [], method_declarations: [], indexed_files: [])
        @available = available
        @declarations = declarations
        @method_declarations = method_declarations
        @indexed_files = indexed_files
      end

      attr_reader :declarations, :method_declarations, :indexed_files

      def available? = @available

      def backend_name = :fake
    end
  end
end
