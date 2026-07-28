# frozen_string_literal: true
require 'nexus_semantic_logger/metrics'

module NexusSemanticLogger
  # Deprecated, kept for services that reference the old name directly,
  # including verified doubles of its instance methods in their specs.
  # The shared metrics object lives at NexusSemanticLogger.metrics.
  class DatadogSingleton < Metrics
    def self.instance
      NexusSemanticLogger.metrics
    end
  end
end
