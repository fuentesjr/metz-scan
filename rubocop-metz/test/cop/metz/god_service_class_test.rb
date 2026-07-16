# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzGodServiceClassTest < Minitest::Test
  include Metz::Test::CopHelper

  def cop_class
    RuboCop::Cop::Metz::GodServiceClass
  end

  def cop_config
    {
      "MaxPublicMethods" => 1,
      "AllowedMethods" => %w[initialize],
      "Severity" => "refactor"
    }
  end

  def test_cop_is_registered_in_global_registry
    klass = RuboCop::Cop::Registry.global.find_by_cop_name("Metz/GodServiceClass")

    assert_equal RuboCop::Cop::Metz::GodServiceClass, klass
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::GodServiceClass.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_includes %i[safe unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_default_yaml_carries_required_keys
    yaml = YAML.load_file(File.expand_path("../../../config/default.yml", __dir__))
    entry = yaml.fetch("Metz/GodServiceClass")

    assert_equal true, entry["Enabled"]
    assert_equal 1, entry["MaxPublicMethods"]
    assert_includes Array(entry["AllowedMethods"]), "initialize"
  end

  def test_fires_on_multi_method_service_class
    source = <<~RUBY
      class UserService
        def create; end
        def update; end
        def deactivate; end
      end
    RUBY

    metz_inspect(source, "app/services/user_service.rb")

    assert_equal 1, @metz_offenses.size
    assert_match(/UserService/, @metz_offenses.first.message)
    assert_match(/3 public methods/, @metz_offenses.first.message)
  end

  def test_fires_outside_services_directory
    source = <<~RUBY
      class BillingService
        def charge; end
        def refund; end
      end
    RUBY

    metz_inspect(source, "lib/billing_service.rb")

    assert_equal 1, @metz_offenses.size
  end

  def test_silent_for_single_entry_service
    source = <<~RUBY
      class ChargeService
        def initialize(order)
          @order = order
        end

        def call
          @order
        end

        private

        def gateway
        end
      end
    RUBY

    refute_offense(source, file: "app/services/charge_service.rb")
  end

  def test_silent_when_class_name_does_not_end_with_service
    source = <<~RUBY
      class Checkout
        def call; end
        def refund; end
      end
    RUBY

    refute_offense(source, file: "app/services/checkout.rb")
  end

  def test_fires_on_namespaced_service_basename
    source = <<~RUBY
      module Billing
        class InvoiceService
          def issue; end
          def void; end
        end
      end
    RUBY

    metz_inspect(source, "app/services/billing/invoice_service.rb")

    assert_equal 1, @metz_offenses.size
    assert_match(/InvoiceService/, @metz_offenses.first.message)
  end
end
