# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzControllersTooManyDirectCollaboratorsTest < Minitest::Test
  include Metz::Test::CopHelper

  CONTROLLER_PATH = "app/controllers/users_controller.rb"
  DATA_METHODS = %w[include? each map fetch [] keys values first size].freeze
  MORE_DATA_METHODS = %w[any? empty? length count last key? to_a dig sample each_with_index].freeze
  DATA_OPERATORS = %w[== != < <= > >= <=> + - * / % **].freeze

  def cop_class
    RuboCop::Cop::Metz::ControllersTooManyDirectCollaborators
  end

  def cop_config
    { "MaxCollaborators" => 1, "Severity" => "refactor" }
  end

  def test_cop_is_registered_in_global_registry
    klass = RuboCop::Cop::Registry.global.find_by_cop_name(
      "Metz/ControllersTooManyDirectCollaborators"
    )

    assert_equal RuboCop::Cop::Metz::ControllersTooManyDirectCollaborators, klass
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::ControllersTooManyDirectCollaborators.metz_metadata

    refute_empty meta[:why_it_matters], "why_it_matters must be non-empty"
    assert_includes %i[safe unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_default_yaml_carries_required_keys
    yaml = YAML.load_file(File.expand_path("../../../config/default.yml", __dir__))
    entry = yaml.fetch("Metz/ControllersTooManyDirectCollaborators")

    assert_equal true, entry["Enabled"]
    assert_equal 1, entry["MaxCollaborators"]
    assert_equal "refactor", entry["Severity"]
    assert_includes Array(entry["Include"]), "app/controllers/**/*.rb"
    assert(
      Array(entry["Include"]).all? { |g| g.start_with?("app/controllers/") },
      "Include must be scoped to app/controllers/"
    )
  end

  def test_fires_on_action_with_multiple_distinct_collaborators
    source = <<~RUBY
      class UsersController < ApplicationController
        def index
          @users = User.all
          @audit = AuditLog.recent
          @notifier = Notifier.deliver_later
        end
      end
    RUBY

    metz_inspect(source, CONTROLLER_PATH)

    assert_equal 1, controller_offenses.size,
                 "Expected one offense, got #{controller_offenses.map(&:message).inspect}"
  end

  def test_silent_when_distinct_collaborators_at_or_below_max
    source = <<~RUBY
      class HomeController < ApplicationController
        def index
          @posts = Post.published
        end
      end
    RUBY

    refute_offense(source, file: CONTROLLER_PATH)
  end

  def test_repeated_references_to_same_collaborator_count_as_one
    source = <<~RUBY
      class SessionsController < ApplicationController
        def create
          @session = Session.new
          Session.authenticate(params[:email], params[:password])
          Session.terminate(current_session_id)
        end
      end
    RUBY

    refute_offense(source, file: CONTROLLER_PATH)
  end

  def test_each_action_is_checked_independently
    source = <<~RUBY
      class UsersController < ApplicationController
        def index
          User.all
          AuditLog.recent
        end

        def show
          @user = User.find(params[:id])
        end
      end
    RUBY

    metz_inspect(source, CONTROLLER_PATH)

    assert_equal 1, controller_offenses.size,
                 "Expected one offense (only `index`), got: " \
                 "#{controller_offenses.map(&:message).inspect}"
  end

  def test_silent_on_files_outside_app_controllers
    source = <<~RUBY
      class S
        def call
          A.new
          B.new
          C.call
        end
      end
    RUBY

    refute_offense(source, file: "lib/script.rb")
  end

  def test_relevant_file_respects_cop_exclude
    config = RuboCop::Config.new(
      "Metz/ControllersTooManyDirectCollaborators" => {
        "Enabled" => true,
        "MaxCollaborators" => 1,
        "Exclude" => [CONTROLLER_PATH]
      }
    )

    refute cop_class.new(config).relevant_file?(CONTROLLER_PATH)
  end

  def test_offense_location_lands_inside_action_body_not_class_line
    source = <<~RUBY
      class UsersController < ApplicationController
        def index
          @users = User.all
          @audit = AuditLog.recent
          @notifier = Notifier.deliver_later
        end
      end
    RUBY

    metz_inspect(source, CONTROLLER_PATH)
    offense = controller_offenses.first
    refute_nil offense

    line = offense.location.line
    refute_match(/\Aclass\b/, source.lines[line - 1].strip,
                 "Offense should NOT land on the class declaration line")
    assert_operator line, :>, 1, "Offense should be inside an action body"
  end

  def test_silent_on_class_methods_even_when_they_touch_many_collaborators
    source = <<~RUBY
      class UsersController < ApplicationController
        def self.background_refresh
          User.refresh_all
          AuditLog.purge
          Notifier.broadcast
        end
      end
    RUBY

    refute_offense(source, file: CONTROLLER_PATH)
  end

  def test_resolves_namespaced_constants_as_single_collaborators
    source = <<~RUBY
      class WidgetsController < ApplicationController
        def show
          Foo::Bar.fetch
          Foo::Bar.cache
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/widgets_controller.rb")
  end

  def test_value_constants_count_toward_their_owning_collaborator
    source = <<~RUBY
      class UsersController < ApplicationController
        def show
          User.find(1)
          User::STATUSES
          User::ROLE_NAMES
        end
      end
    RUBY

    refute_offense(source, file: CONTROLLER_PATH)
  end

  def test_value_constant_alone_reports_its_owner
    source = <<~RUBY
      class UsersController < ApplicationController
        def show
          User::STATUSES
          AuditLog.recent
        end
      end
    RUBY

    metz_inspect(source, CONTROLLER_PATH)

    assert_equal 1, controller_offenses.size
    assert_match(/\(User, AuditLog\)/, controller_offenses.first.message)
  end

  def test_classes_in_a_shared_namespace_stay_distinct
    source = <<~RUBY
      class RefundsController < ApplicationController
        def create
          Billing::Invoice.find(1)
          Billing::Refund.create
        end
      end
    RUBY

    metz_inspect(source, "app/controllers/refunds_controller.rb")

    assert_equal 1, controller_offenses.size
    assert_match(/\(Billing::Invoice, Billing::Refund\)/, controller_offenses.first.message)
  end

  def test_ignores_rescue_exception_classes
    source = <<~RUBY
      class ChatsController < ApplicationController
        def set_chat
          @chat = Current.user.chats.find(params[:chat_id])
        rescue ActiveRecord::RecordNotFound
          redirect_to root_path
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/chats_controller.rb")
  end

  def test_rescue_body_collaborators_still_count
    source = <<~RUBY
      class ChatsController < ApplicationController
        def set_chat
          @chat = Current.user.chats.find(params[:chat_id])
        rescue ActiveRecord::RecordNotFound
          AuditLog.warn("missing chat")
        end
      end
    RUBY

    metz_inspect(source, "app/controllers/chats_controller.rb")

    assert_equal 1, controller_offenses.size
    assert_match(/\(Current, AuditLog\)/, controller_offenses.first.message)
    refute_match(/ActiveRecord::RecordNotFound/, controller_offenses.first.message)
  end

  def test_bare_rescue_body_collaborators_still_count
    source = <<~RUBY
      class ChatsController < ApplicationController
        def set_chat
          @chat = Current.user.chats.find(params[:chat_id])
        rescue
          AuditLog.warn("missing chat")
        end
      end
    RUBY

    metz_inspect(source, "app/controllers/chats_controller.rb")

    assert_equal 1, controller_offenses.size
    assert_match(/\(Current, AuditLog\)/, controller_offenses.first.message)
  end

  def test_ignores_constants_defined_on_the_controller
    source = <<~RUBY
      class CookiesController < ApplicationController
        TAG_FILTER_COOKIE = "tag_filter"
        VALID_COOKIE_KEY = /\\A[a-z_]+\\z/

        def remove_unknown_cookies
          cookies.each_key do |key|
            cookies.delete(key) unless key == TAG_FILTER_COOKIE ||
                                       key.match?(VALID_COOKIE_KEY)
          end
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/cookies_controller.rb")
  end

  def test_ignores_qualified_constants_defined_on_the_controller
    source = <<~RUBY
      class CookiesController < ApplicationController
        VALID_COOKIE_KEY = /\\A[a-z_]+\\z/

        def remove_unknown_cookies
          CookieJar.clean
          cookies.delete(:unknown) unless CookiesController::VALID_COOKIE_KEY.match?("key")
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/cookies_controller.rb")
  end

  def test_qualified_external_constant_assignments_do_not_define_controller_constants
    source = <<~RUBY
      class UsersController < ApplicationController
        ::FEATURE_FLAG = true

        def show
          FEATURE_FLAG
          User.find(params[:id])
        end
      end
    RUBY

    metz_inspect(source, CONTROLLER_PATH)

    assert_equal 1, controller_offenses.size
    assert_match(/\(FEATURE_FLAG, User\)/, controller_offenses.first.message)
  end

  def test_ignores_framework_and_stdlib_constants
    source = <<~RUBY
      class DownloadsController < ApplicationController
        def show
          Rails.logger.info(SecureRandom.uuid)
          Time.zone.today
          File.exist?(params[:path])
          Hash[params[:filters]]
          Report.find(params[:id])
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/downloads_controller.rb")
  end

  def test_ignores_raised_exception_classes_even_without_a_local_rescue
    source = <<~RUBY
      class LoginController < ApplicationController
        def login
          Current.user
          raise LoginBannedError, "banned" if banned?
          raise LoginFailedError, "failed" unless authenticated?
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/login_controller.rb")
  end

  def test_raised_exception_class_via_new_is_not_counted
    source = <<~RUBY
      class LoginController < ApplicationController
        def login
          Current.user
          raise LoginBannedError.new("banned") if banned?
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/login_controller.rb")
  end

  def test_ignores_arel_sql_helper_constant
    source = <<~RUBY
      class JobsController < ApplicationController
        def index
          @jobs = Delayed::Job.order(Arel.sql("priority DESC"))
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/jobs_controller.rb")
  end

  def test_private_helper_offense_is_not_labeled_action
    source = <<~RUBY
      class ChatsController < ApplicationController
        private

        def set_chat
          Current.user
          Chat.find(params[:chat_id])
        end
      end
    RUBY

    metz_inspect(source, "app/controllers/chats_controller.rb")

    assert_equal 1, controller_offenses.size
    assert_match(/Controller method `set_chat` reaches into 2 direct collaborators/,
                 controller_offenses.first.message)
    refute_match(/\AAction `set_chat`/, controller_offenses.first.message)
  end

  # A namespaced ALL_CAPS constant counts as its namespace (everything before the
  # last segment) only when it is bare or the receiver of one of DATA_METHODS,
  # `&.` included; any other use keeps the full name as its own collaborator.
  # Source: owner decision 2026-10-13 (cop-accuracy slice).
  def test_namespaced_all_caps_constant_receiving_a_data_method_counts_as_its_namespace
    DATA_METHODS.each do |data_method|
      call = data_method == "[]" ? "User::STATUSES[:admin]" : "User::STATUSES.#{data_method}"
      source = <<~RUBY
        class UsersController < ApplicationController
          def show
            User.find(1)
            #{call}
          end
        end
      RUBY

      offenses = metz_inspect(source, CONTROLLER_PATH)

      assert_empty offenses,
                   "`#{call}` should count as User; got #{offenses.map(&:message).inspect}"
    end
  end

  def test_safe_navigation_data_method_read_counts_as_the_namespace
    source = <<~RUBY
      class UsersController < ApplicationController
        def show
          User.find(1)
          User::STATUSES&.include?(params[:status])
          User::ROLE_NAMES&.first
        end
      end
    RUBY

    refute_offense(source, file: CONTROLLER_PATH)
  end

  def test_namespaced_all_caps_constant_passed_as_an_argument_counts_as_its_namespace
    source = <<~RUBY
      class UsersController < ApplicationController
        def show
          User.find(1)
          render json: User::STATUSES
          respond(User::ROLE_NAMES)
        end
      end
    RUBY

    refute_offense(source, file: CONTROLLER_PATH)
  end

  def test_namespaced_all_caps_constant_in_an_assignment_counts_as_its_namespace
    source = <<~RUBY
      class UsersController < ApplicationController
        def show
          User.find(1)
          @statuses = User::STATUSES
          roles = User::ROLE_NAMES
        end
      end
    RUBY

    refute_offense(source, file: CONTROLLER_PATH)
  end

  def test_deeply_namespaced_all_caps_constant_counts_as_its_full_namespace
    source = <<~RUBY
      class InvoicesController < ApplicationController
        def show
          Billing::Invoice.find(1)
          Billing::Invoice::STATUSES
          @names = Billing::Invoice::STATUS_NAMES.keys
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/invoices_controller.rb")
  end

  def test_all_caps_class_receiving_a_non_data_method_keeps_its_full_name
    source = <<~RUBY
      class FeedsController < ApplicationController
        def show
          Net::HTTP.get(uri)
          AuditLog.recent
        end
      end
    RUBY

    metz_inspect(source, "app/controllers/feeds_controller.rb")

    assert_equal 1, controller_offenses.size
    assert_match(/\(Net::HTTP, AuditLog\)/, controller_offenses.first.message)
  end

  def test_namespaced_all_caps_receiver_of_a_command_method_is_its_own_collaborator
    source = <<~RUBY
      class ChargesController < ApplicationController
        def create
          Billing::Invoice.find(1)
          Billing::API.charge(order)
        end
      end
    RUBY

    metz_inspect(source, "app/controllers/charges_controller.rb")

    assert_equal 1, controller_offenses.size
    assert_match(/\(Billing::Invoice, Billing::API\)/, controller_offenses.first.message)
  end

  def test_safe_navigation_non_data_call_keeps_the_full_name
    source = <<~RUBY
      class ChargesController < ApplicationController
        def create
          User.find(1)
          Billing::API&.charge(order)
        end
      end
    RUBY

    metz_inspect(source, "app/controllers/charges_controller.rb")

    assert_equal 1, controller_offenses.size
    assert_match(/\(User, Billing::API\)/, controller_offenses.first.message)
  end

  def test_namespaced_all_caps_constant_receiving_a_non_data_method_is_its_own_collaborator
    source = <<~RUBY
      class UsersController < ApplicationController
        def show
          User.find(1)
          User::STATUSES.freeze
        end
      end
    RUBY

    metz_inspect(source, CONTROLLER_PATH)

    assert_equal 1, controller_offenses.size
    assert_match(/\(User, User::STATUSES\)/, controller_offenses.first.message)
  end

  # Source: owner decision 2026-10-14 (question 26), extending the data-read list.
  def test_namespaced_all_caps_constant_receiving_a_newly_listed_data_method_counts_as_its_namespace
    failures = MORE_DATA_METHODS.filter_map do |data_method|
      call = "User::STATUSES.#{data_method}"
      offenses = metz_inspect(users_show_source(call), CONTROLLER_PATH)
      "`#{call}` (method `#{data_method}`): #{offenses.map(&:message).inspect}" if offenses.any?
    end

    assert_empty failures, "these should count as User, not a second collaborator:\n#{failures.join("\n")}"
  end

  # Source: owner decision 2026-10-14 (question 26): comparison and arithmetic
  # operators are data reads when the constant is the receiver.
  def test_namespaced_all_caps_constant_receiving_a_comparison_or_arithmetic_operator_counts_as_its_namespace
    failures = DATA_OPERATORS.filter_map do |operator|
      call = "User::MAX_AGE #{operator} 18"
      offenses = metz_inspect(users_show_source(call), CONTROLLER_PATH)
      "operator `#{operator}` (`#{call}`): #{offenses.map(&:message).inspect}" if offenses.any?
    end

    assert_empty failures, "these should count as User, not a second collaborator:\n#{failures.join("\n")}"
  end

  # join and find stay out of the data list on purpose: classes such as URI and
  # models define them. Source: owner decision 2026-10-14 (question 26).
  def test_namespaced_all_caps_constant_receiving_join_or_find_is_its_own_collaborator
    ["join(\", \")", "find { |s| s }"].each do |call_tail|
      call = "User::STATUSES.#{call_tail}"
      source = <<~RUBY
        class UsersController < ApplicationController
          def show
            User.find(1)
            #{call}
          end
        end
      RUBY

      metz_inspect(source, CONTROLLER_PATH)

      assert_equal 1, controller_offenses.size, "`#{call}` should add a collaborator"
      assert_match(/\(User, User::STATUSES\)/, controller_offenses.first.message,
                   "`#{call}` should keep User::STATUSES as its own collaborator")
    end
  end

  # Operators outside comparison and arithmetic are not reads. Source: owner
  # decision 2026-10-14 (question 26).
  def test_namespaced_all_caps_constant_receiving_an_append_is_its_own_collaborator
    source = <<~RUBY
      class UsersController < ApplicationController
        def show
          User.find(1)
          User::STATUSES << :x
        end
      end
    RUBY

    metz_inspect(source, CONTROLLER_PATH)

    assert_equal 1, controller_offenses.size
    assert_match(/\(User, User::STATUSES\)/, controller_offenses.first.message)
  end

  # A bare namespaced ALL_CAPS constant counts as its namespace even when it
  # names a class. Source: owner decision 2026-10-14 (question 27).
  def test_bare_namespaced_all_caps_class_passed_as_an_argument_counts_as_its_namespace
    source = <<~RUBY
      class FeedsController < ApplicationController
        def show
          Net.get_default
          use(Net::HTTP)
        end
      end
    RUBY

    refute_offense(source, file: "app/controllers/feeds_controller.rb")
  end

  private

  def users_show_source(statement)
    <<~RUBY
      class UsersController < ApplicationController
        def show
          User.find(1)
          #{statement}
        end
      end
    RUBY
  end

  def controller_offenses
    Array(@metz_offenses).select do |o|
      o.cop_name == "Metz/ControllersTooManyDirectCollaborators"
    end
  end
end
