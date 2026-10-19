# frozen_string_literal: true

require 'json'
require 'digest'
require 'games_dice'
require_relative 'reference_parser'
require_relative 'scanner'
require_relative 'measurement'
require_relative 'benchmark_cases'

module GamesDiceParserResearch
  # JSONL benchmark runner. Run each sample in a fresh process; compare per-input ratios.
  class Benchmark
    def initialize
      @seed = Integer(ENV.fetch('SEED', '20261019'))
      @iterations = Integer(ENV.fetch('ITERATIONS', '1000'))
      @warmup = Integer(ENV.fetch('WARMUP', '100'))
      @random = Random.new(@seed)
      @parsers = { reference: ReferenceParser.new, scanner: Scanner.new, production: GamesDice.parser }
    end

    def run
      puts JSON.generate(metadata: metadata)
      valid_jobs.shuffle(random: @random).each { |job| measure(job, iterations: valid_iterations(job)) }
      (invalid_jobs + constructor_jobs).shuffle(random: @random).each { |job| measure(job, iterations: 100) }
    end

    private

    def valid_iterations(job)
      %w[ordinary varied].include?(job.first[:group]) ? @iterations : 200
    end

    def metadata
      { ruby: RUBY_DESCRIPTION, parslet: Gem.loaded_specs.fetch('parslet').version.to_s,
        jit: defined?(RubyVM::YJIT) ? RubyVM::YJIT.enabled? : false, gc: 'enabled',
        seed: @seed, warmup: @warmup, iterations: @iterations, corpus_version: 1,
        source_commit: `git rev-parse HEAD`.strip, process: Process.pid,
        reference_commit: '610b670524410c91fe2daac6c1199f1f61d1b4df',
        research_sha256: research_checksums, production_sha256: production_checksums }
    end

    def research_checksums
      Dir.glob(File.join(__dir__, '*.rb')).to_h do |path|
        [File.basename(path), Digest::SHA256.file(path).hexdigest]
      end
    end

    def production_checksums
      root = File.expand_path('../..', __dir__)
      Dir.glob(File.join(root, 'lib/**/*.rb')).to_h do |path|
        [path.delete_prefix("#{root}/"), Digest::SHA256.file(path).hexdigest]
      end
    end

    def valid_jobs
      @parsers.flat_map do |name, parser|
        BenchmarkCases.valid_inputs.flat_map do |group, text|
          jobs(name, group, text, BenchmarkCases.valid_operations(parser, text)) +
            varied_jobs(name, parser, group, text)
        end
      end
    end

    def varied_jobs(name, parser, group, text)
      return [] unless group == 'ordinary'

      jobs(name, 'varied', text, BenchmarkCases.varied_operations(parser, text))
    end

    def invalid_jobs
      @parsers.flat_map do |name, parser|
        BenchmarkCases.invalid_inputs.flat_map do |group, text|
          operations = { reject: BenchmarkCases.failure_operation(parser, text),
                         render: BenchmarkCases.failure_operation(parser, text, render: true) }
          jobs(name, group, text, operations)
        end
      end
    end

    def constructor_jobs
      @parsers.flat_map do |name, parser|
        Corpus::CONSTRUCTOR_FAILURES.flat_map do |text|
          jobs(name, 'constructor_failure', text, BenchmarkCases.constructor_failures(parser, text))
        end
      end
    end

    def jobs(name, group, text, operations)
      operations.map do |operation, callable|
        [{ parser: name, group: group, input: text, operation: operation }, callable]
      end
    end

    def measure(job, iterations: @iterations)
      labels, callable = job
      result = Measurement.new(iterations: iterations, warmup: @warmup, seed: @seed).call(callable)
      puts JSON.generate(labels.merge(result))
    end
  end
end

GamesDiceParserResearch::Benchmark.new.run if $PROGRAM_NAME == __FILE__
