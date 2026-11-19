# frozen_string_literal: true

require "metz_scan/commands/scan/execution_config_store"

module MetzScan
  module Commands
    class Scan
      # Default mode resolves anchored cop Include globs (app/operations/**/*.rb)
      # against the governing .rubocop.yml directory (or the current directory
      # when none exists). A file those globs match only from a deeper project
      # root silently loses those cops; this names that once per scan.
      module PathScopedIncludeNote
        FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

        module_function

        def print_note(files, stderr, exec_store: nil)
          store = exec_store || ExecutionConfigStore.new
          misses = files.filter_map { |file| miss_for(file, store) }
          stderr.puts(note(misses)) unless misses.empty?
        end

        # Nested app trees (engines, spec/dummy) land here too, so the remedy
        # names each root without telling the reader to rescan only that root.
        def note(misses)
          cop_name, pattern, = misses.first
          roots = misses.map(&:last).uniq
          "metz-scan: note: path-scoped cops did not check #{file_count(misses.size)} under #{roots.join(', ')} " \
            "(#{cop_name} matches #{pattern} relative to the current directory); " \
            "scan #{roots.one? ? roots.first : 'each root'} from inside it to check them"
        end

        def miss_for(file, store)
          config = store.for_file(File.expand_path(file))
          target = relative_target(file, config)
          anchored_includes(config).lazy.filter_map { |cop, pat| miss_entry(cop, pat, target) }.first
        end

        def miss_entry(cop_name, pattern, target)
          root = project_root(target, pattern)
          [cop_name, pattern, root] if root
        end

        def relative_target(file, config)
          rel = config.path_relative_to_config(File.expand_path(file))
          rel.start_with?("..") ? file : rel
        end

        # The leading directories whose removal lets `pattern` match `file`;
        # nil when `pattern` already matches `file` or matches no suffix of it.
        def project_root(file, pattern)
          parts = file.split("/")
          index = (0...parts.size).find { |i| File.fnmatch?(pattern, parts.drop(i).join("/"), FNMATCH_FLAGS) }
          parts.take(index).join("/") if index&.positive?
        end

        def anchored_includes(config)
          config.to_h.flat_map do |cop_name, cop_config|
            next [] unless cop_name.start_with?("Metz/") && cop_config.is_a?(Hash)

            Array(cop_config["Include"]).select { |pattern| anchored_pattern?(pattern) }.map { |pat| [cop_name, pat] }
          end
        end

        def anchored_pattern?(pattern)
          pattern.is_a?(String) && !pattern.start_with?("**/") && !Pathname.new(pattern).absolute?
        end

        def file_count(count) = count == 1 ? "1 file" : "#{count} files"
      end
    end
  end
end
