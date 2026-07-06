# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/file_classifier"
require_relative "../../../metz/cop_metadata"

module RuboCop
  module Cop
    module Metz
      class ControllerClassConstants
        def initialize(method_node)
          @class_node = method_node.each_ancestor(:class).first
        end

        def names
          return [] unless class_node

          (class_names + own_names + qualified_own_names).uniq
        end

        private

        attr_reader :class_node

        def class_names
          return [] unless own_name

          [own_name, lexically_qualified_name].compact.uniq
        end

        def own_name
          @own_name ||= constant_name(class_node.children.first)
        end

        def lexically_qualified_name
          return own_name if own_name.include?("::")
          return nil if namespace.empty?

          (namespace + [own_name]).join("::")
        end

        def namespace
          @namespace ||= class_node.each_ancestor(:class, :module).to_a.reverse.filter_map do |ancestor|
            constant_name(ancestor.children.first)
          end
        end

        def own_names
          @own_names ||= direct_body_children.flat_map { |child| own_names_for(child) }.uniq
        end

        def direct_body_children
          body = class_node.children[2]
          return [] unless body

          body.begin_type? ? body.children : [body]
        end

        def own_names_for(node)
          return casgn_name(node) if node.casgn_type?
          return class_or_module_names(node) if node.class_type? || node.module_type?

          []
        end

        def casgn_name(node)
          return [] unless controller_constant_assignment?(node.children.first)

          [node.children[1].to_s]
        end

        def controller_constant_assignment?(scope)
          return true if scope.nil? || scope.self_type?
          return false unless scope.const_type?

          class_names.include?(scope.const_name)
        end

        def class_or_module_names(node)
          name = constant_name(node.children.first)

          name ? [name, name.split("::").last] : []
        end

        def qualified_own_names
          own_names.flat_map do |name|
            class_names.map { |class_name| "#{class_name}::#{name}" }
          end
        end

        def constant_name(node)
          node&.const_type? ? node.const_name : nil
        end
      end

      class ControllerCollaboratorCollector
        CORE_COLLABORATOR_ALLOWLIST = %w[
          Rails Time Date DateTime File FileUtils Pathname Hash Array String Integer Float
          Symbol Set SecureRandom JSON YAML URI CGI ERB
        ].freeze

        def initialize(method_node)
          @method_node = method_node
          @same_class_constants = ControllerClassConstants.new(method_node).names
        end

        def call
          method_node.each_descendant(:const).with_object({}) do |const_node, ordered|
            record(ordered, const_node)
          end
        end

        private

        attr_reader :method_node, :same_class_constants

        def record(ordered, const_node)
          name = const_node.const_name
          return if name.nil? || ignored?(const_node, name)

          ordered[name] ||= const_node
        end

        def ignored?(const_node, name)
          nested_inside_const?(const_node) ||
            rescue_exception_class?(const_node) ||
            allowed_core_constant?(name) ||
            same_class_constants.include?(name)
        end

        def nested_inside_const?(const_node)
          parent = const_node.parent
          parent&.const_type? && parent.children.first.equal?(const_node)
        end

        def rescue_exception_class?(const_node)
          resbody_node = const_node.each_ancestor(:resbody).first
          return false unless resbody_node

          descendant_of?(const_node, resbody_node.children.first)
        end

        def descendant_of?(node, ancestor)
          return false unless ancestor

          current = node
          current = current.parent while current && !current.equal?(ancestor)
          current.equal?(ancestor)
        end

        def allowed_core_constant?(name)
          root_name = name.delete_prefix("::").split("::").first

          CORE_COLLABORATOR_ALLOWLIST.include?(root_name)
        end
      end

      # Flags Rails controller methods that reach into more than
      # `MaxCollaborators` distinct top-level collaborators. A "direct
      # collaborator" is an application constant referenced inside a method
      # body -- whether bare (`User`), as the receiver of `.new` (`User.new`),
      # or as the receiver of another message (`Mailer.confirmation(...)`).
      # Rescue exception classes, constants owned by the controller class,
      # and core framework/stdlib constants do not count. Multiple references
      # to the same constant count once. The cop is path-classified through
      # `Metz::FileClassifier.controller?` and is silent on any file that is
      # not under `app/controllers/`.
      class ControllersTooManyDirectCollaborators < RuboCop::Cop::Base
        extend ::Metz::CopMetadata

        MSG = "Controller method `%<method>s` reaches into %<count>d " \
              "direct collaborators (%<list>s); " \
              "Max is %<max>d. Reduce by funneling work through a single coordinator."

        why_it_matters "Controllers that touch many collaborators turn into orchestration soup, " \
                       "hiding intent and resisting change."
        fix_safety :manual
        suggested_next_moves [
          "Introduce a single coordinator/service object that owns the multi-step workflow.",
          "Push side-effecting calls into a service the controller invokes once.",
          "Move auxiliary lookups into model scopes or named queries on the primary resource."
        ]

        def on_def(node)
          collaborators = collect_collaborators(node)
          return if collaborators.size <= max_collaborators

          report_offense(node, collaborators)
        end

        def relevant_file?(file)
          return super if file.nil? || file.empty? || file == "(string)"

          !file_name_matches_any?(file, "Exclude", false) &&
            ::Metz::FileClassifier.controller?(file)
        end

        private

        def collect_collaborators(method_node)
          ControllerCollaboratorCollector.new(method_node).call
        end

        def report_offense(method_node, collaborators)
          add_offense(collaborators.values.first, message: build_message(method_node, collaborators))
        end

        def build_message(method_node, collaborators)
          format(MSG,
                 method: method_node.method_name,
                 count: collaborators.size,
                 list: collaborators.keys.join(", "),
                 max: max_collaborators)
        end

        def max_collaborators
          cop_config["MaxCollaborators"] || 1
        end
      end
    end
  end
end
