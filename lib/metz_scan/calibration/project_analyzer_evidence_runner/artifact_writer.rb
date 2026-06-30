# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class ArtifactWriter
        def initialize(summary:, output_dir:, run_id:)
          @summary = summary
          @output_dir = output_dir
          @run_id = run_id || "project-analyzer-evidence-#{Time.now.utc.strftime('%Y%m%d-%H%M%S')}"
        end

        def call
          FileUtils.mkdir_p(run_dir)
          write_json
          write_markdown
          artifacts
        end

        private

        attr_reader :summary, :output_dir, :run_id

        def write_json
          File.write(artifacts.fetch("json"), "#{JSON.pretty_generate(persisted_summary)}\n")
        end

        def write_markdown
          File.write(artifacts.fetch("markdown"), MarkdownRenderer.new(persisted_summary).call)
        end

        def persisted_summary
          summary.merge("artifacts" => artifacts)
        end

        def artifacts
          { "directory" => run_dir, "json" => File.join(run_dir, "summary.json"),
            "markdown" => File.join(run_dir, "summary.md") }
        end

        def run_dir
          File.join(File.expand_path(output_dir), run_id)
        end
      end
    end
  end
end
