# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    module ScanJsonGuidanceFixtures
      GUIDANCE_FIELDS = %w[why_it_matters suggested_next_moves fix_safety].freeze
      LONG_METHOD_SOURCE = <<~RUBY
        # frozen_string_literal: true
        class Sample
          def long_method
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            [a, b, c, d, e]
          end

          # rubocop:disable Metz/MethodsTooManyParameters -- mirrors upstream interface
          def adapter(a, b, c, d, e)
            [a, b, c, d, e]
          end
          # rubocop:enable Metz/MethodsTooManyParameters
        end
      RUBY
      BRANCHING_SOURCE = <<~RUBY
        # frozen_string_literal: true
        case order.status
        when "pending"
          nil
        when "paid", "cancelled"
          nil
        end
      RUBY
      SERVICE_SOURCE = <<~RUBY
        # frozen_string_literal: true
        class OrdersController
          def create
            ValidateOrder.call(order)
            ReserveInventory.call(order)
            CapturePayment.new(order).call
          end
        end
      RUBY
      SETUP_SOURCE = <<~RUBY
        # frozen_string_literal: true
        module Spree
          module Seeds
            class All
              def call
                Countries.call
                States.call
                Zones.call
              end
            end
          end
        end
      RUBY
      SETUP_GUIDANCE = {
        "why_it_matters" => "Setup orchestration often intentionally runs a list of tasks; review only when it " \
                            "changes often or hides domain workflow pressure.",
        "suggested_next_moves" => [
          "Leave setup orchestration as a list when it is stable and declarative.",
          "Extract a named workflow only when setup steps change together or need clearer sequencing."
        ]
      }.freeze
    end

    module ScanJsonGuidanceReportFixtures
      # Characterization snapshots captured from the pre-change CLI on 2026-10-04.
      FIXTURE_ROOT = File.expand_path("../../fixtures/scan_json_guidance", __dir__)
      LEGACY_TEXT = File.read(File.join(FIXTURE_ROOT, "legacy.txt")).freeze
      LEGACY_ANNOTATIONS = File.read(File.join(FIXTURE_ROOT, "legacy.annotations.txt")).freeze
      EMPTY_OVERRIDE_TEXT = <<~TEXT
        Metz/MethodsTooLong
          sample.rb:3:3 Metz/MethodsTooLong: Method has too many lines. [6/5]

        Summary
        -------
        Metz compliance: 0% (0/1 files clean)
        1 offense across 1 cop

        By cop:
          Metz/MethodsTooLong  1

        Most offenses:
          sample.rb  1
      TEXT
      SETUP_REPORT_TEXT = <<~TEXT
        MetzProject/ServiceSoup
          Why it matters: <why>
          Triage: status: validated; confidence: low; severity: setup orchestration. Setup workflow signal; review only when setup orchestration changes often or hides domain workflow pressure.
          setup_workflow.rb:6:1 Spree::Seeds::All#call coordinates 3 distinct services; consider a workflow object that owns the process.
          setup_workflow.rb:7:1 Spree::Seeds::All#call coordinates 3 distinct services; consider a workflow object that owns the process.
          setup_workflow.rb:8:1 Spree::Seeds::All#call coordinates 3 distinct services; consider a workflow object that owns the process.

        Summary
        -------
        Metz compliance: 100% (1/1 files clean)
        3 offenses across 1 cop

        By cop:
          MetzProject/ServiceSoup  3

        Most offenses:
          setup_workflow.rb  3
      TEXT
    end

    module ScanJsonGuidanceSupport
      include ScanJsonGuidanceFixtures
      include ScanJsonGuidanceReportFixtures

      def setup
        @project = File.realpath(Dir.mktmpdir("metz-scan-json-guidance"))
      end

      def teardown
        FileUtils.remove_entry(@project) if @project
      end
    end

    class ScanJsonGuidanceTest < Minitest::Test
      include ScanJsonGuidanceSupport

      def test_guidance_contains_exactly_the_reported_cops_with_catalog_defaults
        write_mixed_fixture
        doc = scan_json
        assert_mixed_cop_names(doc)
        assert_catalog_guidance(doc)
      end

      def test_clean_scan_emits_an_empty_guidance_object
        write_file("clean.rb", "# frozen_string_literal: true\n")
        doc = scan_json(expected_exit: 0)

        assert_empty offenses(doc)
        assert_equal({}, guidance(doc))
      end

      def test_all_cops_guidance_also_covers_reported_stock_rubocop_cops
        write_file("stock.rb", "answer=1\n")
        doc = scan_json(all_cops: true)
        assert_includes cop_names(doc), "Layout/SpaceAroundOperators"
        assert_equal cop_names(doc), guidance(doc).keys.sort
        guidance(doc).each_value { |entry| assert_guidance_types(entry) }
      end

      def test_guidance_excludes_cops_seen_only_in_suppressions_or_filtered_findings
        write_filtered_fixture
        doc = scan_json(project_analyzers: false)

        assert_equal(["Metz/MethodsTooManyParameters"], doc.fetch("suppressions").map { |item| item.fetch("cop_name") })
        assert_equal ["Metz/MethodsTooLong"], cop_names(doc)
        assert_equal ["Metz/MethodsTooLong"], guidance(doc).keys
      end

      def test_metz_offenses_omit_all_three_fields_equal_to_default_guidance
        write_file("sample.rb", LONG_METHOD_SOURCE)
        write_file("second.rb", LONG_METHOD_SOURCE)
        doc = scan_json

        assert_equal 2, offenses(doc).size
        offenses(doc).each { |offense| assert_empty offense.slice(*GUIDANCE_FIELDS) }
      end

      def test_project_analyzer_offenses_omit_all_three_fields_equal_to_default_guidance
        write_default_analyzer_fixture
        assert_default_analyzer_offenses(scan_json)
      end

      def test_setup_workflow_keeps_only_differing_fields_and_does_not_replace_cop_defaults
        write_file("setup_workflow.rb", SETUP_SOURCE)
        doc = scan_json
        assert_setup_offenses(doc)
        assert_equal catalog_guidance(["MetzProject/ServiceSoup"]), guidance(doc)
      end
    end

    class ScanJsonGuidanceCompatibilityTest < Minitest::Test
      include ScanJsonGuidanceSupport

      def test_other_json_fields_match_the_legacy_scan_including_suppressions_and_analyzer_metadata
        write_mixed_fixture
        actual = strip_guidance(scan_json)
        expected = strip_guidance(legacy_report)
        assert_equal expected, normalize_runtime_metadata(actual)
      end
    end

    class ScanJsonGuidanceReportTest < Minitest::Test
      include ScanJsonGuidanceSupport

      def test_report_from_new_scan_is_byte_identical_to_legacy_text
        write_mixed_fixture
        doc = scan_json
        guidance(doc)

        assert_equal LEGACY_TEXT, report_text(doc)
      end

      def test_report_resolves_shared_guidance_from_a_saved_report
        doc = compact_legacy_report
        archived_why = "Advice archived with this report."
        doc.fetch("guidance").fetch("Metz/MethodsTooLong")["why_it_matters"] = archived_why
        original_why = legacy_method_guidance

        assert_equal LEGACY_TEXT.sub(original_why, archived_why), report_text(doc)
      end

      def test_report_prefers_an_offenses_own_guidance_over_the_shared_entry
        doc = single_file_report("setup_workflow.rb")
        offenses(doc).each { |offense| offense["why_it_matters"] = "Finding-specific setup advice." }
        expected = setup_report_text("Finding-specific setup advice.")
        assert_equal expected, report_text(doc)
      end

      def test_report_treats_an_explicit_empty_guidance_field_as_an_override
        doc = single_file_report("sample.rb")
        offenses(doc).first["why_it_matters"] = ""

        assert_equal EMPTY_OVERRIDE_TEXT, report_text(doc)
      end

      def test_report_still_renders_legacy_json_without_a_guidance_map_byte_for_byte
        assert_equal LEGACY_TEXT, report_text(legacy_report)
      end
    end

    class ScanJsonGuidanceFormatsTest < Minitest::Test
      include ScanJsonGuidanceSupport

      def test_text_scan_output_is_byte_identical_to_the_legacy_output
        write_mixed_fixture

        assert_equal LEGACY_TEXT, scan_output("text")
      end

      def test_sarif_scan_output_is_byte_identical_to_the_legacy_output
        write_mixed_fixture
        assert_equal "#{JSON.generate(legacy_sarif)}\n", scan_output("sarif")
      end

      def test_github_annotations_scan_output_is_byte_identical_to_the_legacy_output
        write_mixed_fixture

        assert_equal LEGACY_ANNOTATIONS, scan_output("gh-annotations")
      end
    end

    module ScanJsonGuidanceSupport
      private

      def write_mixed_fixture
        write_file("sample.rb", LONG_METHOD_SOURCE)
        write_file("branching_a.rb", BRANCHING_SOURCE)
        write_file("branching_b.rb", BRANCHING_SOURCE)
        write_file("orders_controller.rb", SERVICE_SOURCE)
        write_file("setup_workflow.rb", SETUP_SOURCE)
      end

      def write_file(path, source)
        File.write(File.join(@project, path), source)
      end

      def command(*args, expected_exit:)
        stdout, stderr, status = capture_command(args)
        assert_equal expected_exit, status.exitstatus, "#{args.join(' ')} failed: #{stderr}\n#{stdout}"
        stdout
      end

      def capture_command(args)
        Open3.capture3(subprocess_env, "bundle", "exec", RbConfig.ruby, File.join(repo_root, "bin/metz-scan"),
                       *args, chdir: @project)
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def repo_root = File.expand_path("../../..", __dir__)

      def scan_output(format, project_analyzers: true, all_cops: false, expected_exit: 1)
        flags = project_analyzers ? ["--project-analyzers"] : []
        flags << "--all-cops" if all_cops
        command("scan", ".", *flags, "--format", format, expected_exit: expected_exit)
      end

      def scan_json(**)
        JSON.parse(scan_output("json", **))
      end

      def offenses(doc)
        doc.fetch("files").flat_map { |file| file.fetch("offenses") }
      end

      def guidance(doc)
        assert doc.key?("guidance"), "scan JSON must contain a top-level guidance object"
        assert_kind_of Hash, doc.fetch("guidance")
        doc.fetch("guidance")
      end

      def catalog_guidance(names)
        names.to_h { |name| [name, catalog_defaults(name)] }
      end

      def catalog_entries
        @catalog_entries ||= load_catalog_entries
      end

      def load_catalog_entries
        cops = JSON.parse(command("rules", "--json", expected_exit: 0))
        analyzers = JSON.parse(command("project-analyzers", "--json", expected_exit: 0))
        cops + analyzers
      end

      def catalog_defaults(name)
        entry = catalog_entries.find { |item| item.fetch("name") == name }
        refute_nil entry, "#{name} must appear in its public catalog"
        defaults = entry.slice(*GUIDANCE_FIELDS)
        defaults["fix_safety"] = "manual" if name.start_with?("MetzProject/")
        defaults
      end

      def assert_guidance_types(entry)
        assert_equal GUIDANCE_FIELDS.sort, entry.keys.sort
        assert_kind_of String, entry.fetch("why_it_matters")
        assert_kind_of String, entry.fetch("fix_safety")
        assert_kind_of Array, entry.fetch("suggested_next_moves")
        entry.fetch("suggested_next_moves").each { |move| assert_kind_of String, move }
      end
    end

    module ScanJsonGuidanceSupport
      private

      def legacy_report
        JSON.parse(File.read(File.join(FIXTURE_ROOT, "legacy.json")).gsub("<project>", @project))
      end

      def legacy_sarif
        snapshot = File.read(File.join(FIXTURE_ROOT, "legacy.sarif.json"))
        snapshot = snapshot.gsub("<project>", @project).sub("<metz-scan-version>", metz_scan_version)
        JSON.parse(snapshot)
      end

      def legacy_method_guidance
        offense = offenses(legacy_report).find { |item| item.fetch("cop_name") == "Metz/MethodsTooLong" }
        offense.fetch("why_it_matters")
      end

      def compact_legacy_report
        doc = legacy_report
        doc["guidance"] = catalog_guidance(cop_names(doc))
        offenses(doc).each { |offense| compact_offense(offense, doc.fetch("guidance")) }
        doc
      end

      def compact_offense(offense, guidance)
        defaults = guidance.fetch(offense.fetch("cop_name"))
        GUIDANCE_FIELDS.each { |field| offense.delete(field) if offense[field] == defaults.fetch(field) }
      end

      def report_text(doc)
        path = File.join(@project, "saved.json")
        File.write(path, JSON.generate(doc))
        command("report", path, expected_exit: 1)
      end

      def normalize_runtime_metadata(doc)
        assert_equal runtime_metadata, doc.fetch("metadata")
        doc["metadata"] = doc.fetch("metadata").to_h { |key, _value| [key, "<#{key}>"] }
        doc
      end

      def runtime_metadata
        { "ruby_engine" => RUBY_ENGINE, "ruby_version" => RUBY_VERSION,
          "ruby_patchlevel" => RUBY_PATCHLEVEL.to_s, "ruby_platform" => RUBY_PLATFORM,
          "rubocop_version" => Gem::Specification.find_by_name("rubocop").version.to_s }
      end

      def cop_names(doc)
        offenses(doc).map { |offense| offense.fetch("cop_name") }.uniq.sort
      end

      def assert_mixed_cop_names(doc)
        expected = %w[Metz/MethodsTooLong MetzProject/RepeatedBranching MetzProject/ServiceSoup]
        assert_equal expected, cop_names(doc)
        assert_operator offenses(doc).size, :>, expected.size
      end

      def assert_catalog_guidance(doc)
        assert_equal cop_names(doc), guidance(doc).keys.sort
        assert_equal catalog_guidance(cop_names(doc)), guidance(doc)
        guidance(doc).each_value { |entry| assert_guidance_types(entry) }
      end

      def write_filtered_fixture
        write_file("sample.rb", LONG_METHOD_SOURCE)
        write_file("setup_workflow.rb", SETUP_SOURCE)
      end

      def write_default_analyzer_fixture
        write_file("orders_controller.rb", SERVICE_SOURCE)
        write_file("branching_a.rb", BRANCHING_SOURCE)
        write_file("branching_b.rb", BRANCHING_SOURCE)
      end

      def assert_default_analyzer_offenses(doc)
        assert_equal %w[MetzProject/RepeatedBranching MetzProject/ServiceSoup], cop_names(doc)
        assert_equal 5, offenses(doc).size
        offenses(doc).each { |offense| assert_empty offense.slice(*GUIDANCE_FIELDS) }
      end

      def assert_setup_offenses(doc)
        assert_equal ["MetzProject/ServiceSoup"], cop_names(doc)
        assert_equal 3, offenses(doc).size
        offenses(doc).each { |offense| assert_equal SETUP_GUIDANCE, offense.slice(*GUIDANCE_FIELDS) }
      end

      def strip_guidance(doc)
        doc.delete("guidance")
        offenses(doc).each { |offense| GUIDANCE_FIELDS.each { |field| offense.delete(field) } }
        doc
      end

      def single_file_report(path)
        doc = compact_legacy_report
        doc["files"] = doc.fetch("files").select { |file| file.fetch("path") == path }
        doc.delete("summary")
        doc.delete("suppressions")
        doc
      end

      def metz_scan_version
        command("--version", expected_exit: 0).strip
      end

      def setup_report_text(why)
        SETUP_REPORT_TEXT.sub("<why>", why)
      end
    end
  end
end
