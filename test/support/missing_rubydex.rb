# frozen_string_literal: true

require "tmpdir"

module MetzScan
  module MissingRubydexSupport
    def with_missing_rubydex_shim
      Dir.mktmpdir("metz-scan-missing-rubydex") do |dir|
        shim = File.join(dir, "missing_rubydex.rb")
        File.write(shim, missing_rubydex_shim_source)
        yield("RUBYOPT" => rubyopt_with_shim(shim))
      end
    end

    private

    def rubyopt_with_shim(shim)
      [ENV.fetch("RUBYOPT", nil), "-r#{shim}"].compact.join(" ")
    end

    def missing_rubydex_shim_source
      <<~RUBY
        module Kernel
          alias_method :metz_scan_original_require, :require

          def require(feature)
            raise LoadError, "cannot load such file -- rubydex" if feature == "rubydex"

            metz_scan_original_require(feature)
          end
        end
      RUBY
    end
  end
end
