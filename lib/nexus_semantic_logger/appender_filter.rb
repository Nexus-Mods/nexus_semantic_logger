# frozen_string_literal: true
require 'rails_semantic_logger'

module NexusSemanticLogger
  # Filters appender output by log level, with per logger-name overrides.
  #
  # Configuration is read once at construction from the supplied env hash
  # (ENV by default), so instances hold plain state and never touch ENV at
  # log time:
  #   LOG_NAMES_DEFAULT_LEVEL  level applied to loggers without an override.
  #   LOG_NAMES_TRACE ... LOG_NAMES_FATAL  comma separated logger names that
  #     log at that level regardless of the default.
  #
  # One shared instance lives at NexusSemanticLogger.appender_filter so that
  # the signal handler cycles the level for every appender using the filter.
  class AppenderFilter
    LEVEL_NAME_VARS = {
      trace: 'LOG_NAMES_TRACE',
      debug: 'LOG_NAMES_DEBUG',
      info: 'LOG_NAMES_INFO',
      warn: 'LOG_NAMES_WARN',
      error: 'LOG_NAMES_ERROR',
      fatal: 'LOG_NAMES_FATAL',
    }.freeze

    attr_reader :default_level, :level

    # @param [Hash] env Configuration source, ENV by default.
    # @param [String, Symbol, nil] fallback_level Used when the env vars are absent,
    #   typically the Rails config.log_level.
    # Levels are normalized to lowercase Symbols regardless of input type.
    def initialize(env: ENV, fallback_level: nil)
      fallback = normalize_level(fallback_level || :warn)
      @level = normalize_level(env.fetch('LOG_LEVEL', fallback))
      @default_level = normalize_level(env.fetch('LOG_NAMES_DEFAULT_LEVEL', fallback))
      @name_overrides = LEVEL_NAME_VARS.transform_values do |var|
        env.fetch(var, '').split(',').to_set
      end
    end

    # log API see https://logger.rocketjob.io/log_struct.html
    def call(log)
      override = @name_overrides.find { |_level, names| names.include?(log.name) }&.first
      threshold = override || default_level
      log.level_index >= SemanticLogger::Levels.index(threshold)
    end

    # SemanticLogger 4.x only accepts a Proc or Regexp as an appender filter.
    def to_proc
      ->(log) { call(log) }
    end

    # Change the default level on a running process by sending signals.
    # Each signal rotates through the levels, wrapping around.
    # Note that USR1/USR2 are already used by puma. WINCH/SYS should be unused these days.
    # The handlers only touch plain instance state, keeping them trap safe.
    def add_signal_handler(level_signal = 'WINCH', info_signal = 'SYS')
      if level_signal
        Signal.trap(level_signal) do
          previous_level = default_level
          cycle_default_level!
          puts "#{level_signal} signal changed LOG_NAMES_DEFAULT_LEVEL from #{previous_level} to #{default_level}"
        rescue => err
          puts "Error handling signal #{level_signal}: #{err}"
          puts err.backtrace
        end
      end

      return unless info_signal

      Signal.trap(info_signal) do
        puts "#{info_signal} signal reports LOG_LEVEL=#{level} LOG_NAMES_DEFAULT_LEVEL=#{default_level}"
      rescue => err
        puts "Error handling signal #{info_signal}: #{err}"
        puts err.backtrace
      end
    end

    # Step the default level forward, wrapping from fatal back to trace.
    def cycle_default_level!
      @default_level = self.class.next_level(default_level)
    end

    def self.next_level(current_level)
      next_index = SemanticLogger::Levels.index(current_level) + 1
      next_index = 0 if next_index >= SemanticLogger::Levels.all_levels.size
      SemanticLogger::Levels.level(next_index)
    end

    private

    def normalize_level(level)
      level.to_s.downcase.to_sym
    end

    # Backwards compatible class level API, delegating to the shared instance.
    class << self
      alias_method :get_next_log_level, :next_level

      def filter_lambda
        NexusSemanticLogger.appender_filter.to_proc
      end

      def add_signal_handler(level_signal = 'WINCH', info_signal = 'SYS')
        NexusSemanticLogger.appender_filter.add_signal_handler(level_signal, info_signal)
      end

      # Discard the shared instance so the next use re-reads configuration.
      def flush
        NexusSemanticLogger.appender_filter = nil
      end
    end
  end
end
