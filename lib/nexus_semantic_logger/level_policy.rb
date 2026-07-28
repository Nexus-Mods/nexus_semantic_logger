# frozen_string_literal: true
require 'rails_semantic_logger'

module NexusSemanticLogger
  # The log level policy: a default level plus per logger-name overrides.
  # The default level is mutable so a running process can cycle it.
  class LevelPolicy
    LEVEL_NAME_VARS = {
      trace: 'LOG_NAMES_TRACE',
      debug: 'LOG_NAMES_DEBUG',
      info: 'LOG_NAMES_INFO',
      warn: 'LOG_NAMES_WARN',
      error: 'LOG_NAMES_ERROR',
      fatal: 'LOG_NAMES_FATAL',
    }.freeze

    attr_reader :default_level, :overrides

    # LOG_NAMES_DEFAULT_LEVEL sets the default, LOG_NAMES_<LEVEL> lists names
    # pinned to that level. A name in several lists keeps the most verbose.
    # @param [Hash] env Configuration source, ENV or a plain hash.
    # @param [String, Symbol, nil] fallback_level Used when the env vars are absent.
    # @return [LevelPolicy]
    def self.from_env(env, fallback_level: nil)
      overrides = {}
      LEVEL_NAME_VARS.each do |level, var|
        env.fetch(var, '').split(',').each { |name| overrides[name] ||= level }
      end

      new(
        default_level: env.fetch('LOG_NAMES_DEFAULT_LEVEL', fallback_level || :warn),
        overrides: overrides,
      )
    end

    # @param [String, Symbol] default_level Normalized to a lowercase Symbol.
    # @param [Hash<String, String, Symbol>] overrides Logger name to level.
    def initialize(default_level:, overrides: {})
      @default_level = self.class.normalize_level(default_level)
      @overrides = overrides.transform_values { |level| self.class.normalize_level(level) }.freeze
    end

    # Whether a log entry should be appended.
    # log API see https://logger.rocketjob.io/log_struct.html
    def call(log)
      threshold = overrides.fetch(log.name, default_level)
      log.level_index >= SemanticLogger::Levels.index(threshold)
    end

    # SemanticLogger 4.x only accepts a Proc or Regexp as an appender filter.
    # @return [Proc]
    def to_proc
      ->(log) { call(log) }
    end

    # Step the default level forward, wrapping from fatal back to trace.
    def cycle_default_level!
      next_index = SemanticLogger::Levels.index(default_level) + 1
      next_index = 0 if next_index >= SemanticLogger::Levels.all_levels.size
      @default_level = SemanticLogger::Levels.level(next_index)
    end

    def self.normalize_level(level)
      level.to_s.downcase.to_sym
    end
  end
end
