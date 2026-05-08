# frozen_string_literal: true

require "lint_roller"
require "pathname"

require_relative "version"

module RuboCop
  module Metz
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: "rubocop-metz",
          version: RuboCop::Metz::VERSION,
          homepage: "https://rubygems.org/gems/rubocop-metz",
          description: "Sandi-Metz-inspired RuboCop cops."
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join("../../../config/default.yml").expand_path
        )
      end
    end
  end
end
