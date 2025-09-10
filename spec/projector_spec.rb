# frozen_string_literal: true
require 'rspec'
require_relative '../lib/engine/inputs'
require_relative '../lib/engine/projector'
require_relative '../lib/engine/strategy/fixed_amount'

RSpec.describe Engine::Projector do
  it 'runs a simple 5 year projection' do
    inputs = Engine::Inputs.new(
      age_primary: 60,
      age_spouse: 58,
      trad_balance: 500_000,
      roth_balance: 100_000,
      base_income: 80_000,
      social_security_start_year: 5,
      social_security_amount: 40_000,
      growth_rate: 0.05,
      inflation_rate: 0.02,
      horizon_years: 5,
      current_year: 2025,
      conversion_strategy: 'fixed',
      conversion_value: 20_000
    )
    strategy = Engine::Strategy::FixedAmount.new(amount: 20_000)
  # Compute naive growth-only balance to ensure conversions reduced it below that
  growth_only = 500_000 * (1 + 0.05) ** 5
    result = described_class.new(inputs: inputs, strategy: strategy).run
    expect(result.primary.years.size).to eq 5
    expect(result.primary.totals[:conversions]).to be > 0
    expect(result.primary.totals[:ending_trad]).to be < growth_only
    expect(result.baseline).not_to be_nil
  end

  it 'starts social security after offset' do
    inputs = Engine::Inputs.new(
      age_primary: 60,
      age_spouse: 58,
      trad_balance: 100_000,
      roth_balance: 50_000,
      base_income: 0,
      social_security_start_year: 2,
      social_security_amount: 30_000,
      growth_rate: 0.0,
      inflation_rate: 0.0,
      horizon_years: 4,
      current_year: 2025,
      conversion_strategy: 'fixed',
      conversion_value: 0
    )
    strategy = Engine::Strategy::FixedAmount.new(amount: 0)
    result = described_class.new(inputs: inputs, strategy: strategy).run
  ss_series = result.primary.years.map(&:social_security)
    expect(ss_series[0]).to eq 0
    expect(ss_series[1]).to eq 0
    expect(ss_series[2]).to be > 0
  end

  it 'caps conversions at next bracket threshold using fill bracket strategy' do
    require_relative '../lib/engine/strategy/fill_bracket'
    inputs = Engine::Inputs.new(
      age_primary: 62,
      age_spouse: 60,
      trad_balance: 400_000,
      roth_balance: 0,
      base_income: 50_000,
      social_security_start_year: 99,
      social_security_amount: 40_000,
      growth_rate: 0.0,
      inflation_rate: 0.0,
      horizon_years: 1,
      current_year: 2025,
      conversion_strategy: 'fill_bracket',
      conversion_value: 22 # interpret as 22% target bracket
    )
  strategy = Engine::Strategy::FillBracket.new(target_bracket: 0.22)
    result = described_class.new(inputs: inputs, strategy: strategy).run
    yr = result.primary.years.first
    # Taxable income should not exceed start of 24% bracket
    brackets = result.primary.brackets
    twenty_four_start = brackets.find { |b| (b[1] - 0.24).abs < 1e-6 }&.first
    expect(twenty_four_start).not_to be_nil
    taxable = [0, yr.gross_income - result.primary.standard_deduction].max
    expect(taxable).to be < twenty_four_start
  end

  it 'applies higher standard deduction when either spouse 65+' do
    # Age 65 threshold triggers senior additional amount (assumes MFJ modeling)
    inputs1 = Engine::Inputs.new(
      age_primary: 64,
      age_spouse: 63,
      trad_balance: 0,
      roth_balance: 0,
      base_income: 10_000,
      social_security_start_year: 99,
      social_security_amount: 0,
      growth_rate: 0.0,
      inflation_rate: 0.0,
      horizon_years: 1,
      current_year: 2025,
      conversion_strategy: 'fixed',
      conversion_value: 0
    )
    inputs2 = Engine::Inputs.new(
      age_primary: 65,
      age_spouse: 63,
      trad_balance: 0,
      roth_balance: 0,
      base_income: 10_000,
      social_security_start_year: 99,
      social_security_amount: 0,
      growth_rate: 0.0,
      inflation_rate: 0.0,
      horizon_years: 1,
      current_year: 2025,
      conversion_strategy: 'fixed',
      conversion_value: 0
    )
    strategy = Engine::Strategy::FixedAmount.new(amount: 0)
    r1 = described_class.new(inputs: inputs1, strategy: strategy).run
    r2 = described_class.new(inputs: inputs2, strategy: strategy).run
  expect(r1.primary.standard_deduction).not_to be_nil
  expect(r2.primary.standard_deduction).not_to be_nil
  expect(r2.primary.standard_deduction).to be > r1.primary.standard_deduction
  end

  it 'baseline has lower Roth balance growth when conversions occur' do
    inputs = Engine::Inputs.new(
      age_primary: 60,
      age_spouse: 58,
      trad_balance: 300_000,
      roth_balance: 50_000,
      base_income: 70_000,
      social_security_start_year: 5,
      social_security_amount: 40_000,
      growth_rate: 0.04,
      inflation_rate: 0.02,
      horizon_years: 10,
      current_year: 2025,
      conversion_strategy: 'fixed',
      conversion_value: 25_000
    )
    strategy = Engine::Strategy::FixedAmount.new(amount: 25_000)
    result = described_class.new(inputs: inputs, strategy: strategy).run
    expect(result.primary.totals[:ending_roth]).to be > result.baseline.totals[:ending_roth]
  end
end
