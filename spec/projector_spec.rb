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
end
