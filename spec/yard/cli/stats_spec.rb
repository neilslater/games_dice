# frozen_string_literal: true

require 'helpers'
require 'open3'
require 'rbconfig'
require 'yard'
require_relative '../../support/validation'

describe YARD::CLI::Stats, :aggregate_failures do
  include_context 'with temporary Ruby source'

  let(:documentation_check) { File.expand_path('../../../script/check_documentation.rb', __dir__) }

  def documentation_result(source)
    with_source(source) do |directory|
      Open3.capture2e(RbConfig.ruby, documentation_check, chdir: directory)
    end
  end

  it 'accepts documented source' do
    output, status = documentation_result("# A documented class.\nclass Probe\nend\n")
    expect(status).to be_success, output
    expect(output).to include('100.00% documented')
  end

  it 'rejects undocumented objects' do
    output, status = documentation_result("class Probe\nend\n")
    expect(status).not_to be_success
    expect(output).to include('Documentation check found undocumented objects', 'Probe')
  end

  it 'rejects YARD warnings even when the object is documented' do
    output, status = documentation_result("# A documented class.\n# @unknown_tag invalid\nclass Probe\nend\n")
    expect(status).not_to be_success
    expect(output).to include('Unknown tag @unknown_tag', '100.00% documented')
  end

  it 'rejects an empty documentation source boundary' do
    output, status = documentation_result('# No API objects here.')
    expect(status).not_to be_success
    expect(output).to include('Documentation check found no objects')
  end
end
