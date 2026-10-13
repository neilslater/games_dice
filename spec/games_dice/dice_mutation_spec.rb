# frozen_string_literal: true

require 'helpers'

describe GamesDice::Dice, :aggregate_failures do
  let(:dice) { GamesDice.create('2d6x.m:>=8,1,Success.+1d4') }

  def failing_mutation_trigger
    lambda do |_|
      dice.bunch_multipliers.clear
      raise RangeError, 'callback failed'
    end
  end

  def mutation_trigger
    lambda do |_|
      yield
      true
    end
  end

  def populate(recipe)
    recipe.roll
    recipe.minmax
    recipe.probabilities
  end

  it 'caches the full combined distribution until a multiplier changes' do
    previous = dice.probabilities
    expect(dice.probabilities).to equal(previous)
    dice.bunch_multipliers[0] = 0
    expect(dice.probabilities.to_h).to eq(GamesDice.create('1d4').probabilities.to_h)
  end

  it 'clears parent history but retains unchanged child history after a multiplier edit' do
    populate(dice)
    child = dice.bunches.first.result
    dice.bunch_multipliers[0] = -1
    expect(dice.result).to be_nil
    expect(dice.bunches.first.result).to eq(child)
  end

  it 'clears affected child and parent histories after a rule replacement' do
    populate(dice)
    dice.bunches.first.rerolls[0] = GamesDice::RerollRule.new(6, :==, :reroll_replace, 1)
    expect(dice.explain_result).to be_nil
    expect(dice.bunches.first).to have_attributes(result: nil, result_details: nil, explain_result: nil)
    expect(dice.bunches.first.single_die).to have_attributes(result: nil, explain_result: nil,
                                                             probabilities_complete: nil)
  end

  it 'detects mutable map labels and permits rolling again after invalidation' do
    populate(dice)
    dice.bunches.first.maps.first.mapped_name.replace('Hit')
    expect(dice.result).to be_nil
    dice.roll
    expect(dice.explain_result).to be_a(String)
  end

  it 'detects paired insertion and deletion without replacing the exposed arrays' do
    original = dice.bunches
    dice.bunches << GamesDice::Bunch.new(ndice: 1, sides: 1)
    dice.bunch_multipliers << 2
    expect(dice.bunches).to equal(original)
    expect(dice.minmax).to eq([3, 8])
  end

  it 'rejects mismatched array lengths deliberately and permits later repair' do
    dice.bunch_multipliers.pop
    expect { dice.result }.to raise_error(ArgumentError, 'bunches and bunch_multipliers must have the same length')
    dice.bunches.pop
    expect(dice.minmax).to eq([0, 2])
  end

  it 'rejects invalid entry types and recovers when they are replaced' do
    dice.bunches[0] = 'invalid'
    expect { dice.probabilities }.to raise_error(TypeError, /Expected GamesDice::Bunch/)
    dice.bunches[0] = GamesDice::Bunch.new(ndice: 1, sides: 1)
    expect(dice.minmax).to eq([2, 5])
  end

  it 'invalidates every parent of a shared bunch' do
    other = GamesDice.create('1d4')
    other.bunches[0] = dice.bunches.first
    [dice, other].each { |recipe| populate(recipe) }
    dice.bunches.first.maps.clear
    expect([dice.result, other.result]).to eq([nil, nil])
  end

  it 'tracks reorder and clear operations' do
    dice.probabilities
    dice.bunches.reverse!
    dice.bunch_multipliers.replace([0, 1])
    expect(dice.minmax).to eq([0, 2])
  end

  it 'tracks removal of every bunch' do
    dice.bunches.clear
    dice.bunch_multipliers.clear
    expect(dice.probabilities.to_h).to eq({ 0 => 1.0 })
  end

  it 'invalidates bounds and histories after mutable bunch names change' do
    name = +'Original'
    dice.bunches[0] = GamesDice::Bunch.new(ndice: 1, sides: 6, name: name)
    populate(dice)
    name.replace('Changed')
    expect(dice.result).to be_nil
  end

  it 'keeps clone cache metadata independent while retaining shared recipe arrays' do
    copy = dice.clone
    populate(dice)
    populate(copy)
    dice.bunch_multipliers[0] = -1
    expect([dice.result, copy.result]).to eq([nil, nil])
  end

  it 'detects mutation from a custom predicate before publishing a result' do
    trigger = mutation_trigger { dice.bunch_multipliers[0] = -1 }
    dice.bunches.first.maps.replace([GamesDice::MapRule.new(trigger, :call, 1)])
    expect { dice.probabilities }.to raise_error(RuntimeError, 'Dice recipe changed during calculation')
    expect(dice.result).to be_nil
  end

  it 'detects rule-array edits from callbacks during a roll' do
    die = dice.bunches.first.single_die
    trigger = mutation_trigger { die.maps.clear }
    die.maps.replace([GamesDice::MapRule.new(trigger, :call, 1)])
    expect { dice.roll }.to raise_error(RuntimeError, 'Dice recipe changed during calculation')
    expect(dice.result).to be_nil
  end

  it 'keeps returned roll records unchanged when a shared label changes' do
    label = +'Original'
    die = GamesDice::ComplexDie.new(1, maps: [[1, :==, 1, label]])
    record = die.roll
    label.replace('Changed')
    expect(record.explain_value).to eq('1 Original')
  end

  it 'discards calculations when callbacks leave an invalid recipe' do
    trigger = mutation_trigger { dice.bunch_multipliers.clear }
    dice.bunches.first.maps.replace([GamesDice::MapRule.new(trigger, :call, 1)])
    expect { dice.probabilities }.to raise_error(RuntimeError, 'Dice recipe changed during calculation')
  end

  it 'preserves callback exceptions even when the callback also changes the recipe' do
    trigger = failing_mutation_trigger
    dice.bunches.first.maps.replace([GamesDice::MapRule.new(trigger, :call, 1)])
    expect { dice.probabilities }.to raise_error(RangeError, 'callback failed')
  end

  it 'recomputes unrecognized restored recipe metadata' do
    populate(dice)
    dice.instance_variable_set(:@recipe_cache, nil)
    expect(marshal_round_trip(dice).result).to be_nil
  end

  it 'invalidates a restored parent when a child snapshot is missing' do
    populate(dice)
    dice.bunches.first.single_die.instance_variable_set(:@recipe_cache, nil)
    expect(marshal_round_trip(dice).result).to be_nil
  end
end
