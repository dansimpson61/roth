# frozen_string_literal: true
require_relative '../tax_tables'
module Engine
  module Strategy
    class FillBracket
      def initialize(target_bracket:)
        # Allow entry as 0.22 or 22
        tb = target_bracket.to_f
        @target_rate = tb > 1 ? (tb / 100.0) : tb
      end
      def conversion_amount(ctx)
        brackets = TaxTables.federal_brackets(ctx[:year], ctx[:inflation_rate])
        idx = brackets.index { |(_, rate)| (rate - @target_rate).abs < 1e-6 }
        return 0 unless idx
        # Cap is start of NEXT bracket (or large sentinel if top)
        next_threshold = brackets[idx + 1]&.first || (ctx[:pre_conversion_taxable] + 0)
        cap = next_threshold - 1 # stay within bracket
        room = cap - ctx[:pre_conversion_taxable]
        room.positive? ? room : 0
      end
      def description
        pct = (@target_rate * 100).round
        "Fill bracket #{pct}%"
      end
    end
  end
end
