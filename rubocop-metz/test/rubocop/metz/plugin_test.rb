# frozen_string_literal: true

require_relative "../../test_helper"
require "rubocop/metz/plugin"

module RuboCop
  module Metz
    class PluginTest < Minitest::Test
      def test_about_points_to_published_package
        assert_equal "https://github.com/users/fuentesjr/packages/rubygems/package/rubocop-metz",
                     Plugin.new.about.homepage
      end
    end
  end
end
