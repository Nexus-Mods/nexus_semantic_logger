# frozen_string_literal: true
require 'singleton'

module NexusSemanticLogger
  # Application wide location to get datadog objects.
  # dogstatsd-ruby maintains its own queue and thread for flushing, so the client code should never create its
  # own statsd instance.
  class DatadogSingleton
    include Singleton
    attr_accessor :statsd, :global_tags

    def flush
      statsd&.flush(sync: Rails.env.development?) # Force flush sync in development, speed up checks.
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Array<String>] tags Additional tags.
    def increment(metric, tags: [])
      statsd&.increment(metric, tags: global_tags + tags)
      flush
    end

    # Delegate to statsd (if available).
    # @param [String] metric Metric name.
    # @param [Integer] ms Timing in milliseconds.
    # @param [Array<String>] tags Additional tags.
    def timing(metric, ms, tags: [])
      statsd&.timing(metric, ms, tags: global_tags + tags)
      flush
    end
  end
end
