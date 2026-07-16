# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzOperationsTooManyPublicMethodsTest < Minitest::Test
  include Metz::Test::CopHelper

  SERVICE_PATH = "app/services/checkout.rb"
  OPERATION_PATH = "app/operations/import_accounts.rb"

  def cop_class
    RuboCop::Cop::Metz::OperationsTooManyPublicMethods
  end

  def cop_config
    {
      "MaxPublicMethods" => 1,
      "AllowedMethods" => %w[initialize],
      "Severity" => "refactor"
    }
  end

  def test_cop_is_registered_in_global_registry
    klass = RuboCop::Cop::Registry.global.find_by_cop_name(
      "Metz/OperationsTooManyPublicMethods"
    )

    assert_equal RuboCop::Cop::Metz::OperationsTooManyPublicMethods, klass
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::OperationsTooManyPublicMethods.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_includes %i[safe unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_default_yaml_carries_required_keys
    yaml = YAML.load_file(File.expand_path("../../../config/default.yml", __dir__))
    entry = yaml.fetch("Metz/OperationsTooManyPublicMethods")

    assert_equal true, entry["Enabled"]
    assert_equal 1, entry["MaxPublicMethods"]
    assert_includes Array(entry["AllowedMethods"]), "initialize"
    assert_includes Array(entry["Include"]), "app/services/**/*.rb"
    assert_includes Array(entry["Include"]), "app/operations/**/*.rb"
  end

  def test_fires_on_two_public_methods_in_app_services
    source = <<~RUBY
      class Checkout
        def call
        end

        def refund
        end
      end
    RUBY

    metz_inspect(source, SERVICE_PATH)

    assert_equal 1, @metz_offenses.size
    assert_match(/2 public methods/, @metz_offenses.first.message)
    assert_match(/:call/, @metz_offenses.first.message)
    assert_match(/:refund/, @metz_offenses.first.message)
  end

  def test_fires_on_app_operations_path
    source = <<~RUBY
      class ImportAccounts
        def call; end
        def preview; end
      end
    RUBY

    metz_inspect(source, OPERATION_PATH)

    assert_equal 1, @metz_offenses.size
  end

  def test_silent_with_single_public_call_and_initialize
    source = <<~RUBY
      class Checkout
        def initialize(cart:)
          @cart = cart
        end

        def call
          @cart
        end
      end
    RUBY

    refute_offense(source, file: SERVICE_PATH)
  end

  def test_silent_when_helpers_are_private
    source = <<~RUBY
      class Checkout
        def call
          charge
        end

        private

        def charge
        end

        def notify
        end
      end
    RUBY

    refute_offense(source, file: SERVICE_PATH)
  end

  def test_silent_for_private_def_inline
    source = <<~RUBY
      class Checkout
        def call
        end

        private def charge
        end
      end
    RUBY

    refute_offense(source, file: SERVICE_PATH)
  end

  def test_silent_outside_operation_paths
    source = <<~RUBY
      class Checkout
        def call; end
        def refund; end
      end
    RUBY

    refute_offense(source, file: "app/models/checkout.rb")
  end

  def test_counts_singleton_public_methods
    source = <<~RUBY
      class Checkout
        def self.call
        end

        def self.preview
        end
      end
    RUBY

    metz_inspect(source, SERVICE_PATH)

    assert_equal 1, @metz_offenses.size
    assert_match(/:call/, @metz_offenses.first.message)
    assert_match(/:preview/, @metz_offenses.first.message)
  end

  def test_counts_class_self_block_methods
    source = <<~RUBY
      class Checkout
        class << self
          def call
          end

          def preview
          end
        end
      end
    RUBY

    metz_inspect(source, SERVICE_PATH)

    assert_equal 1, @metz_offenses.size
  end
end
