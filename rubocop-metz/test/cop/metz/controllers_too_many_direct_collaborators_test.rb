# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzControllersTooManyDirectCollaboratorsTest < Minitest::Test
  include Metz::Test::CopHelper

  CONTROLLER_PATH = "app/controllers/users_controller.rb"

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

  private

  def controller_offenses
    Array(@metz_offenses).select do |o|
      o.cop_name == "Metz/ControllersTooManyDirectCollaborators"
    end
  end
end
