# frozen_string_literal: true

module MetzScan
  class ProjectIndex
    class RubydexBackend
      module MethodDeclarations
        def method_declarations
          method_declaration_entries.sort_by do |declaration|
            [declaration.owner_name.to_s, declaration.method_identity.to_s, declaration.path.to_s,
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
          attributes = method_declaration_attributes(declaration)
          MethodDeclaration.new(**attributes) if attributes
        end

        def method_declaration_attributes(declaration)
          owner_attributes = method_owner_attributes(declaration)
          return unless owner_attributes

          method_name = method_name_for(owner_attributes.fetch(:signature))
          identity_attributes(declaration, owner_attributes, method_name)
            .merge(location_attributes(declaration))
        end

        def method_owner_and_signature(declaration)
          owner_attributes = method_owner_attributes(declaration)
          [owner_attributes[:owner_name], owner_attributes[:signature]] if owner_attributes
        end

        def method_owner_attributes(declaration)
          raw_owner_name = raw_owner_name_for(declaration)
          signature = signature_for(declaration.name, raw_owner_name)
          return unless raw_owner_name && signature

          { owner_name: normalized_owner_name(raw_owner_name), signature: signature,
            receiver_kind: receiver_kind_for(raw_owner_name) }
        end

        def identity_attributes(declaration, owner_attributes, method_name)
          receiver_kind = owner_attributes.fetch(:receiver_kind)
          { name: declaration.name, owner_name: owner_attributes.fetch(:owner_name), method_name: method_name,
            signature: owner_attributes.fetch(:signature), receiver_kind: receiver_kind,
            method_identity: method_identity_for(receiver_kind, method_name) }
        end

        def location_attributes(declaration)
          location = definition_display_location(declaration)
          { path: path_from_location(location), line: line_from_location(location),
            column: column_from_location(location) }
        end

        def raw_owner_name_for(declaration)
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

        def receiver_kind_for(raw_owner_name)
          singleton_owner_name?(raw_owner_name) ? "singleton" : "instance"
        end

        def normalized_owner_name(raw_owner_name)
          singleton_owner_name?(raw_owner_name) ? singleton_owner_name(raw_owner_name) : raw_owner_name
        end

        def singleton_owner_name?(raw_owner_name)
          singleton_owner_name(raw_owner_name)
        end

        def singleton_owner_name(raw_owner_name)
          owner_name, singleton_tail = raw_owner_name.to_s.split("::<", 2)
          return unless singleton_tail&.delete_suffix(">") == owner_name

          owner_name
        end

        def method_identity_for(receiver_kind, method_name)
          "#{receiver_kind}:#{method_name}"
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
