# frozen_string_literal: true

module GamesDiceParserResearch
  # Anchored modifier recognition and direct constructor-data emission.
  module ScannerModifiers
    OPERATORS = { '==' => :==, '>=' => :<=, '>' => :<, '<' => :>, '<=' => :>= }.freeze
    REROLL = /r:(>=|<=|==|>|<)?([0-9]+)(?:,([a-z_]+)(?:,([0-9]+))?)?\./
    MAP = /m:(>=|<=|==|>|<)?([0-9]+)(?:,([+-]?[0-9]+)(?:,([A-Za-z0-9_]+))?)?\./
    KEEP = /k:([0-9]+)(?:,([a-z_]+))?\./

    private

    def modifiers(bunch)
      loop do
        if @scanner.scan(/([rkm])([0-9]+)\.?/)
          simple_modifier(bunch, @scanner[1], @scanner[2].to_i)
        elsif @scanner.skip(/x\.?/)
          (bunch[:rerolls] ||= []) << [bunch[:sides], :==, :reroll_add]
        elsif !full_modifier?(bunch)
          break
        end
      end
    end

    def simple_modifier(bunch, type, value)
      case type
      when 'r' then (bunch[:rerolls] ||= []) << [value, :>=, :reroll_replace]
      when 'm' then (bunch[:maps] ||= []) << [value, :<=, 1]
      when 'k' then keep(bunch, value, 'best')
      end
    end

    def full_modifier?(bunch)
      if @scanner.scan(REROLL)
        reroll(bunch)
      elsif @scanner.scan(MAP)
        map(bunch)
      elsif @scanner.scan(KEEP)
        keep(bunch, @scanner[1].to_i, @scanner[2] || 'best')
      else
        return false
      end
      true
    end

    def reroll(bunch)
      rule = [@scanner[2].to_i, OPERATORS.fetch(@scanner[1] || '=='), :"reroll_#{@scanner[3] || 'replace'}"]
      rule << @scanner[4].to_i if @scanner[4]
      (bunch[:rerolls] ||= []) << rule
    end

    def map(bunch)
      rule = [@scanner[2].to_i, OPERATORS.fetch(@scanner[1] || '>='), (@scanner[3] || '1').to_i]
      rule << @scanner[4] if @scanner[4]
      (bunch[:maps] ||= []) << rule
    end

    def keep(bunch, number, type)
      fail_at('Cannot set keepers for a bunch twice') if bunch[:keep_mode]
      bunch[:keep_number] = number
      bunch[:keep_mode] = :"keep_#{type}"
    end
  end
end
