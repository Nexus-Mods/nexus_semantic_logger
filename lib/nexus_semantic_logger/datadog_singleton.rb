# frozen_string_literal: true
require 'singleton'

module NexusSemanticLogger
  # Application wide location to get datadog objects.
  # dogstatsd-ruby maintains its own queue and thread for flushing, so the client code should never create its
  # own statsd instance.
  class DatadogSingleton
    include Singleton
    attr_accessor :statsd

    def flush
      statsd&.flush(sync: Rails.env.development?) # Force flush sync in development, speed up checks.
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Array<String>] tags Additional tags.
    def increment(metric, tags: [])
      statsd&.increment(metric, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Array<String>] tags Additional tags.
    def decrement(metric, tags: [])
      statsd&.decrement(metric, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Integer] ms Timing in milliseconds.
    # @param [Array<String>] tags Additional tags.
    def timing(metric, ms, tags: [])
      statsd&.timing(metric, ms, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Numeric] value Distribution value.
    # @param [Array<String>] tags Additional tags.
    def distribution(metric, value, tags: [])
      statsd&.distribution(metric, value, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Numeric] value Gauge value.
    # @param [Array<String>] tags Additional tags.
    def gauge(metric, value, tags: [])
      statsd&.gauge(metric, value, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Numeric] value Count value.
    # @param [Array<String>] tags Additional tags.
    def count(metric, value, tags: [])
      statsd&.count(metric, value, tags: combine_tags(tags))
      flush
    end

    private

    # Safely combine the supplied tags.
    def combine_tags(tags)
      final_tags = []
      final_tags += tags unless tags.nil?
      final_tags
    end
  end
end
