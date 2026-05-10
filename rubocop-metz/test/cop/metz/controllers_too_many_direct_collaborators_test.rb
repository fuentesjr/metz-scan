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

  private

  def controller_offenses
    Array(@metz_offenses).select do |o|
      o.cop_name == "Metz/ControllersTooManyDirectCollaborators"
    end
  end
end
