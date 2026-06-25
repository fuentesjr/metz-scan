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
          base_offense(path, offense).merge(location_fields(loc))
        end

        def base_offense(path, offense)
          { path: path, cop_name: offense["cop_name"], severity: offense["severity"],
            message: offense["message"], why_it_matters: offense["why_it_matters"],
            project_analyzer: offense["project_analyzer"] }
        end

        def location_fields(location)
          { line: location_value(location, "start_line", "line"),
            column: location_value(location, "start_column", "column") }
        end

        def location_value(location, primary_key, fallback_key)
          return location[primary_key] if location.key?(primary_key)
          return location[fallback_key] if location.key?(fallback_key)

          raise KeyError, "RuboCop JSON location missing #{primary_key}/#{fallback_key}"
        end
      end
    end
  end
end
