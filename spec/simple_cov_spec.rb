# frozen_string_literal: true

require 'helpers'
require 'open3'
require 'rbconfig'
require_relative 'support/validation'

describe SimpleCov, :aggregate_failures do
  include_context 'with temporary Ruby source'

  let(:coverage_setup) { File.expand_path('support/coverage.rb', __dir__) }

  def coverage_result(source, load_source: true)
    with_source(source) do |directory|
      code = load_source ? 'require "./lib/probe"' : ''
      Open3.capture2e(RbConfig.ruby, '-r', coverage_setup, '-e', code, chdir: directory)
    end
  end

  it 'accepts fully covered Ruby code' do
    output, status = coverage_result('[true, false].each { |flag| flag ? 1 : 2 }')
    expect(status).to be_success, output
  end

  it 'rejects a line coverage shortfall' do
    output, status = coverage_result("def uncalled\n  1\n  2\nend\n")
    expect(status.exitstatus).to eq(2)
    expect(output).to include('Line coverage', 'below the expected minimum coverage (95.00%)')
  end

  it 'rejects a branch shortfall even when every line runs' do
    output, status = coverage_result('[true].each { |flag| flag ? 1 : 2 }')
    expect(status.exitstatus).to eq(2)
    expect(output).to include('Line Coverage: 100.0%', 'Branch coverage', 'expected minimum coverage (95.00%)')
  end

  it 'counts maintained Ruby files that were never loaded' do
    output, status = coverage_result("class Unloaded\n  def value\n    1\n  end\nend\n", load_source: false)
    expect(status.exitstatus).to eq(2)
    expect(output).to include('Line Coverage: 0.0%')
  end
end
