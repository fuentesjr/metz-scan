# frozen_string_literal: true

module MetzScan
  class ProjectIndex
    class RubydexBackend
      module MethodDeclarations
        def method_declarations
          method_declaration_entries.sort_by do |declaration|
            [declaration.owner_name.to_s, declaration.method_name.to_s, declaration.path.to_s,
             declaration.line.to_i]
          end
        end

        private

        def method_declaration_entries
          graph.declarations.select { |declaration| method_declaration?(declaration) }
                            .filter_map { |declaration| method_declaration_for(declaration) }
        end

        def method_declaration?(declaration)
          defined?(Rubydex::Method) && declaration.instance_of?(Rubydex::Method)
        end

        def method_declaration_for(declaration)
          MethodDeclaration.new(**method_declaration_attributes(declaration)) if method_owner_and_signature(declaration)
        end

        def method_declaration_attributes(declaration)
          location = definition_display_location(declaration)
          owner_name, signature = method_owner_and_signature(declaration)
          { name: declaration.name, owner_name: owner_name, method_name: method_name_for(signature),
            signature: signature, path: path_from_location(location), line: line_from_location(location),
            column: column_from_location(location) }
        end

        def method_owner_and_signature(declaration)
          owner_name = owner_name_for(declaration)
          signature = signature_for(declaration.name, owner_name)
          [owner_name, signature] if owner_name && signature
        end

        def owner_name_for(declaration)
          declaration.owner.name if declaration.respond_to?(:owner) && declaration.owner.respond_to?(:name)
        end

        def signature_for(name, owner_name)
          name.to_s.delete_prefix("#{owner_name}#")
              .delete_prefix("#{owner_name}.")
              .delete_prefix("#{owner_name}::")
        end

        def method_name_for(signature)
          signature.to_s.sub(/\(.*\)\z/, "")
        end

        def definition_display_location(declaration)
          definition = declaration.definitions.first if declaration.respond_to?(:definitions)
          display_location_for(definition)
        end

        def line_from_location(location)
          location.start_line if location.respond_to?(:start_line)
        end

        def column_from_location(location)
          location.start_column if location.respond_to?(:start_column)
        end
      end
    end
  end
end
