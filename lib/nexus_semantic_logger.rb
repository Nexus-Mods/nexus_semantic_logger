# frozen_string_literal: true
require 'nexus_semantic_logger/appender_filter'
require 'nexus_semantic_logger/application'
require 'nexus_semantic_logger/datadog_formatter'
require 'nexus_semantic_logger/datadog_singleton'
require 'nexus_semantic_logger/datadog_tracer'
require 'nexus_semantic_logger/logger_metrics_subscriber'
require 'nexus_semantic_logger/traced_shell'

module NexusSemanticLogger
  class << self
    # The shared appender filter. Application setup replaces this with one built
    # from the app's config. It must be shared so the signal handler cycles the
    # level for every appender that uses it.
    attr_writer :appender_filter

    def appender_filter
      @appender_filter ||= AppenderFilter.new(fallback_level: rails_log_level)
    end

    # Get application wide object for sending metrics.
    def metrics
      DatadogSingleton.instance
    end

    # Get application wide object for running instrumented shell commands.
    def shell
      @shell ||= TracedShell.new
    end

    private

    def rails_log_level
      Rails.application&.config&.log_level if defined?(Rails)
    end
  end
end

# Patch access to LEVELS array.
module SemanticLogger
  module Levels
    def self.all_levels
      LEVELS
    end
  end
end
