# frozen_string_literal: true
require 'sinatra'
require 'slim'
require_relative 'lib/engine/projector'
require_relative 'lib/engine/inputs'
require_relative 'lib/engine/strategy/fixed_amount'
require_relative 'lib/engine/strategy/fill_bracket'
require_relative 'lib/engine/tax_tables'

set :public_folder, File.join(__dir__, 'public')
set :views, File.join(__dir__, 'views')

get '/' do
  slim :controls
end

post '/run' do
  content_type :json
  params_payload = JSON.parse(request.body.read)
  inputs = Engine::Inputs.from_hash(params_payload)
  projector = Engine::Projector.new(inputs: inputs, strategy: strategy_from(inputs))
  result = projector.run
  # base-year standard deduction for labeling (federal, age-adjusted)
  seniors = [inputs.age_primary >= 65 ? 1 : 0, (inputs.age_spouse && inputs.age_spouse >= 65) ? 1 : 0].sum
  std_ded = Engine::TaxTables.standard_deduction(inputs.current_year, inputs.inflation_rate, seniors)
  # Build clean hash output
  output = {
    primary: {
      scenario: result.primary.scenario,
      totals: result.primary.totals,
      years: result.primary.years.map(&:to_h),
      brackets: result.primary.brackets,
      standard_deduction: std_ded
    }
  }
  if result.baseline
    output[:baseline] = {
      scenario: result.baseline.scenario,
      totals: result.baseline.totals,
      years: result.baseline.years.map(&:to_h),
      brackets: result.baseline.brackets,
      standard_deduction: std_ded
    }
  end
  JSON.pretty_generate(output)
end

helpers do
  def strategy_from(inputs)
    case inputs.conversion_strategy
    when 'fixed'
      Engine::Strategy::FixedAmount.new(amount: inputs.conversion_value)
    when 'fill_bracket'
      Engine::Strategy::FillBracket.new(target_bracket: inputs.conversion_value)
    else
      Engine::Strategy::FixedAmount.new(amount: 0)
    end
  end
end
