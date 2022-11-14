# frozen_string_literal: true
require 'sneakers'
require 'sneakers/metrics/statsd_metrics'

module NexusSemanticLogger
  class SneakersMetrics < Sneakers::Metrics::StatsdMetrics

    def initialize(component_name)
      @prefix = "nexus.#{component_name}."
      super(NexusSemanticLogger.metrics)
    end

    def increment(metric)
      super("#{@prefix}#{metric}")
    end

    def timing(metric, &block)
      super("#{@prefix}#{metric}", block)
    end
  end
end
