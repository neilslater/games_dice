# frozen_string_literal: true

module GamesDice
  # @api private
  # A structural snapshot of exposed recipe arrays. Stable reads allocate nothing.
  class RecipeCache
    def initialize(sources, labels)
      @sources = sources
      @labels = labels
      @format = 1
      capture
    end

    # @return [Boolean] Whether this is a recognized snapshot format.
    def valid?
      @format == 1
    end

    def changed?
      index = 0
      while index < @sources.length
        array, = @sources[index]
        return true if source_changed?(array, @snapshots[index])

        index += 1
      end
      @labels != @label_copies
    end

    # Records entry references, component versions, and copies of mutable labels.
    def capture
      @snapshots = @sources.map do |array, klass|
        array&.map do |entry|
          validate(entry, klass)
          [entry, child_version(entry), label_copy(entry)]
        end
      end
      @label_copies = @labels.map(&:dup)
    end

    private

    def source_changed?(array, snapshot)
      return false unless array
      return true unless snapshot && array.length == snapshot.length

      index = 0
      while index < array.length
        return true if entry_changed?(array[index], snapshot[index])

        index += 1
      end
      false
    end

    def entry_changed?(entry, snapshot)
      saved, version, label = snapshot
      return true unless entry.equal?(saved)
      return true if version && entry.__send__(:recipe_version) != version

      label && entry.mapped_name != label
    end

    def validate(entry, klass)
      raise TypeError, "Expected #{klass}, got #{entry.class}" unless entry.is_a?(klass)
    end

    def child_version(entry)
      entry.__send__(:recipe_version) if entry.is_a?(Bunch) || entry.is_a?(ComplexDie)
    end

    def label_copy(entry)
      entry.mapped_name.dup if entry.is_a?(MapRule)
    end
  end

  # @api private
  # Shared invalidation and transaction boundary for recipe-dependent operations.
  module RecipeQueries
    private

    def initialize_copy(original)
      super
      @recipe_cache = nil
      refresh_recipe
    end

    def initialize_recipe
      @recipe_cache = RecipeCache.new(recipe_sources, recipe_labels)
      @recipe_version = 0
    end

    def recipe_labels
      []
    end

    def recipe_version
      refresh_recipe
      @recipe_version
    end

    def refresh_recipe
      validate_recipe
      restore_recipe_cache unless @recipe_cache.is_a?(RecipeCache) && @recipe_cache.valid?
      return unless @recipe_cache.changed?

      clear_derived_state
      @recipe_version += 1
      @recipe_cache.capture
    rescue TypeError, ArgumentError
      clear_derived_state
      @recipe_version = (@recipe_version || 0) + 1
      raise
    end

    def restore_recipe_cache
      previous_version = @recipe_version || 0
      initialize_recipe
      @recipe_version = previous_version + 1
      clear_derived_state
    end

    def validate_recipe; end

    def clear_derived_state
      @probabilities = @probability_error = @probabilities_complete = nil
      @min = @max = @min_result = @max_result = nil
      @result = @raw_result_details = @used_result_details = nil
    end

    def valid_probability_cache?(limit)
      @probabilities && @probability_error.is_a?(Float) && @probability_error >= 0.0 && @probability_error <= limit
    end

    def with_recipe
      version = recipe_version
      result = yield
      completed = true
      result
    ensure
      verify_recipe(version, completed) if version
    end

    def verify_recipe(version, completed)
      discard_changed_recipe(completed) if recipe_version != version
    rescue TypeError, ArgumentError
      discard_changed_recipe(completed)
    end

    def discard_changed_recipe(completed)
      clear_derived_state
      raise 'Dice recipe changed during calculation' if completed
    end
  end
end
