# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class ScanTest < Minitest::Test
      VIOLATING_FIXTURE = <<~RUBY
        # frozen_string_literal: true
        class Sample
          def long_method
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            f = 6
            g = 7
            h = 8
            [a, b, c, d, e, f, g, h]
          end
        end
      RUBY

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-scan-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_text_format_default_groups_by_metz_cop_with_location_lines
        code = scan_violating([@tmpdir])
        assert_text_grouped_output(code)
      end

      def test_text_format_default_is_not_json
        scan_violating([@tmpdir])
        assert_raises(JSON::ParserError) { JSON.parse(@stdout.string) }
      end

      def test_json_format_passes_through_metz_json_formatter_shape
        scan_violating([@tmpdir, "--format", "json"])
        assert_metz_offense_shape
      end

      def test_sarif_format_emits_2_1_0_structure_with_driver_name
        scan_violating([@tmpdir, "--format", "sarif"])
        assert_sarif_2_1_0_shape
      end

      private

      def write_violating_fixture
        File.write(File.join(@tmpdir, "sample.rb"), VIOLATING_FIXTURE)
      end

      def scan_violating(argv)
        write_violating_fixture
        run_scan(argv)
      end

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        if @original_rubocop_cache_root
          ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
        else
          ENV.delete("RUBOCOP_CACHE_ROOT")
        end
      end

      def metz_offense
        @metz_offense ||= json_offenses.find { |o| o["cop_name"].to_s.start_with?("Metz/") }
      end

      def json_offenses
        JSON.parse(@stdout.string).fetch("files").flat_map { |f| f.fetch("offenses") }
      end

      def assert_text_grouped_output(code)
        refute_equal 0, code, "expected non-zero exit when offenses found"
        assert_match(%r{^Metz/}m, @stdout.string, "expected a Metz/* cop heading")
        assert_match(/\.rb:\d+:\d+/, @stdout.string, "expected at least one location line")
        assert_no_stack_trace
      end

      def assert_metz_offense_shape
        refute_nil metz_offense, "expected at least one Metz/* offense"
        %w[why_it_matters fix_safety].each { |k| assert metz_offense.key?(k), "missing #{k}" }
        assert_kind_of Array, metz_offense["suggested_next_moves"]
        assert metz_offense.dig("location", "start_line"), "missing location.start_line"
      end

      def assert_sarif_2_1_0_shape
        doc = JSON.parse(@stdout.string)
        assert_kind_of Array, doc["runs"]
        assert_equal "2.1.0", doc["version"]
        assert_equal "metz-scan", doc.dig("runs", 0, "tool", "driver", "name")
        assert_equal "https://github.com/fuentesjr/metz-scan", doc.dig("runs", 0, "tool", "driver", "informationUri")
      end

      def assert_no_stack_trace
        combined = @stdout.string + @stderr.string
        refute_match(/Traceback/, combined, "output should not contain a Ruby traceback")
        refute_match(/\.rb:\d+:in [`']/, combined, "output should not contain a stack frame")
      end
    end

    class ScanCopSelectionTest < Minitest::Test
      STOCK_STYLE_FIXTURE = <<~RUBY
        answer=1
      RUBY
      DISABLING_PROJECT_CONFIG = <<~YAML
        AllCops:
          DisabledByDefault: true
        Metz/MethodsTooLong:
          Enabled: false
          Max: 200
      YAML
      METZ_VIOLATING_FIXTURE = <<~RUBY
        # frozen_string_literal: true
        class Sample
          def long_method
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            f = 6
            g = 7
            h = 8
            [a, b, c, d, e, f, g, h]
          end
        end
      RUBY

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-cop-selection-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_default_scan_ignores_stock_rubocop_cops_without_project_config
        write_stock_style_fixture
        code = run_scan([@tmpdir, "--format", "json"])

        assert_equal 0, code, "expected stock-only offenses to be hidden by default"
        refute_includes cop_names, "Layout/SpaceAroundOperators"
      end

      def test_all_cops_restores_full_rubocop_suite
        write_stock_style_fixture
        code = run_scan([@tmpdir, "--all-cops", "--format", "json"])

        refute_equal 0, code, "expected --all-cops to report stock RuboCop offenses"
        assert_includes cop_names, "Layout/SpaceAroundOperators"
      end

      def test_default_scan_reports_metz_cops_when_project_config_disables_them
        write_disabling_project_config
        write_metz_violating_fixture
        code = run_scan([@tmpdir, "--format", "json"])

        refute_equal 0, code, "expected Metz offenses despite target project config"
        assert_includes cop_names, "Metz/MethodsTooLong"
      end

      private

      def write_stock_style_fixture
        File.write(File.join(@tmpdir, "stock_style.rb"), STOCK_STYLE_FIXTURE)
      end

      def write_metz_violating_fixture
        File.write(metz_violating_path, METZ_VIOLATING_FIXTURE)
      end

      def write_disabling_project_config
        File.write(File.join(@tmpdir, ".rubocop.yml"), DISABLING_PROJECT_CONFIG)
      end

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def cop_names
        JSON.parse(@stdout.string).fetch("files")
            .flat_map { |file| file.fetch("offenses") }
            .map { |offense| offense.fetch("cop_name") }
      end

      def metz_violating_path
        File.join(@tmpdir, "metz_violating.rb")
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end
    end

    class ScanOptInCopSelectionTest < Minitest::Test
      FIXTURE_APP = File.expand_path("../../fixtures/test_reaches_private_app", __dir__)

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        create_tmpdir
        copy_fixture_app
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_default_scan_hides_opt_in_testing_cops
        run_scan([@tmpdir, "--format", "json"])

        refute_includes cop_names, "Metz/TestReachesPrivate"
        refute_includes cop_names, "Metz/TestStubsSubject"
        assert_includes cop_names, "Metz/MethodsTooLong"
      end

      def test_all_cops_with_project_enablement_reports_opt_in_testing_cops
        run_scan([@tmpdir, "--all-cops", "--format", "json"])

        assert_includes cop_names, "Metz/TestReachesPrivate"
        assert_includes cop_names, "Metz/TestStubsSubject"
      end

      private

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def create_tmpdir
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-opt-in-cop-test", tmp_root)
      end

      def copy_fixture_app
        FileUtils.cp_r("#{FIXTURE_APP}/.", @tmpdir)
      end

      def cop_names
        JSON.parse(@stdout.string).fetch("files")
            .flat_map { |file| file.fetch("offenses") }
            .map { |offense| offense.fetch("cop_name") }
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end
    end

    class ScanProjectExcludeTest < Minitest::Test
      EXCLUDING_PROJECT_CONFIG = <<~YAML
        AllCops:
          Exclude:
            - "lib/templates/**/*"
      YAML
      TEMPLATE_FIXTURE = "class <%= @name %> < ActiveRecord::Migration\nend\n"

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-project-exclude-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_default_scan_honors_project_all_cops_excludes_for_syntax_files
        write_excluding_project_config
        write_template_fixture
        assert_default_scan_has_no_template_syntax_offenses
      end

      def test_default_scan_matches_all_cops_project_file_set
        write_excluding_project_config
        write_metz_violating_fixture
        write_template_fixture
        assert_default_and_all_cops_file_paths_match
      end

      private

      def assert_default_scan_has_no_template_syntax_offenses
        code = run_scan([@tmpdir, "--format", "json"])
        assert_equal 0, code
        refute_includes cop_names, "Lint/Syntax"
        refute_includes file_paths, template_path
      end

      def assert_default_and_all_cops_file_paths_match
        default_paths = scan_file_paths([@tmpdir, "--format", "json"])
        all_cops_paths = scan_file_paths([@tmpdir, "--all-cops", "--format", "json"])
        assert_equal all_cops_paths, default_paths
        assert_equal [metz_violating_path], default_paths
      end

      def write_excluding_project_config
        File.write(File.join(@tmpdir, ".rubocop.yml"), EXCLUDING_PROJECT_CONFIG)
      end

      def write_metz_violating_fixture
        File.write(metz_violating_path, ScanCopSelectionTest::METZ_VIOLATING_FIXTURE)
      end

      def write_template_fixture
        FileUtils.mkdir_p(File.dirname(template_path))
        File.write(template_path, TEMPLATE_FIXTURE)
      end

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def scan_file_paths(argv)
        @stdout = StringIO.new
        @stderr = StringIO.new
        code = run_scan(argv)
        refute_equal 2, code
        file_paths
      end

      def cop_names
        JSON.parse(@stdout.string).fetch("files")
            .flat_map { |file| file.fetch("offenses") }
            .map { |offense| offense.fetch("cop_name") }
      end

      def file_paths
        JSON.parse(@stdout.string).fetch("files")
            .map { |file| File.expand_path(file.fetch("path")) }
      end

      def metz_violating_path
        File.join(@tmpdir, "metz_violating.rb")
      end

      def template_path
        File.join(@tmpdir, "lib/templates/migration.rb")
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end
    end

    # Default (Metz-only) mode honors the project's per-cop file *scope*
    # (Include/Exclude) just as #33 made it honor AllCops: Exclude, while still
    # forcing Metz cop *tuning* (Max/Enabled/Severity) to stock defaults. See #37.
    class ScanProjectPerCopExcludeTest < Minitest::Test
      # Loosens the threshold (must be ignored) and scopes the length cop off
      # spec files (must be honored) in a single config.
      EXCLUDE_AND_LOOSEN_CONFIG = <<~YAML
        Metz/MethodsTooLong:
          Max: 200
          Exclude:
            - "spec/**/*"
      YAML
      # Scopes only the length cop off spec files; the coupling cop stays on.
      EXCLUDE_LENGTH_ONLY_CONFIG = <<~YAML
        Metz/MethodsTooLong:
          Exclude:
            - "spec/**/*"
      YAML
      LONG_METHOD_FIXTURE = ScanCopSelectionTest::METZ_VIOLATING_FIXTURE
      # Long (trips MethodsTooLong) AND reaches through an object graph (trips
      # DemeterTrainWreck), proving per-cop exclusion is granular: excluding the
      # length cop must not silence the coupling cop Sandi keeps on tests.
      LONG_AND_COUPLED_SPEC_FIXTURE = <<~RUBY
        # frozen_string_literal: true
        class SampleSpec
          def exercises_behavior
            a = 1
            b = 2
            c = 3
            d = 4
            name = user.account.subscription.plan.name
            [a, b, c, d, name]
          end
        end
      RUBY

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-per-cop-exclude-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      THRESHOLD_FORCED_MSG = "threshold must stay forced for non-excluded files"
      SCOPE_HONORED_MSG = "per-cop Exclude must scope the length cop off spec files"
      LENGTH_EXCLUDED_MSG = "the length cop is excluded on spec files"
      COUPLING_KEPT_MSG = "a coupling smell in a length-excluded spec must still report"

      def test_default_scan_honors_per_cop_exclude_while_forcing_thresholds
        write_config(EXCLUDE_AND_LOOSEN_CONFIG)
        write_fixture("app.rb", LONG_METHOD_FIXTURE)
        write_fixture("spec/thing_spec.rb", LONG_METHOD_FIXTURE)
        assert_scope_honored_and_thresholds_forced
      end

      def test_per_cop_exclude_is_granular_and_keeps_the_coupling_cop
        write_config(EXCLUDE_LENGTH_ONLY_CONFIG)
        write_fixture("spec/thing_spec.rb", LONG_AND_COUPLED_SPEC_FIXTURE)
        assert_length_excluded_but_coupling_reported
      end

      private

      def assert_scope_honored_and_thresholds_forced
        run_scan([@tmpdir, "--format", "json"])
        assert_includes cops_for("app.rb"), "Metz/MethodsTooLong", THRESHOLD_FORCED_MSG
        refute_includes cops_for("spec/thing_spec.rb"), "Metz/MethodsTooLong", SCOPE_HONORED_MSG
      end

      def assert_length_excluded_but_coupling_reported
        run_scan([@tmpdir, "--format", "json"])
        cops = cops_for("spec/thing_spec.rb")
        refute_includes cops, "Metz/MethodsTooLong", LENGTH_EXCLUDED_MSG
        assert_includes cops, "Metz/DemeterTrainWreck", COUPLING_KEPT_MSG
      end

      def write_config(yaml)
        File.write(File.join(@tmpdir, ".rubocop.yml"), yaml)
      end

      def write_fixture(relative_path, contents)
        path = File.join(@tmpdir, relative_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, contents)
      end

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def cops_for(path_suffix)
        JSON.parse(@stdout.string).fetch("files")
            .select { |file| file.fetch("path").end_with?(path_suffix) }
            .flat_map { |file| file.fetch("offenses").map { |offense| offense.fetch("cop_name") } }
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end
    end

    class ScanProjectExternalConfigScopeTest < Minitest::Test
      EXTERNAL_CONFIG_WITH_SCOPE = <<~YAML
        plugins:
          - rubocop-performance
        require:
          - rubocop-rails
        inherit_gem:
          rubocop-rails-omakase: rubocop.yml

        AllCops:
          Exclude:
            - "excluded/**/*"

        Metz/MethodsTooLong:
          Exclude:
            - "spec/**/*"
      YAML

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-external-config-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_default_scan_honors_project_scope_without_loading_external_config_gems
        write_external_config_scope_project
        assert_default_scan_honors_external_config_scope(run_scan([@tmpdir, "--format", "json"]))
      end

      private

      def write_external_config_scope_project
        write_config
        write_fixture("app.rb", ScanCopSelectionTest::METZ_VIOLATING_FIXTURE)
        write_fixture("spec/thing_spec.rb", ScanCopSelectionTest::METZ_VIOLATING_FIXTURE)
        write_fixture("excluded/generated.rb", "class <%= @name %>\nend\n")
      end

      def assert_default_scan_honors_external_config_scope(code)
        assert_scan_completed_with_findings(code)
        assert_includes cops_for("app.rb"), "Metz/MethodsTooLong"
        refute_includes cops_for("spec/thing_spec.rb"), "Metz/MethodsTooLong"
        refute_includes file_paths, File.join(@tmpdir, "excluded/generated.rb")
      end

      def assert_scan_completed_with_findings(code)
        assert_equal 1, code, "findings should report as exit 1, not crash as exit 2"
        assert_unresolved_inherit_gem_warning_once
      end

      # rubocop-rails-omakase isn't in this repo's bundle, so its inherit_gem
      # exclude can't be resolved; the scan now warns once instead of silently
      # dropping that scope (Next Queue item 1).
      def assert_unresolved_inherit_gem_warning_once
        matches = @stderr.string.lines.grep(/rubocop-rails-omakase/)
        assert_equal 1, matches.size, @stderr.string
        assert_match(/not installed/, matches.first)
      end

      def write_config
        File.write(File.join(@tmpdir, ".rubocop.yml"), EXTERNAL_CONFIG_WITH_SCOPE)
      end

      def write_fixture(relative_path, contents)
        path = File.join(@tmpdir, relative_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, contents)
      end

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def cops_for(path_suffix)
        JSON.parse(@stdout.string).fetch("files")
            .select { |file| file.fetch("path").end_with?(path_suffix) }
            .flat_map { |file| file.fetch("offenses").map { |offense| offense.fetch("cop_name") } }
      end

      def file_paths
        JSON.parse(@stdout.string).fetch("files")
            .map { |file| File.expand_path(file.fetch("path")) }
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end
    end

    class ScanTargetRubyVersionTest < Minitest::Test
      TARGET_RUBY_CONFIG = <<~YAML
        AllCops:
          TargetRubyVersion: 3.2
      YAML
      RUBY_31_BLOCK_FORWARDING_FIXTURE = <<~RUBY
        # frozen_string_literal: true
        module Sample
          def wrapper(a, b = {}, &)
            other(a, b, &)
          end
        end
      RUBY

      def test_default_scan_uses_project_target_ruby_version_for_syntax
        Dir.mktmpdir("metz-scan-target-ruby-version-test") do |dir|
          write_target_ruby_fixture(dir)

          assert_no_syntax_offense(scan_subprocess(dir))
          assert_no_syntax_offense(scan_subprocess(dir, "--all-cops"))
        end
      end

      private

      def write_target_ruby_fixture(dir)
        File.write(File.join(dir, ".rubocop.yml"), TARGET_RUBY_CONFIG)
        File.write(File.join(dir, "sample.rb"), RUBY_31_BLOCK_FORWARDING_FIXTURE)
      end

      def assert_no_syntax_offense(result)
        stdout, stderr, status = result
        assert_operator status.exitstatus, :<, 2, stdout + stderr
        refute_includes cop_names(stdout), "Lint/Syntax"
      end

      def cop_names(stdout)
        JSON.parse(stdout).fetch("files")
            .flat_map { |file| file.fetch("offenses") }
            .map { |offense| offense.fetch("cop_name") }
      end

      def scan_subprocess(dir, *flags)
        Open3.capture3(
          subprocess_env,
          "bundle", "exec", RbConfig.ruby, bin_path, "scan", ".", *flags, "--format", "json",
          chdir: dir
        )
      end

      def subprocess_env
        {
          "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil
        }
      end

      def bin_path
        File.join(repo_root, "bin/metz-scan")
      end

      def repo_root
        File.expand_path("../../..", __dir__)
      end
    end

    class ScanUnresolvedInheritGemWarningTest < Minitest::Test
      ABSENT_GEM_CONFIG = <<~YAML
        inherit_gem:
          rubocop-rails-omakase: rubocop.yml
      YAML

      def test_default_scan_warns_once_on_stderr_for_unresolvable_inherit_gem
        Dir.mktmpdir("metz-scan-unresolved-inherit-gem-test") do |dir|
          write_fixture(dir)
          assert_warns_once_without_crashing(scan_subprocess(dir))
        end
      end

      private

      def write_fixture(dir)
        File.write(File.join(dir, ".rubocop.yml"), ABSENT_GEM_CONFIG)
        FileUtils.mkdir_p(File.join(dir, "data"))
        File.write(File.join(dir, "data/x.rb"), "# frozen_string_literal: true\n")
      end

      def assert_warns_once_without_crashing(result)
        stdout, stderr, status = result
        assert_operator status.exitstatus, :<, 2, stdout + stderr
        assert_warning_once(stderr)
        assert JSON.parse(stdout)
      end

      def assert_warning_once(stderr)
        matches = stderr.lines.grep(/rubocop-rails-omakase/)
        assert_equal 1, matches.size, stderr
        assert_match(/not installed/, matches.first)
      end

      def scan_subprocess(dir)
        Open3.capture3(
          subprocess_env,
          "bundle", "exec", RbConfig.ruby, bin_path, "scan", ".", "--format", "json",
          chdir: dir
        )
      end

      def subprocess_env
        {
          "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil
        }
      end

      def bin_path
        File.join(repo_root, "bin/metz-scan")
      end

      def repo_root
        File.expand_path("../../..", __dir__)
      end
    end
  end
end
