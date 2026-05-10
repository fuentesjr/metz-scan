# frozen_string_literal: true

require "rubocop"
require "rubocop-ast"

require_relative "rubocop/metz/version"
require_relative "rubocop/metz/plugin"
require_relative "metz/cop_metadata"
require_relative "metz/file_classifier"
require_relative "metz/erb_ruby_extractor"
require_relative "rubocop/cop/metz/base"
require_relative "rubocop/cop/metz_cops"

Metz::ErbRubyExtractor.install!
