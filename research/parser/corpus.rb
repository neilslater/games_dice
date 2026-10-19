# frozen_string_literal: true

module GamesDiceParserResearch
  # Shared, versioned corpus. Ordinary rolls define the latency acceptance set.
  module Corpus
    ORDINARY = %w[1d6 2d20k1+5 3d12+5+2d8+1d6 4d6r1xk3m4 10d10m8
                  1d6r:1,replace,1.m:>=5,2,hit.k:1,best.].freeze
    VALID = [*ORDINARY, '5', '-0+12-7', '0d0', '0002d006', '4d6k0', '4d6k:2,unknown_type.',
             '1d6r:1,unknown_type,0.', '1d6m:1,-2,Hi_123.', '1d6m:1,+2.', '1d6r:1.',
             '1d6m:1.', '4d6k:2.', '1d6xx.r0.m0.', '1d6m1m2r1r2', "\0 1d6\0",
             "\t-\v2d6\r\n+\f3\t", "1d6\n+\t2", "#{'9' * 100}d#{'8' * 100}",
             "1d6m:1,#{'9' * 100}.", '1d6x.r1.k1.m2.'].freeze
    INVALID = ['', nil, '+', '-', 'd6', '1D6', '1 d6', '1d 6', '1d6 k1', '1d6junk',
               '1d6+', '1d6++2', '1d6 2', '1d6r', '1d6r-1', '1d6r:1', '1d6m:1,2,hi',
               '1d6r:1,add,-1.', '1d6m:1,2,a-b.', '1d6r:!=1.', '1d6k:1,Best.',
               '1d6x..', '4d6k1k2', "1d6\0+2", '１d6', "1d6\u00a0+2"].freeze
    CONSTRUCTOR_FAILURES = %w[0d6 1d0 1d6r:1,unknown. 4d6k0 4d6k:1,unknown.].freeze
    MODIFIERS = %w[x x. r1 r1. m4 m4. k1 k:1,worst. r:<=2,replace,1. m:>=5,-2,Hit_1.].freeze

    module_function

    def comparisons
      %w[== >= <= > <].flat_map do |operator|
        ["2d6r:#{operator}2,add,3.", "2d6m:#{operator}3,-1,label."]
      end
    end

    def permutations
      %w[r1 m4 k2 x].permutation.map { |modifiers| "4d6#{modifiers.join}" }
    end

    def generated(seed: 20_261_019, count: 300)
      random = Random.new(seed)
      Array.new(count) do
        terms = Array.new(random.rand(1..4)) { generated_term(random) }
        terms.join + random.rand(-20..20).to_s.sub(/\A(?=\d)/, '+')
      end
    end

    def generated_term(random)
      modifiers = MODIFIERS.reject { |value| value.start_with?('k') }.sample(random.rand(0..4), random: random)
      "#{%w[+ -].sample(random: random)}#{random.rand(1..9)}d#{random.rand(2..20)}#{modifiers.join}"
    end

    def mutations(inputs, seed: 20_261_020)
      random = Random.new(seed)
      alphabet = '01269drkmx:+-.,<>=_ aZ!'
      inputs.flat_map do |input|
        position = random.rand(0..input.length)
        inserted = input.dup.insert(position, alphabet[random.rand(alphabet.length)])
        [inserted, input[0...position], "#{input}?", input.sub(/[0-9]/, '')]
      end
    end

    def differential
      valid = VALID + comparisons + permutations + generated
      valid + INVALID + mutations(valid) + encoding_cases
    end

    def encoding_cases
      ['1d6'.b, '1d6'.encode(Encoding::ISO_8859_1), '1d6'.encode(Encoding::UTF_16LE),
       "1d6\xff", "\xff1d6", "1d6m:1,2,\xff."]
    end
  end
end
