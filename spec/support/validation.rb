# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

shared_context 'with temporary Ruby source' do
  def with_source(source)
    Dir.mktmpdir('games-dice-validation') do |directory|
      FileUtils.mkdir_p(File.join(directory, 'lib'))
      File.write(File.join(directory, 'lib/probe.rb'), source)
      yield directory
    end
  end
end
