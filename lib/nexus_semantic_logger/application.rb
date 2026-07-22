# frozen_string_literal: true
require 'rails_semantic_logger'

module NexusSemanticLogger
  class Application
    include SemanticLogger::Loggable

    class << self
      def common(config, service, env: ENV)
        # Set a safe logging level which individual environments can make more verbose if needed.
        config.log_level = env.fetch('LOG_LEVEL', 'WARN')

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

        policy = level_policy(config, env)

        # Default logging is stdout in datadog compatible JSON.
        config.rails_semantic_logger.format = NexusSemanticLogger::DatadogFormatter.new(service)
        config.rails_semantic_logger.add_file_appender = false
        dd_appender = config.semantic_logger.add_appender(io: $stdout, formatter: config.rails_semantic_logger.format)
        dd_appender.filter = policy.to_proc

        add_signal_handlers(policy, config.log_level)

        NexusSemanticLogger::DatadogTracer.new(service, env: env)

        SemanticLogger.on_log(NexusSemanticLogger::LoggerMetricsSubscriber.new)

        logger.info('SemanticLogger initialised.', level: config.log_level)

        config.after_initialize do
          require("nexus_semantic_logger/extensions/action_dispatch/debug_exceptions") if defined?(
            ::ActionDispatch::DebugExceptions)
          warn_on_incompatible_rails_semantic_logger
        end
      end

      def development(config, env: ENV)
        # Enable debug globally.
        config.log_level = env.fetch('LOG_LEVEL', 'DEBUG')

        policy = level_policy(config, env)

        # Change default logging to coloured logging on stdout.
        config.semantic_logger.clear_appenders!
        color_appender = config.semantic_logger.add_appender(io: $stdout, formatter: :color)
        color_appender.filter = policy.to_proc

        if env['DD_AGENT_HOST'].present? && env['DD_AGENT_LOGGING_PORT'].present?
          # Development logs can be sent to datadog via a TCP logging endpoint on a local agent.
          # Each port is assigned a particular service.
          # See https://logger.rocketjob.io/appenders.html
          dd_appender = config.semantic_logger.add_appender(
            appender: :tcp,
            server: "#{env['DD_AGENT_HOST']}:#{env['DD_AGENT_LOGGING_PORT']}",
            formatter: config.rails_semantic_logger.format
          )
          dd_appender.filter = policy.to_proc
        end

        logger.info('SemanticLogger initialised in development.', level: config.log_level)

        # Ensure logging is immediately flushed.
        $stdout.sync = true
      end

      def test(config, env: ENV)
        policy = level_policy(config, env)

        # Use human readable coloured output for logs when running tests.
        config.semantic_logger.clear_appenders!
        color_appender = config.semantic_logger.add_appender(io: $stdout, formatter: :color)
        color_appender.filter = policy.to_proc

        # Ensure logging is immediately flushed.
        $stdout.sync = true
      end

      private

      # Memoized on the config so every entry point shares one instance.
      def level_policy(config, env)
        config.nexus_semantic_logger ||= ActiveSupport::OrderedOptions.new
        config.nexus_semantic_logger.level_policy ||= LevelPolicy.from_env(env, fallback_level: config.log_level)
      end

      # Cycle LOG_NAMES_DEFAULT_LEVEL or report levels on a running process.
      # USR1/USR2 are taken by puma. Handlers only touch plain policy state,
      # keeping them trap safe.
      def add_signal_handlers(policy, log_level, level_signal: 'WINCH', info_signal: 'SYS')
        Signal.trap(level_signal) do
          previous_level = policy.default_level
          policy.cycle_default_level!
          puts "#{level_signal} signal changed LOG_NAMES_DEFAULT_LEVEL " \
            "from #{previous_level} to #{policy.default_level}"
        rescue => err
          puts "Error handling signal #{level_signal}: #{err}"
          puts err.backtrace
        end

        Signal.trap(info_signal) do
          puts "#{info_signal} signal reports LOG_LEVEL=#{log_level} LOG_NAMES_DEFAULT_LEVEL=#{policy.default_level}"
        rescue => err
          puts "Error handling signal #{info_signal}: #{err}"
          puts err.backtrace
        end
      end

      # Rails 8.1 needs rails_semantic_logger 5.x and no gemspec can express
      # that, so detect the broken pairing at boot. Shimmed apps stay quiet.
      def warn_on_incompatible_rails_semantic_logger
        return unless defined?(::ActiveRecord::RuntimeRegistry)
        return if ::ActiveRecord::RuntimeRegistry.respond_to?(:sql_runtime)
        return if Gem::Version.new(RailsSemanticLogger::VERSION) >= Gem::Version.new('5.0')

        logger.warn(
          'rails_semantic_logger 4.x cannot log ActiveRecord events on this Rails version, every ' \
          'sql.active_record event will log a NoMethodError instead of the query. Add ' \
          '`gem "rails_semantic_logger", ">= 5.1"` to your Gemfile so bundler refuses this ' \
          'pairing, then `bundle update rails_semantic_logger semantic_logger`.'
        )
      end
    end
  end
end
