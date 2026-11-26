# frozen_string_literal: true

require "json"

module MetzScan
  module Commands
    class Scan
      class BaselineLoader
        class Error < StandardError; end

        def self.load(path) = new(path).load

        def initialize(path)
          @path = path
        end

        def load
          validate_path!
          validate_report!(parse_json(read_file))
        end

        private

        attr_reader :path

        def validate_path!
          raise Error, "no such file or directory" unless File.exist?(path)
          raise Error, "is a directory, expected a JSON scan report file" if File.directory?(path)
        end

        def read_file
          File.read(path)
        rescue SystemCallError => e
          raise Error, "cannot read file (#{e.message})"
        end

        def parse_json(raw)
          JSON.parse(raw)
        rescue JSON::ParserError
          raise Error, "invalid JSON"
        end

        def validate_report!(report)
          return report if valid_report?(report)

          raise Error, "not a valid scan report (expected files[].offenses)"
        end

        def valid_report?(report)
          report.is_a?(Hash) && valid_files?(report["files"]) && valid_suppressions?(report["suppressions"])
        end

        def valid_files?(files)
          files.is_a?(Array) && files.all? { |file| valid_file?(file) }
        end

        def valid_file?(file)
          file.is_a?(Hash) && valid_path_string?(file["path"]) && valid_offenses?(file["offenses"])
        end

        def valid_offenses?(offenses)
          offenses.is_a?(Array) && offenses.all? { |offense| valid_offense?(offense) }
        end

        def valid_offense?(offense)
          offense.is_a?(Hash) && offense["cop_name"].is_a?(String) &&
            offense["message"].is_a?(String) && valid_location?(offense["location"])
        end

        def valid_location?(location)
          return true if location.nil?

          location.is_a?(Hash) && valid_coord?(location["start_line"]) && valid_coord?(location["start_column"])
        end

        def valid_coord?(value) = value.nil? || value.is_a?(Integer)

        def valid_suppressions?(suppressions)
          suppressions.nil? || (suppressions.is_a?(Array) && suppressions.all? { |item| valid_suppression?(item) })
        end

        def valid_suppression?(item)
          item.is_a?(Hash) && (item["path"].nil? || valid_path_string?(item["path"]))
        end

        def valid_path_string?(value) = value.is_a?(String) && !value.include?("\0")
      end
    end
  end
end
