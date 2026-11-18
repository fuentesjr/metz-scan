# frozen_string_literal: true

require "parser"
require "prism"

module MetzScan
  # Stand-in for Dependabot::Bundler::FileUpdater::GemspecSanitizer::Rewriter
  # #replace_constant, plus the sanitizer's follow-up gsub. A call whose
  # receiver is a local variable and whose last argument interpolates a
  # VERSION constant is treated as a version assignment, and that argument is
  # replaced with a bare version string. Gem::Requirement.parse defaults a
  # missing operator to "=".
  module DependabotVersionAssignmentRewrite
    VERSION_INTERPOLATION = /#\{[A-Z][^.}]*::[A-Z][^.}]*\}/
    REPLACEABLE_TYPES = %i[float const send lvar if dstr].freeze

    module_function

    def rewrite(source, version)
      buffer = Parser::Source::Buffer.new("(gemspec)")
      buffer.source = source
      ast = Prism::Translation::ParserCurrent.new.parse(buffer)
      updated = Rewriter.new(version).rewrite(buffer, ast)
      substitute_version_constants(updated, version)
    end

    def substitute_version_constants(source, version)
      source.gsub(VERSION_INTERPOLATION, version_interpolation(version))
    end

    def version_interpolation(version)
      ["#", "{", '"', version, '"', "}"].join
    end

    class Rewriter < Parser::TreeRewriter
      def initialize(version)
        @version = version
        super()
      end

      def on_send(node)
        walk(node)
      end

      private

      attr_reader :version

      def walk(node)
        return unless node.is_a?(Parser::AST::Node)
        return replace_argument(node) if version_assignment?(node)

        node.children.each { |child| walk(child) }
      end

      def version_assignment?(node)
        return false unless lvar_receiver?(node)

        version_writer?(node) || version_expression?(node.children.last)
      end

      def lvar_receiver?(node)
        receiver = node.children[0]
        receiver.is_a?(Parser::AST::Node) && receiver.type == :lvar
      end

      def version_writer?(node)
        node.children[1] == :version=
      end

      def version_expression?(node)
        version_const?(node) || calls_version?(node) || interpolates_version?(node)
      end

      def version_const?(node)
        return false unless node.is_a?(Parser::AST::Node) && node.type == :const

        const_name(node).match?(/version/i)
      end

      def const_name(node)
        node.children.last.to_s
      end

      def calls_version?(node)
        return false unless node.is_a?(Parser::AST::Node) && node.type == :send

        node.children.any? { |child| version_const?(child) }
      end

      def interpolates_version?(node)
        return false unless node.is_a?(Parser::AST::Node) && node.type == :dstr

        interpolations(node).any? { |child| version_const?(child) }
      end

      def interpolations(node)
        begins = node.children.grep(Parser::AST::Node)
        begins.select { |child| child.type == :begin }.flat_map(&:children)
      end

      def replace_argument(node)
        argument = node.children.last
        return unless replaceable_argument?(argument)

        replace(argument.loc.expression, %("#{version}"))
      end

      def replaceable_argument?(node)
        node.is_a?(Parser::AST::Node) && REPLACEABLE_TYPES.include?(node.type)
      end
    end
  end
end
