# frozen_string_literal: true

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      module SharedDependencyTriage
        CATEGORY = "shared_dependency"
        CONFIDENCE = "low"
        TRIAGE_SEVERITY = "shared dependency"
        TRIAGE_SUMMARY = "Shared dependency signal; review broad APIs or infrastructure hubs only when " \
                         "they change often or force package-specific callers to know too much."
        WHY = "Broad shared dependencies are often intentional, but they can still reveal global APIs " \
              "that many packages must understand."
        SUGGESTED_NEXT_MOVES = [
          "Leave stable shared APIs alone when callers use a narrow, intentional interface.",
          "Extract package-owned adapters when broad APIs force repeated package-specific knowledge."
        ].freeze
        SHARED_NAME_SEGMENTS = "Config(?:uration)?|Settings?|Current|Core|Events?|Types?|" \
                               "Feature(?:Flag|Toggle)s?|Permissions?|Utils?|Utilities?"
        NAME_SEGMENT_PATTERN =
          /\A(?:#{SHARED_NAME_SEGMENTS})\z/i
        ERROR_SUFFIX_PATTERN = /(?:Error|Exception)\z/
        INFRASTRUCTURE_LIB_SEGMENT_PATTERN =
          /\A(?:cache|caches|errors?|exceptions?|freedom_patches|rate_limiter|redis|scheduler)\z/i
        CALIBRATED_SHARED_SURFACE_PATHS = {
          "ActivityPub::TagManager" => "activitypub/tag_manager.rb",
          "Spree::LineItem" => "spree/line_item.rb",
          "Spree::Money" => "spree/money.rb",
          "Spree::Order" => "spree/order.rb",
          "Spree::Product" => "spree/product.rb",
          "Spree::User" => "spree/user.rb",
          "Spree::Variant" => "spree/variant.rb"
        }.freeze
        private_constant :SHARED_NAME_SEGMENTS, :NAME_SEGMENT_PATTERN, :ERROR_SUFFIX_PATTERN,
                         :INFRASTRUCTURE_LIB_SEGMENT_PATTERN, :CALIBRATED_SHARED_SURFACE_PATHS

        module_function

        def shared?(declaration)
          shared_name?(declaration.name) || shared_path?(declaration.path) || calibrated_shared_surface?(declaration)
        end

        def attributes(status)
          { project_analyzer_status: status, confidence: CONFIDENCE,
            triage_severity: TRIAGE_SEVERITY, triage_summary: TRIAGE_SUMMARY }
        end

        def shared_name?(name)
          segments = name_segments(name)
          segments.any? { |segment| segment.match?(NAME_SEGMENT_PATTERN) } ||
            constant_like_tail?(segments.last) || error_like_tail?(segments.last)
        end

        def shared_path?(path)
          package_parts = PackageMap.package_parts(path)
          return false unless package_parts.first == "lib"

          root_lib_file?(package_parts) || infrastructure_lib_segment?(package_parts)
        end

        def calibrated_shared_surface?(declaration)
          suffix = CALIBRATED_SHARED_SURFACE_PATHS[declaration.name]

          suffix && normalized_path(declaration.path).end_with?(suffix)
        end

        def name_segments(name)
          name.to_s.split("::")
        end

        def constant_like_tail?(segment)
          segment.to_s.match?(/\A[A-Z][A-Z0-9_]*\z/) && segment.to_s.include?("_")
        end

        def error_like_tail?(segment)
          segment.to_s.match?(ERROR_SUFFIX_PATTERN)
        end

        def root_lib_file?(package_parts)
          package_parts[1].to_s.end_with?(".rb")
        end

        def infrastructure_lib_segment?(package_parts)
          File.basename(package_parts[1].to_s, ".rb").match?(INFRASTRUCTURE_LIB_SEGMENT_PATTERN)
        end

        def normalized_path(path)
          path.to_s.split(File::SEPARATOR).join("/")
        end
      end
    end
  end
end
