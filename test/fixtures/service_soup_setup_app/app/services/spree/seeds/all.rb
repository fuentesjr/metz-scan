# frozen_string_literal: true

module Spree
  module Seeds
    class All
      def call
        Countries.call
        States.call
        Zones.call
        PaymentMethods.call
      end
    end
  end
end
