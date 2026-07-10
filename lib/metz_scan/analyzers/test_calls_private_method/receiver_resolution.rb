# frozen_string_literal: true

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      module ReceiverResolution
        def receiver_target(receiver, scopes)
          return unless receiver
          return const_receiver_target(receiver) if receiver.const_type?
          return send_receiver_target(receiver, scopes) if send_like?(receiver)

          assigned_receiver_target(receiver, scopes) if VARIABLE_TYPES.include?(receiver.type)
        end

        def const_receiver_target(receiver)
          { owner_name: receiver.const_name, receiver_kind: "singleton" }
        end

        def send_receiver_target(receiver, scopes)
          owner_name = new_receiver_owner(receiver, scopes) || subject_receiver_owner(receiver, scopes)
          { owner_name: owner_name, receiver_kind: "instance" } if owner_name
        end

        def assigned_receiver_target(receiver, scopes)
          owner_name = assigned_owner_for(receiver.children.first.to_s, scopes, receiver.type)
          { owner_name: owner_name, receiver_kind: "instance" } if owner_name
        end

        def new_receiver_owner(node, scopes)
          return unless send_like?(node) && node.method_name == :new

          owner_for_new_receiver(node.receiver, scopes)
        end

        def owner_for_new_receiver(receiver, scopes)
          return receiver.const_name if receiver&.const_type?

          current_sut_name(scopes) if described_class_call?(receiver)
        end

        def subject_receiver_owner(node, scopes)
          return unless bare_call?(node)

          node.method_name == :subject ? bare_subject_owner(scopes) : named_subject_owner(node.method_name, scopes)
        end

        def named_subject_owner(name, scopes)
          scope = scopes.reverse.find { |candidate| candidate.subject_definitions.key?(name) }
          scope&.subject_definitions&.fetch(name) == :sut ? scope.sut_name : nil
        end

        def bare_subject_owner(scopes)
          return if scopes.any? { |scope| scope.subject_definitions[:subject] == :non_sut }

          explicit_subject_owner(scopes) || current_sut_name(scopes)
        end

        def explicit_subject_owner(scopes)
          scope = scopes.reverse.find { |candidate| candidate.subject_definitions[:subject] == :sut }
          scope&.sut_name
        end

        def assigned_owner_for(name, scopes, variable_type)
          variable_type == :lvar ? local_owner_for(name, scopes) : instance_owner_for(name, scopes)
        end

        def local_owner_for(name, scopes)
          scope = scopes.reverse.find { |candidate| candidate.kind == :local && candidate.assignments.key?(name) }
          scope&.assignments&.fetch(name)
        end

        def instance_owner_for(name, scopes)
          owner_values = scopes.select { |scope| scope.assignments.key?(name) }
                               .map { |scope| scope.assignments.fetch(name) }
          owner_values.one? ? owner_values.first : nil
        end
      end
    end
  end
end
