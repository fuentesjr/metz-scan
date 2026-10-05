# frozen_string_literal: true

require "yaml"

module MetzScan
  module Commands
    class Scan
      # Default mode runs --force-default-config, so RuboCop resolves anchored
      # cop Include globs (app/operations/**/*.rb) against the current
      # directory. A file those globs match only from a deeper project root
      # silently loses those cops; this names that once per scan.
      module PathScopedIncludeNote
        FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

        module_function

        def print_note(files, stderr)
          misses = files.filter_map { |file| miss_for(file) }
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

        def miss_for(file)
          anchored_includes.each do |cop_name, pattern|
            root = project_root(file, pattern)
            return [cop_name, pattern, root] if root
          end
          nil
        end

        # The leading directories whose removal lets `pattern` match `file`;
        # nil when `pattern` already matches `file` or matches no suffix of it.
        def project_root(file, pattern)
          parts = file.split("/")
          index = (0...parts.size).find { |i| File.fnmatch?(pattern, parts.drop(i).join("/"), FNMATCH_FLAGS) }
          parts.take(index).join("/") if index&.positive?
        end

        def anchored_includes
          @anchored_includes ||= metz_cop_configs.flat_map do |cop_name, config|
            Array(config["Include"]).reject { |pattern| pattern.start_with?("**/") }
                                    .map { |pattern| [cop_name, pattern] }
          end
        end

        def metz_cop_configs
          require "rubocop-metz"
          YAML.load_file(RuboCop::Metz::Plugin.new.rules(nil).value.to_s).select { |name, _| name.start_with?("Metz/") }
        end

        def file_count(count) = count == 1 ? "1 file" : "#{count} files"
      end
    end
  end
end
