# frozen_string_literal: true
require 'rails_semantic_logger'

module NexusSemanticLogger
  class Application
    include SemanticLogger::Loggable

    def self.common(config, service)
      # Set a safe logging level which individual environments can make more verbose if needed.
      config.log_level = ENV.fetch('LOG_LEVEL', 'WARN')

      # semanticlogger ddtrace correlation.
      # From https://github.com/DataDog/dd-trace-rb/issues/1450
      # Also https://docs.datadoghq.com/tracing/connect_logs_and_traces/ruby/
      config.log_tags = {
        request_id: :request_id,
        dd: -> (_) {
          correlation = Datadog::Tracing.correlation
          {
            trace_id: correlation.trace_id.to_s,
            span_id: correlation.span_id.to_s,
            env: correlation.env.to_s,
            service: correlation.service.to_s,
            version: correlation.version.to_s,
          }
        },
        ddsource: ["ruby"],
      }

      # Synchronous mode is vital when puma is in single thread mode. Must add appender AFTER setting sync.
      SemanticLogger.sync!

      # Default logging is stdout in datadog compatible JSON.
      config.rails_semantic_logger.format = NexusSemanticLogger::DatadogFormatter.new(service)
      config.rails_semantic_logger.add_file_appender = false
      dd_appender = config.semantic_logger.add_appender(io: $stdout, formatter: config.rails_semantic_logger.format)
      dd_appender.filter = NexusSemanticLogger::AppenderFilter.filter_lambda
      NexusSemanticLogger::AppenderFilter.add_signal_handler

      NexusSemanticLogger::DatadogTracer.new(service)

      SemanticLogger.on_log(NexusSemanticLogger::LoggerMetricsSubscriber.new)

      logger.info('SemanticLogger initialised.', level: config.log_level)

      config.after_initialize do
        require("nexus_semantic_logger/extensions/action_dispatch/debug_exceptions") if defined?(
          ::ActionDispatch::DebugExceptions)
      end
    end

    def self.development(config)
      # Enable debug globally.
      config.log_level = ENV.fetch('LOG_LEVEL', 'DEBUG')

      # Change default logging to coloured logging on stdout.
      config.semantic_logger.clear_appenders!
      color_appender = config.semantic_logger.add_appender(io: $stdout, formatter: :color)
      color_appender.filter = NexusSemanticLogger::AppenderFilter.filter_lambda

      if ENV['DD_AGENT_HOST'].present? && ENV['DD_AGENT_LOGGING_PORT'].present?
        # Development logs can be sent to datadog via a TCP logging endpoint on a local agent.
        # Each port is assigned a particular service.
        # See https://logger.rocketjob.io/appenders.html
        dd_appender = config.semantic_logger.add_appender(
          appender: :tcp,
          server: "#{ENV['DD_AGENT_HOST']}:#{ENV['DD_AGENT_LOGGING_PORT']}",
          formatter: config.rails_semantic_logger.format
        )
        dd_appender.filter = NexusSemanticLogger::AppenderFilter.filter_lambda
      end

      logger.info('SemanticLogger initialised in development.', level: config.log_level)

      # Ensure logging is immediately flushed.
      $stdout.sync = true
    end

    def self.test(config)
      # Use human readable coloured output for logs when running tests.
      config.semantic_logger.clear_appenders!
      color_appender = config.semantic_logger.add_appender(io: $stdout, formatter: :color)
      color_appender.filter = NexusSemanticLogger::AppenderFilter.filter_lambda

      # Ensure logging is immediately flushed.
      $stdout.sync = true
    end
  end
end
