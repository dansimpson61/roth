# frozen_string_literal: true
# Rack configuration for the Roth Conversion Directional Estimator
# Intentional minimalism: directional planning tool, NOT tax prep software.

require 'bundler/setup'
require_relative './app'

# You can set :environment via RACK_ENV; default to development
run Sinatra::Application
