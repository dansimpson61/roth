# frozen_string_literal: true
module Engine
  module Strategy
    class FixedAmount
      def initialize(amount:)
        @amount = amount.to_f
      end
      def conversion_amount(_ctx)
        [@amount, 0].max
      end
      def description
        "Fixed #{@amount.round}"
      end
    end
  end
end
