# frozen_string_literal: true
require 'nexus_semantic_logger/level_policy'
require 'nexus_semantic_logger/application'
require 'nexus_semantic_logger/datadog_formatter'
require 'nexus_semantic_logger/datadog_singleton'
require 'nexus_semantic_logger/metrics'
require 'nexus_semantic_logger/datadog_tracer'
require 'nexus_semantic_logger/logger_metrics_subscriber'
require 'nexus_semantic_logger/traced_shell'

module NexusSemanticLogger
  class << self
    # The shared metrics object. DatadogTracer replaces this with one built
    # around a real statsd client, the default is a no op.
    attr_writer :metrics

    # Get application wide object for sending metrics.
    def metrics
      @metrics ||= Metrics.new
    end

    # Get application wide object for running instrumented shell commands.
    def shell
      @shell ||= TracedShell.new
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
