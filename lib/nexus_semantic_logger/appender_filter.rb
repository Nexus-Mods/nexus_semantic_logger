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
        elsif (log.name.in?(env_names_debug))
          append = log.level_index >= 1
        elsif (log.name.in?(env_names_info))
          append = log.level_index >= 2
        elsif (log.name.in?(env_names_warn))
          append = log.level_index >= 3
        elsif (log.name.in?(env_names_error))
          append = log.level_index >= 4
        elsif (log.name.in?(env_names_fatal))
          append = log.level_index >= 5
        else
          append = log.level_index >= current_log_level
        end
        append
      }
    end

    def self.env_names_default_level
      @@names_default_level ||= ENV.fetch('LOG_NAMES_DEFAULT_LEVEL', Rails.application.config.log_level)
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

    private

    def self.fetch_env_names(var)
      ENV.fetch(var, '').split(',').to_set
    end
  end
end
