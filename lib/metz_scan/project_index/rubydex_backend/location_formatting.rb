# frozen_string_literal: true

require "uri"

module MetzScan
  class ProjectIndex
    class RubydexBackend
      module LocationFormatting
        def path_from_location(location)
          return unless location

          path_from_file_location(location) || path_from_uri_location(location) || location.to_s
        end

        def path_from_file_location(location)
          location.to_file_path if location.respond_to?(:to_file_path)
        rescue StandardError
          nil
        end

        def path_from_uri_location(location)
          path_from_uri(location.uri) if location.respond_to?(:uri)
        end

        def path_from_uri(uri)
          string = uri.to_s
          return URI(string).path if string.start_with?("file:")

          string
        rescue URI::InvalidURIError
          string
        end
      end
    end
  end
end
