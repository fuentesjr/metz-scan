# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzOnSendCsendBridgeTest < Minitest::Test
  def test_aliases_on_send_when_included_before_definition
    klass = Class.new do
      include RuboCop::Cop::Metz::OnSendCsendBridge

      def on_send(node); end
    end

    assert_same_handler klass
  end

  def test_aliases_existing_on_send_when_included_after_definition
    klass = Class.new do
      def on_send(node); end

      include RuboCop::Cop::Metz::OnSendCsendBridge
    end

    assert_same_handler klass
  end

  def test_does_not_define_on_csend_without_on_send
    klass = Class.new do
      include RuboCop::Cop::Metz::OnSendCsendBridge
    end

    refute_includes klass.instance_methods(false), :on_csend
  end

  private

  def assert_same_handler(klass)
    assert_includes klass.instance_methods(false), :on_csend
    assert_equal klass.instance_method(:on_send), klass.instance_method(:on_csend)
  end
end
