# frozen_string_literal: true
module Engine
  Inputs = Struct.new(
    :age_primary,
    :age_spouse,
    :trad_balance,
    :roth_balance,
    :base_income,
    :social_security_start_year,
    :social_security_amount,
    :growth_rate,
    :inflation_rate,
    :horizon_years,
    :current_year,
    :conversion_strategy,
    :conversion_value,
    keyword_init: true
  ) do
    def self.from_hash(h)
      new(
        age_primary: h['age_primary'],
        age_spouse: h['age_spouse'],
        trad_balance: h['trad_balance'],
        roth_balance: h['roth_balance'],
        base_income: h['base_income'],
        social_security_start_year: h['social_security_start_year'],
        social_security_amount: h['social_security_amount'],
        growth_rate: (h['growth_rate'] || 0.05),
        inflation_rate: (h['inflation_rate'] || 0.02),
        horizon_years: (h['horizon_years'] || 30),
        current_year: (h['current_year'] || Time.now.year),
        conversion_strategy: (h['conversion_strategy'] || 'fixed'),
        conversion_value: (h['conversion_value'] || 0)
      )
    end
  end
end
