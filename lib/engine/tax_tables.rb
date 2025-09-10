# frozen_string_literal: true
module Engine
  module TaxTables
    # Simplified MFJ 2025-ish brackets (illustrative), inflated later
    BASE_YEAR = 2025
    FEDERAL_BRACKETS_MFJ = [
      [0, 0.10],
      [22000, 0.12],
      [94000, 0.22],
      [201000, 0.24],
      [383000, 0.32],
      [487000, 0.35],
      [731000, 0.37]
    ].freeze

  STANDARD_DEDUCTION_MFJ_BASE = 29500 # base (approx)
  ADDITIONAL_65_MFJ_PER_PERSON = 1550 # per qualifying spouse (approx)
  NY_STANDARD_DEDUCTION_MFJ = 16050

    def self.federal_brackets(year, inflation_rate)
      years = year - BASE_YEAR
      factor = (1 + inflation_rate) ** years
      FEDERAL_BRACKETS_MFJ.map { |threshold, rate| [(threshold * factor / 50).round * 50, rate] }
    end

    def self.standard_deduction(year, inflation_rate, seniors_count = 0)
      years = year - BASE_YEAR
      factor = (1 + inflation_rate) ** years
      base = STANDARD_DEDUCTION_MFJ_BASE * factor
      addl = ADDITIONAL_65_MFJ_PER_PERSON * seniors_count * factor
      ((base + addl) / 50).round * 50
    end

    def self.ny_standard_deduction(year, inflation_rate)
      years = year - BASE_YEAR
      factor = (1 + inflation_rate) ** years
      ((NY_STANDARD_DEDUCTION_MFJ * factor) / 50).round * 50
    end
  end
end
