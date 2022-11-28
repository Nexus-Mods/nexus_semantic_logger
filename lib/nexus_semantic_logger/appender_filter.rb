# frozen_string_literal: true
require 'rails_semantic_logger'

module NexusSemanticLogger
  class AppenderFilter
    def self.filter_lambda
      -> (log) {
        # log API see https://logger.rocketjob.io/log_struct.html
        # and lib/semantic_logger/levels.rb
        # level: :trace=>0, :debug=>1, :info=>2, :warn=>3, :error=>4, :fatal=>5
        current_log_level = SemanticLogger::Levels.index(env_names_default_level)

        # Names allow overriding the level that will be appended,
        # else the global level is used to determine appending.
        append = false
        if log.name.in?(env_names_trace)
          append = true
        elsif log.name.in?(env_names_debug)
          append = log.level_index >= 1
        elsif log.name.in?(env_names_info)
          append = log.level_index >= 2
        elsif log.name.in?(env_names_warn)
          append = log.level_index >= 3
        elsif log.name.in?(env_names_error)
          append = log.level_index >= 4
        elsif log.name.in?(env_names_fatal)
          append = log.level_index >= 5
        else
          append = log.level_index >= current_log_level
        end
        append
      }
    end

    def self.env_level
      @@level ||= ENV.fetch('LOG_LEVEL', Rails.application.config.log_level).downcase
    end

    def self.env_names_default_level
      @@names_default_level ||= ENV.fetch('LOG_NAMES_DEFAULT_LEVEL', Rails.application.config.log_level).downcase
    end

    def self.env_names_trace
      @@names_trace ||= fetch_env_names('LOG_NAMES_TRACE')
    end

    def self.env_names_debug
      @@names_debug ||= fetch_env_names('LOG_NAMES_DEBUG')
    end

    def self.env_names_info
      @@names_info ||= fetch_env_names('LOG_NAMES_INFO')
    end

    def self.env_names_warn
      @@names_warn ||= fetch_env_names('LOG_NAMES_WARN')
    end

    def self.env_names_error
      @@names_error ||= fetch_env_names('LOG_NAMES_ERROR')
    end

    def self.env_names_fatal
      @@names_fatal ||= fetch_env_names('LOG_NAMES_FATAL')
    end

    def self.flush
      @@level = nil
      @@names_default_level = nil
      @@names_trace = nil
      @@names_debug = nil
      @@names_info = nil
      @@names_warn = nil
      @@names_error = nil
      @@names_fatal = nil
    end

    def self.fetch_env_names(var)
      ENV.fetch(var, '').split(',').to_set
    end

    # Change LOG_LEVEL and LOG_NAMES_DEFAULT_LEVEL on a running process by sending signals.
    # Each signal rotates through the levels, wrapping around.
    # Based on SemanticLogger.add_signal_handler.
    # Note that USR1/USR2 are already used by puma. WINCH/SYS should be unused these days.
    def self.add_signal_handler(log_names_level_signal = "WINCH", info_signal = "SYS")
      if log_names_level_signal
        Signal.trap(log_names_level_signal) do
          current_level = env_names_default_level
          next_level = get_next_log_level(current_level)
          @@names_default_level = next_level
          puts "#{log_names_level_signal} signal changed LOG_NAMES_DEFAULT_LEVEL from #{current_level} to #{next_level}"
        rescue => err
          puts "Error handling signal #{log_names_level_signal}: #{err}"
          puts err.backtrace
        end
      end

      if info_signal
        Signal.trap(info_signal) do
          current_level = env_names_default_level
          puts "#{info_signal} signal reports LOG_LEVEL=#{env_level} LOG_NAMES_DEFAULT_LEVEL=#{current_level}"
        rescue => err
          puts "Error handling signal #{info_signal}: #{err}"
          puts err.backtrace
        end
      end
    end

    private

    def self.get_next_log_level(current_log_level)
      current_log_level_index = SemanticLogger::Levels.index(current_log_level)
      next_log_level_index = current_log_level_index + 1
      next_log_level_index = 0 if next_log_level_index >= SemanticLogger::Levels.all_levels.size
      SemanticLogger::Levels.level(next_log_level_index)
    end
  end
end
