# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      module OffenseExtractor
        module_function

        def offenses(parsed)
          guidance = parsed["guidance"] || {}
          Array(parsed["files"]).flat_map { |file| file_offenses(file, guidance) }
        end

        def file_offenses(file, guidance)
          Array(file["offenses"]).map { |o| offense_struct(file["path"], o, guidance) }
        end

        def offense_struct(path, offense, guidance)
          loc = offense["location"] || {}
          base_offense(path, offense, guidance).merge(location_fields(loc))
        end

        def base_offense(path, offense, guidance)
          { path: path, cop_name: offense["cop_name"], severity: offense["severity"],
            message: offense["message"], why_it_matters: why_it_matters(offense, guidance),
            project_analyzer: offense["project_analyzer"] }
        end

        # Saved scan JSON keeps per-cop defaults in `guidance`; an offense's own field overrides them.
        def why_it_matters(offense, guidance)
          offense.fetch("why_it_matters") { guidance.dig(offense["cop_name"], "why_it_matters") }
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
