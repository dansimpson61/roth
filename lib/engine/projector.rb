# frozen_string_literal: true
require 'json'
require_relative 'tax_tables'
require_relative 'rmd_table'
require_relative 'irmaa_table'

module Engine
  YearResult = Struct.new(
    :year,:age_primary,:age_spouse,:trad_start,:roth_start,
    :conversion,:rmd,:base_income,:social_security,:gross_income,
    :taxable_income,:federal_tax,:magi,:irmaa_tier,:irmaa_applied_cost,
    :trad_end,:roth_end, keyword_init: true
  ) do
    def to_h
      to_h_base = super
      to_h_base.transform_values { |v| v.is_a?(Float) ? v.round(2) : v }
    end
  end

  class Projector
    def initialize(inputs:, strategy:)
      @inputs = inputs
      @strategy = strategy
    end

  def run
      years = []
      magi_history = [] # to apply IRMAA 2-year lag
      trad = @inputs.trad_balance.to_f
      roth = @inputs.roth_balance.to_f
      year = @inputs.current_year
      age_p = @inputs.age_primary
      age_s = @inputs.age_spouse

      @inputs.horizon_years.times do
        brackets = TaxTables.federal_brackets(year, @inputs.inflation_rate)
        seniors = [age_p >= 65 ? 1 : 0, (age_s && age_s >= 65) ? 1 : 0].sum
        std_ded = TaxTables.standard_deduction(year, @inputs.inflation_rate, seniors)

        # Growth at start
        trad *= (1 + @inputs.growth_rate)
        roth *= (1 + @inputs.growth_rate)

  year_index = year - @inputs.current_year
  start_offset = (@inputs.social_security_start_year || 10).to_i
  ss_income = year_index >= start_offset ? @inputs.social_security_amount.to_f : 0.0
        base_income = @inputs.base_income.to_f

        rmd = rmd_for(age_p, trad)
        pre_conversion_taxable = base_income + ss_income + rmd

        conv_ctx = { year: year, inflation_rate: @inputs.inflation_rate, pre_conversion_taxable: pre_conversion_taxable }
        conversion = [@strategy.conversion_amount(conv_ctx), trad].min

        gross_income = base_income + ss_income + rmd + conversion
        taxable_income = [gross_income - std_ded, 0].max
        federal_tax = compute_tax(taxable_income, brackets)
        magi = gross_income # simplified

        irmaa_info = IRMAATable.tier_for(magi, year, @inputs.inflation_rate)
        magi_history << magi
        applied_cost = if magi_history.size > 2
                         past_magi = magi_history[-3]
                         past_tier = IRMAATable.tier_for(past_magi, year - 2, @inputs.inflation_rate)
                         past_tier[:projected_surcharge]
                       else
                         0
                       end

        # Update balances
        trad = trad - conversion - rmd
        roth += conversion

        years << YearResult.new(
          year: year,
          age_primary: age_p,
          age_spouse: age_s,
          trad_start: trad + conversion + rmd,
            roth_start: roth - conversion,
          conversion: round_h(conversion),
          rmd: round_h(rmd),
          base_income: round_h(base_income),
          social_security: round_h(ss_income),
          gross_income: round_h(gross_income),
          taxable_income: round_h(taxable_income),
          federal_tax: round_h(federal_tax),
          magi: round_h(magi),
          irmaa_tier: irmaa_info[:tier],
          irmaa_applied_cost: applied_cost,
          trad_end: round_h(trad),
          roth_end: round_h(roth)
        )

        year += 1
        age_p += 1
        age_s += 1 if age_s
      end

      primary = OpenStruct.new(
        scenario: @strategy.description,
        years: years,
        totals: aggregate(years),
        brackets: TaxTables.federal_brackets(@inputs.current_year, @inputs.inflation_rate) # base-year brackets for labeling
      )

      baseline_strategy = Strategy::FixedAmount.new(amount: 0)
      baseline = self.class.new(inputs: @inputs, strategy: baseline_strategy).run_single unless @strategy.is_a?(Strategy::FixedAmount) && @strategy.instance_variable_get(:@amount).zero?

  OpenStruct.new(primary: primary, baseline: baseline)
    end

    # Single scenario helper (used for baseline to avoid infinite recursion)
    def run_single
      # duplicate of run up to aggregation but without baseline recursion
      years = []
      magi_history = []
      trad = @inputs.trad_balance.to_f
      roth = @inputs.roth_balance.to_f
      year = @inputs.current_year
      age_p = @inputs.age_primary
      age_s = @inputs.age_spouse

      @inputs.horizon_years.times do
        brackets = TaxTables.federal_brackets(year, @inputs.inflation_rate)
        seniors = [age_p >= 65 ? 1 : 0, (age_s && age_s >= 65) ? 1 : 0].sum
        std_ded = TaxTables.standard_deduction(year, @inputs.inflation_rate, seniors)
        trad *= (1 + @inputs.growth_rate)
        roth *= (1 + @inputs.growth_rate)
        year_index = year - @inputs.current_year
        start_offset = (@inputs.social_security_start_year || 10).to_i
        ss_income = year_index >= start_offset ? @inputs.social_security_amount.to_f : 0.0
        base_income = @inputs.base_income.to_f
        rmd = rmd_for(age_p, trad)
        pre_conversion_taxable = base_income + ss_income + rmd
        conv_ctx = { year: year, inflation_rate: @inputs.inflation_rate, pre_conversion_taxable: pre_conversion_taxable }
        conversion = [@strategy.conversion_amount(conv_ctx), trad].min
        gross_income = base_income + ss_income + rmd + conversion
        taxable_income = [gross_income - std_ded, 0].max
        federal_tax = compute_tax(taxable_income, brackets)
        magi = gross_income
        irmaa_info = IRMAATable.tier_for(magi, year, @inputs.inflation_rate)
        magi_history << magi
        applied_cost = if magi_history.size > 2
                         past_magi = magi_history[-3]
                         past_tier = IRMAATable.tier_for(past_magi, year - 2, @inputs.inflation_rate)
                         past_tier[:projected_surcharge]
                       else
                         0
                       end
        trad = trad - conversion - rmd
        roth += conversion
        years << YearResult.new(
          year: year, age_primary: age_p, age_spouse: age_s,
          trad_start: trad + conversion + rmd, roth_start: roth - conversion,
          conversion: round_h(conversion), rmd: round_h(rmd), base_income: round_h(base_income),
          social_security: round_h(ss_income), gross_income: round_h(gross_income),
          taxable_income: round_h(taxable_income), federal_tax: round_h(federal_tax),
          magi: round_h(magi), irmaa_tier: irmaa_info[:tier], irmaa_applied_cost: applied_cost,
          trad_end: round_h(trad), roth_end: round_h(roth)
        )
        year += 1; age_p += 1; age_s += 1 if age_s
      end
  OpenStruct.new(scenario: @strategy.description, years: years, totals: aggregate(years), brackets: TaxTables.federal_brackets(@inputs.current_year, @inputs.inflation_rate))
    end

    private

    def rmd_for(age, trad_balance)
      factor = RMDTable.factor(age)
      return 0 unless factor
      trad_balance / factor
    end

    def compute_tax(taxable, brackets)
      tax = 0.0
      brackets.each_with_index do |(threshold, rate), idx|
        next_bracket_threshold = brackets[idx + 1]&.first || 9e15
        break if taxable <= threshold
        amount_in_bracket = [taxable, next_bracket_threshold].min - threshold
        tax += amount_in_bracket * rate if amount_in_bracket > 0
      end
      tax
    end

    def round_h(v)
      (v / 100.0).round * 100
    end

    def aggregate(years)
      {
        taxes_paid: years.sum(&:federal_tax),
        conversions: years.sum(&:conversion),
        rmds: years.sum(&:rmd),
        ending_trad: years.last.trad_end,
        ending_roth: years.last.roth_end
      }
    end
  end
end
