# frozen_string_literal: true

require_relative "project_index/null_backend"
require_relative "project_index/rubydex_backend"

module MetzScan
  # Thin facade over optional project-wide indexes used by future analyzers.
  class ProjectIndex
    Declaration = Struct.new(:name, :path, :kind, keyword_init: true)
    MethodDeclaration = Struct.new(:name, :owner_name, :method_name, :signature, :path, :line, :column,
                                   :receiver_kind, :method_identity, :visibility, keyword_init: true)
    Reference = Struct.new(:name, :path, :line, :column, keyword_init: true)

    class UnknownBackendError < StandardError; end
    class UnavailableBackendError < StandardError; end

    BACKENDS = %i[auto null rubydex].freeze
    private_constant :BACKENDS

    def self.build(paths, backend: :auto, workspace: false)
      backend = backend.to_sym
      raise UnknownBackendError, "unknown project index backend: #{backend}" unless BACKENDS.include?(backend)

      new(build_backend(Array(paths), backend, workspace))
    end

    def self.build_backend(paths, backend, workspace)
      case backend
      when :auto then auto_backend(paths, workspace)
      when :null then null_backend("project index disabled")
      when :rubydex then rubydex_backend(paths, workspace)
      end
    end
    private_class_method :build_backend

    def self.auto_backend(paths, workspace)
      return rubydex_backend(paths, workspace) if RubydexBackend.available?

      null_backend(RubydexBackend.unavailable_reason)
    end
    private_class_method :auto_backend

    def self.rubydex_backend(paths, workspace)
      raise UnavailableBackendError, RubydexBackend.unavailable_reason unless RubydexBackend.available?

      RubydexBackend.build(paths, workspace: workspace)
    end
    private_class_method :rubydex_backend

    def self.null_backend(reason)
      NullBackend.new(reason: reason)
    end
    private_class_method :null_backend

    def initialize(backend)
      @backend = backend
    end

    attr_reader :backend

    def backend_name
      backend.name
    end

    def available?
      backend.available?
    end

    def reason
      backend.reason
    end

    def indexed_files
      backend.indexed_files
    end

    def index_errors
      backend.index_errors
    end

    def diagnostics
      backend.diagnostics
    end

    def declarations
      backend.declarations
    end

    def method_declarations
      backend.method_declarations
    end

    def documents
      backend.documents
    end

    def descendants_of(name)
      backend.descendants_of(name)
    end

    def constant_references_to(name)
      backend.constant_references_to(name)
    end

    def search(query)
      backend.search(query)
    end
  end
end
