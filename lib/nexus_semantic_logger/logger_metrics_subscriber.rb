# frozen_string_literal: true
require 'semantic_logger'

module NexusSemanticLogger
  # Sends SemanticLogger metrics to statsd.
  # This is a candidate to move into the nexus_semantic_logger gem if it becomes widely useful.
  # See https://logger.rocketjob.io/metrics.html
  # Based on https://github.com/reidmorrison/semantic_logger/blob/master/lib/semantic_logger/metric/statsd.rb
  class LoggerMetricsSubscriber < SemanticLogger::Subscriber

    def call(log)
      log(log) if should_log?(log)
    end

    def log(log)
      metric = log.metric
      tags = log.payload.nil? ? nil : []
      log.payload&.each_pair { |key, value| tags << "#{key}:#{value}" }
      if (duration = log.duration)
        NexusSemanticLogger.metrics.timing(metric, duration, tags: tags)
      else
        amount = (log.metric_amount || 1).round
        if amount.negative?
          NexusSemanticLogger.metrics.decrement(metric, tags: tags)
        else
          NexusSemanticLogger.metrics.increment(metric, tags: tags)
        end
      end
    end

    # Only forward log entries that contain metrics.
    def should_log?(log)
      # Does not support metrics with dimensions.
      log.metric && !log.dimensions && meets_log_level?(log) && !filtered?(log)
    end
  end
end
