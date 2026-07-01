# frozen_string_literal: true

module MetzScan
  class ProjectIndex
    class RubydexBackend
      module FileDiscovery
        RUBY_GLOB = "**/*.rb"
        private_constant :RUBY_GLOB

        def ruby_files_for(paths)
          paths.flat_map { |path| ruby_files_under(path) }.uniq.sort
        end

        def workspace_path_for(paths)
          expanded = File.expand_path(paths.first || Dir.pwd)
          return expanded if File.directory?(expanded)

          File.dirname(expanded)
        end

        private

        def ruby_files_under(path)
          expanded = File.expand_path(path)
          return Dir.glob(File.join(expanded, RUBY_GLOB)) if File.directory?(expanded)
          return [expanded] if File.file?(expanded) && File.extname(expanded) == ".rb"

          []
        end
      end
    end
  end
end
