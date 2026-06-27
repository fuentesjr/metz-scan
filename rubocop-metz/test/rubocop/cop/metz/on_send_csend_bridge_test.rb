# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzOnSendCsendBridgeTest < Minitest::Test
  def test_local_base_compatibility_shim_is_removed
    refute defined?(RuboCop::Cop::Metz::Base)
  end

  def test_composes_with_cop_metadata_without_local_base
    klass = Class.new(RuboCop::Cop::Base) do
      exclude_from_registry

      extend Metz::CopMetadata
      include RuboCop::Cop::Metz::OnSendCsendBridge

      why_it_matters "composition matters"
      fix_safety :unsafe
      suggested_next_moves ["include the bridge directly"]
    end

    assert_equal "composition matters", klass.why_it_matters
    assert_equal :unsafe, klass.fix_safety
    assert_equal ["include the bridge directly"], klass.suggested_next_moves
  end

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
