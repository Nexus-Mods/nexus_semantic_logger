# frozen_string_literal: true
require 'nexus_semantic_logger/appender_filter'
require 'nexus_semantic_logger/application'
require 'nexus_semantic_logger/datadog_formatter'
require 'nexus_semantic_logger/datadog_singleton'
require 'nexus_semantic_logger/datadog_tracer'

module NexusSemanticLogger

  # Get application wide object for sending metrics.
  def metrics
    DatadogSingleton.instance
  end
end
