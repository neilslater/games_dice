# frozen_string_literal: true

require 'helpers'

describe GamesDice::ProbabilityBudget, :aggregate_failures do
  it 'rejects an aggregate certificate exceeding its requested budget' do
    expect { described_class.check(1e-9, 1e-10) }
      .to raise_error(GamesDice::ProbabilityLimitError, /truncation error bound/)
  end

  it 'rounds component union bounds outwards' do
    error = 1.0 / 3
    expect(described_class.scale(error, 10).to_r).to be >= 10 * error.to_r
    expect(described_class.add(error, error).to_r).to be >= 2 * error.to_r
    expect(described_class.share(error, 10).to_r).to be <= error.to_r / 10
  end
end
