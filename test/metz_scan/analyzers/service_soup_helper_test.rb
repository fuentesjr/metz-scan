# frozen_string_literal: true

require "minitest/autorun"
require "rubocop"

require "metz_scan/analyzers/service_soup/service_call_pattern"

module MetzScan
  module Analyzers
    class ServiceCallPatternTest < Minitest::Test
      def test_matches_constant_class_call_services
        match = ServiceSoup::ServiceCallPattern.new(first_send_node("ValidateOrder.call(order)")).match

        assert_equal "ValidateOrder", match.service_name
        assert_equal :class_call, match.style
      end

      def test_matches_new_service_call
        match = ServiceSoup::ServiceCallPattern.new(first_send_node("Imap::Service.new(order).call")).match

        assert_equal "Imap::Service", match.service_name
        assert_equal :new_call, match.style
      end

      def test_matches_new_service_perform
        match = ServiceSoup::ServiceCallPattern.new(first_send_node("Imap::Service.new(order).perform")).match

        assert_equal "Imap::Service", match.service_name
        assert_equal :new_perform, match.style
      end

      def test_ignores_plain_callable_objects
        match = ServiceSoup::ServiceCallPattern.new(first_send_node("validator.call(order)")).match

        assert_nil match
      end

      private

      def first_send_node(source)
        node = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast
        return node if node&.type == :send

        node&.each_descendant(:send)&.first
      end
    end
  end
end
