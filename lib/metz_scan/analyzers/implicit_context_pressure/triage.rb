# frozen_string_literal: true

module MetzScan
  module Analyzers
    class ImplicitContextPressure
      module Triage
        CATEGORY_TRIAGE = {
          "root_current_read" => {
            triage_summary: "Candidate application Current signal; review whether callers should receive context.",
            why: "Application-wide Current reads hide dependencies from method signatures and make workflows " \
                 "harder to reason about.",
            suggested_next_moves: [
              "Pass the context value explicitly into collaborators that use it.",
              "Keep request-scoped globals at application boundaries when possible."
            ]
          },
          "root_current_write" => {
            triage_summary: "Candidate mutable application Current signal; review whether writes should stay at " \
                            "request boundaries.",
            why: "Mutable application Current access hides both dependency and mutation order from the callers " \
                 "that depend on it.",
            suggested_next_moves: [
              "Keep Current writes near request, job, or tenant setup boundaries.",
              "Pass context explicitly once domain collaborators need the value."
            ]
          },
          "namespaced_current_read" => {
            triage_summary: "Candidate namespaced Current signal; review whether the namespace is leaking ambient " \
                            "context.",
            why: "Namespaced Current reads can make a package depend on ambient state owned by another namespace.",
            suggested_next_moves: [
              "Pass the namespaced context value into collaborators that use it repeatedly.",
              "Keep namespace-owned Current access behind the namespace boundary when possible."
            ]
          },
          "namespaced_current_write" => {
            triage_summary: "Candidate namespaced Current signal with writes; review whether mutation should stay " \
                            "at namespace boundaries.",
            why: "Namespaced Current writes spread mutation order across packages and make the ambient context " \
                 "harder to audit.",
            suggested_next_moves: [
              "Keep namespaced Current writes near the boundary that establishes the namespace context.",
              "Pass explicit context to downstream collaborators instead of writing ambient state mid-workflow."
            ]
          },
          "thread_current_read" => {
            triage_summary: "Candidate Thread.current signal; review whether thread-local dependencies should be " \
                            "explicit.",
            why: "Repeated thread-local reads hide dependencies from method signatures and make context setup " \
                 "harder to audit.",
            suggested_next_moves: [
              "Pass the thread-local value explicitly into collaborators that use it repeatedly.",
              "Keep thread-local reads at framework, request, or instrumentation boundaries when possible."
            ]
          },
          "thread_current_write" => {
            triage_summary: "Candidate mutable Thread.current signal; review whether thread-local writes should " \
                            "stay at setup boundaries.",
            why: "Repeated thread-local writes hide mutation order in ambient state and make cleanup requirements " \
                 "harder to audit.",
            suggested_next_moves: [
              "Keep Thread.current writes near setup/teardown boundaries that own the thread-local lifecycle.",
              "Pass explicit context to downstream collaborators instead of mutating thread-local state mid-flow."
            ]
          }
        }.freeze
        private_constant :CATEGORY_TRIAGE

        private

        def implicit_context_category_for(ambient_context, grouped)
          return "thread_current_#{access_category_for(grouped)}" if grouped.context_kind == "thread_current"

          "#{current_receiver_scope_for(ambient_context)}_current_#{access_category_for(grouped)}"
        end

        def current_receiver_scope_for(ambient_context)
          ambient_context.include?("::Current.") ? "namespaced" : "root"
        end

        def current_attribute_for(ambient_context)
          ambient_context.split(".").last
        end

        def access_category_for(grouped)
          grouped.access_modes.include?("write") ? "write" : "read"
        end

        def access_phrase(grouped)
          return "read and written" if mixed_access?(grouped)
          return "written" if grouped.access_modes.include?("write")

          "read"
        end

        def mixed_access?(grouped)
          grouped.access_modes.include?("read") && grouped.access_modes.include?("write")
        end

        def category_triage_attributes(category)
          profile = CATEGORY_TRIAGE.fetch(category)

          { triage_summary: profile.fetch(:triage_summary), why_it_matters: profile.fetch(:why),
            suggested_next_moves: profile.fetch(:suggested_next_moves) }
        end
      end
    end
  end
end
