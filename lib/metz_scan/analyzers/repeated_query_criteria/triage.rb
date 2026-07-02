# frozen_string_literal: true

module MetzScan
  module Analyzers
    class RepeatedQueryCriteria
      module Triage
        CATEGORY_TRIAGE = {
          "polymorphic_where_criteria" => {
            triage_summary: "Candidate polymorphic query signal; review whether polymorphic lookup rules need a " \
                            "name.",
            why: "Repeated polymorphic query criteria spread type/id coupling across callers and make policy " \
                 "changes harder to find.",
            suggested_next_moves: [
              "Extract a named scope or query object when the polymorphic lookup is a domain concept.",
              "Keep inline polymorphic criteria only when the repetition is mechanical and local."
            ]
          },
          "compound_association_where_criteria" => {
            triage_summary: "Candidate compound association query signal; review whether association pairs need a " \
                            "named query.",
            why: "Repeated compound association criteria can hide a relationship rule in several callers instead " \
                 "of behind one named query.",
            suggested_next_moves: [
              "Extract a named scope when the association pair represents a reusable relationship.",
              "Keep simple join-table lookups inline when the criteria are purely mechanical."
            ]
          },
          "scoped_association_where_criteria" => {
            triage_summary: "Candidate scoped association query signal; review whether scoped criteria belong " \
                            "behind a named query.",
            why: "Repeated association-scoped criteria spread filtering rules across callers and make policy " \
                 "changes harder to find.",
            suggested_next_moves: [
              "Extract a named scope or query object when the predicate represents a reusable business concept.",
              "Keep one-off lookup criteria inline when repetition is incidental or purely local."
            ]
          },
          "where_hash_criteria" => {
            triage_summary: "Candidate repeated query signal; review whether criteria belong behind a named query.",
            why: "Repeated query predicates spread data-access rules across callers and make policy changes " \
                 "harder to find.",
            suggested_next_moves: [
              "Extract a named scope or query object when the predicate represents a reusable business concept.",
              "Keep one-off lookup criteria inline when repetition is incidental or purely local."
            ]
          }
        }.freeze
        MESSAGE_PHRASES = {
          "polymorphic_where_criteria" => "repeats polymorphic query criteria",
          "compound_association_where_criteria" => "repeats compound association query criteria",
          "scoped_association_where_criteria" => "repeats association-scoped query criteria",
          "where_hash_criteria" => "appears"
        }.freeze
        private_constant :CATEGORY_TRIAGE, :MESSAGE_PHRASES

        private

        def repeated_query_category_for(site)
          return "polymorphic_where_criteria" if polymorphic_criteria?(site.criteria_keys)
          return "compound_association_where_criteria" if foreign_key_count(site.criteria_keys) >= 2
          return "scoped_association_where_criteria" if foreign_key_count(site.criteria_keys).positive?

          "where_hash_criteria"
        end

        def polymorphic_criteria?(criteria_keys)
          criteria_keys.any? do |key|
            key.end_with?("_type") && criteria_keys.include?("#{key.delete_suffix('_type')}_id")
          end
        end

        def foreign_key_count(criteria_keys)
          criteria_keys.count { |key| key.end_with?("_id") }
        end

        def criteria_key_shape_for(site)
          repeated_query_category_for(site).delete_suffix("_where_criteria")
        end

        def category_triage_attributes(category)
          profile = CATEGORY_TRIAGE.fetch(category)

          { triage_summary: profile.fetch(:triage_summary), why_it_matters: profile.fetch(:why),
            suggested_next_moves: profile.fetch(:suggested_next_moves) }
        end

        def query_message_phrase(category)
          MESSAGE_PHRASES.fetch(category)
        end
      end
    end
  end
end
