# frozen_string_literal: true

require "rails/all"

module SampleApp
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
  end
end
