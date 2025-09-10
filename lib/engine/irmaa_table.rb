# frozen_string_literal: true
module Engine
  module IRMAATable
    BASE_YEAR = 2025
    # Simplified MAGI thresholds (MFJ) and annual surcharge amounts (combined Part B+D approx)
    THRESHOLDS = [
      [0, :none, 0],
      [206000, :tier1, 1200],
      [258000, :tier2, 3000],
      [322000, :tier3, 4800],
      [386000, :tier4, 6600],
      [750000, :tier5, 8400]
    ].freeze

    def self.thresholds(year, inflation_rate)
      years = year - BASE_YEAR
      factor = (1 + inflation_rate) ** years
      THRESHOLDS.map { |mag, tier, cost| [(mag * factor / 1000).round * 1000, tier, cost] }
    end

    def self.tier_for(magi, year, inflation_rate)
      thresholds = thresholds(year, inflation_rate)
      current = thresholds.first
      thresholds.each do |row|
        break if magi < row[0]
        current = row
      end
      { tier: current[1], projected_surcharge: current[2] }
    end
  end
end
