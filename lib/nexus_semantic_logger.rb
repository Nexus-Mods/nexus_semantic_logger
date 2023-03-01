# frozen_string_literal: true
require 'nexus_semantic_logger/appender_filter'
require 'nexus_semantic_logger/application'
require 'nexus_semantic_logger/datadog_formatter'
require 'nexus_semantic_logger/datadog_singleton'
require 'nexus_semantic_logger/datadog_tracer'
require 'nexus_semantic_logger/ddtrace_ruby3_patch'
require 'nexus_semantic_logger/logger_metrics_subscriber'

module NexusSemanticLogger
  # Get application wide object for sending metrics.
  def self.metrics
    DatadogSingleton.instance
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
