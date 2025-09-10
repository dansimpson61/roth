# frozen_string_literal: true
module Engine
  module RMDTable
    # Very simplified distribution period table excerpt
    TABLE = {
      73 => 26.5,
      74 => 25.5,
      75 => 24.6,
      76 => 23.7,
      77 => 22.9,
      78 => 22.0,
      79 => 21.1,
      80 => 20.2,
      81 => 19.4,
      82 => 18.5,
      83 => 17.7,
      84 => 16.8,
      85 => 16.0,
      86 => 15.2,
      87 => 14.4,
      88 => 13.7,
      89 => 12.9,
      90 => 12.2
    }.freeze

    def self.factor(age)
      TABLE[age]
    end
  end
end
