# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      module OffenseExtractor
        module_function

        def offenses(parsed)
          Array(parsed["files"]).flat_map { |file| file_offenses(file) }
        end

        def file_offenses(file)
          Array(file["offenses"]).map { |o| offense_struct(file["path"], o) }
        end

        def offense_struct(path, offense)
          loc = offense["location"] || {}
          { path: path, cop_name: offense["cop_name"], severity: offense["severity"],
            line: loc["start_line"] || loc["line"], column: loc["start_column"] || loc["column"],
            message: offense["message"], why_it_matters: offense["why_it_matters"],
            project_analyzer: offense["project_analyzer"] }
        end
      end
    end
  end
end
