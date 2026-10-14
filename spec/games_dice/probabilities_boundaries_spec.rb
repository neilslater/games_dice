# frozen_string_literal: true

require 'helpers'
require 'timeout'

describe GamesDice::Probabilities, :aggregate_failures do
  let(:int_min) { -(2**31) }
  let(:int_max) { (2**31) - 1 }

  def singleton(value)
    described_class.new([1.0], value)
  end

  def child_with_deadline(&)
    child = fork { run_child(&) }
    _, status = Timeout.timeout(5) { Process.wait2(child) }
    status.success?
  ensure
    reap_timed_out_child(child) if child && !status
  end

  def run_child
    yield
    exit! 0
  rescue StandardError
    exit! 1
  end

  def reap_timed_out_child(child)
    Process.kill('KILL', child)
    Process.wait(child)
  end

  def validate_large_repetitions
    values = [-1, 0, 1]
    [2**29, 2**30, int_max].each do |count|
      values.each { |value| raise unless singleton(value).repeat_sum(count).to_h == { value * count => 1.0 } }
    end
  end

  it 'terminates large repetition counts, including the native positive integer limit' do
    expect(child_with_deadline { validate_large_repetitions }).to be(true)
  end

  def expect_endpoint(distribution, endpoint)
    expect(distribution).to have_attributes(min: endpoint, max: endpoint)
    expect(distribution.p_eql(endpoint)).to eq(1.0)
    expect_aggregate_probabilities(distribution, { p_ge: { int_min => 1.0 }, p_lt: { int_min => 0.0 } })
    %i[given_ge given_le].each do |operation|
      expect(distribution.public_send(operation, endpoint).to_h).to eq({ endpoint => 1.0 })
    end
  end

  it 'queries both extreme endpoints without overflowing threshold arithmetic' do
    [int_min, int_max].each do |endpoint|
      expect_endpoint(singleton(endpoint), endpoint)
    end
    expect(singleton(int_min).p_eql(int_max)).to eq(0.0)
    expect(singleton(int_max).p_le(int_min)).to eq(0.0)
  end

  it 'permits cancelling weighted products outside the outcome range' do
    positive = singleton(int_max)
    negative = singleton(-int_max)
    expect(described_class.add_distributions_mult(int_max, positive, int_max, negative).to_h).to eq({ 0 => 1.0 })
    expect(described_class.add_distributions_mult(0, positive, 0, negative).to_h).to eq({ 0 => 1.0 })
  end

  it 'rejects unrepresentable endpoints before allocating or indexing' do
    expect { described_class.new([0.5, 0.5], int_max) }.to raise_error(RangeError, /outside native integer range/)
    expect { singleton(int_max).repeat_sum(2) }.to raise_error(RangeError)
    expect { described_class.add_distributions(singleton(int_min), singleton(-1)) }.to raise_error(RangeError)
    expect { described_class.add_distributions_mult(int_min, singleton(int_min), int_min, singleton(int_min)) }
      .to raise_error(RangeError)
  end

  it 'rejects a sparse hash spanning the whole integer range' do
    expect { described_class.from_h({ int_min => 0.5, int_max => 0.5 }) }.to raise_error(ArgumentError)
  end

  it 'rejects overflowing keeper endpoints' do
    expect { singleton(int_max).repeat_n_sum_k(3, 2) }.to raise_error(RangeError)
  end

  it 'supports the inclusive million-slot boundary with cheap sparse construction' do
    [999_999, 1_000_000].each do |slots|
      distribution = described_class.from_h({ 0 => 0.5, slots - 1 => 0.5 })
      expect(distribution.max).to eq(slots - 1)
      expect(described_class.add_distributions_mult(0, distribution, 1, singleton(0)).to_h).to eq({ 0 => 1.0 })
    end
  end

  it 'rejects more than a million probability slots' do
    expect { described_class.from_h({ 0 => 0.5, 1_000_000 => 0.5 }) }.to raise_error(ArgumentError)
  end

  it 'validates finite individual probabilities equally for array and hash constructors' do
    [Float::NAN, -Float::INFINITY, Float::INFINITY, -0.5, 1.5].each do |invalid|
      expect { described_class.new([invalid], 0) }.to raise_error(ArgumentError)
      expect { described_class.from_h({ 0 => invalid }) }.to raise_error(ArgumentError)
    end
    expect { described_class.from_h({ 0 => -0.5, 1 => 1.5 }) }.to raise_error(ArgumentError)
  end

  it 'preserves the existing total-mass tolerance without normalizing caller data' do
    [1.0 - 5e-9, 1.0].each do |mass|
      expect(described_class.new([mass], 0).to_h).to eq({ 0 => mass })
      expect(described_class.from_h({ 0 => mass }).to_h).to eq({ 0 => mass })
    end
  end

  it 'rejects total mass outside the existing tolerance' do
    expect { described_class.new([1.0 - 2e-8], 0) }.to raise_error(ArgumentError, /less than/)
    expect { described_class.from_h({ 0 => 0.5, 1 => 0.5 + 2e-8 }) }.to raise_error(ArgumentError, /greater than/)
  end

  it 'coerces each key and value only once' do
    key, value = coercion_pair
    expect(described_class.from_h({ key => value }).to_h).to eq({ 4 => 1.0 })
    expect(key).to have_received(:to_int).once
    expect(value).to have_received(:to_f).once
  end

  def coercion_pair
    key = instance_double(Float)
    value = instance_double(Float)
    allow(key).to receive(:to_int).and_return(4, int_max)
    allow(value).to receive(:to_f).and_return(1.0, Float::NAN)
    [key, value]
  end

  it 'uses the actual array length' do
    array = [1.0]
    allow(array).to receive(:count).and_return(int_max)
    expect(described_class.new(array, -1).to_h).to eq({ -1 => 1.0 })
  end

  it 'retains last-write semantics for keys coercing to the same integer' do
    expect(described_class.from_h({ 1 => 0.5, 1.1 => 1.0 }).to_h).to eq({ 1 => 1.0 })
  end

  it 'replaces native storage atomically across initialization and copying failures' do
    distribution = singleton(3)
    expect { distribution.__send__(:initialize, [Float::NAN], 0) }.to raise_error(ArgumentError)
    expect { distribution.__send__(:initialize_copy, Object.new) }.to raise_error(TypeError)
    expect(distribution.to_h).to eq({ 3 => 1.0 })
  end

  it 'replaces and frees previously initialized native storage' do
    distribution = singleton(3)
    distribution.__send__(:initialize, [0.25, 0.75], -1)
    expect(distribution.to_h).to eq({ -1 => 0.25, 0 => 0.75 })
  end

  it 'replaces and frees storage on an explicit copy' do
    distribution = singleton(3)
    distribution.__send__(:initialize_copy, singleton(7))
    GC.start
    expect(distribution.to_h).to eq({ 7 => 1.0 })
  end
end
