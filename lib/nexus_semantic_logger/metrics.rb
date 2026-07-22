# frozen_string_literal: true

module NexusSemanticLogger
  # Sends metrics to a statsd instance.
  # dogstatsd-ruby maintains its own queue and thread for flushing, so the client code should never create its
  # own statsd instance. Share one Metrics via NexusSemanticLogger.metrics instead.
  class Metrics
    # Stands in until a real client is configured, so callers never care.
    class NoopStatsd
      def increment(*, **); end

      def decrement(*, **); end

      def count(*, **); end

      def gauge(*, **); end

      def distribution(*, **); end

      def timing(*, **); end

      def flush(*, **); end
    end

    attr_accessor :statsd
    attr_reader :sync_flush

    # @param [Datadog::Statsd] statsd Client to delegate to, a noop by default.
    # @param [Boolean] sync_flush Force flushes to be synchronous, speeds up local checks.
    def initialize(statsd: NoopStatsd.new, sync_flush: false)
      @statsd = statsd
      @sync_flush = sync_flush
    end

    def flush
      statsd.flush(sync: sync_flush)
    end

    # Delegate to statsd.
    # @param [String] metric Metric name.
    # @param [Array<String>] tags Additional tags.
    def increment(metric, tags: [])
      statsd.increment(metric, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd.
    # @param [String] metric Metric name.
    # @param [Array<String>] tags Additional tags.
    def decrement(metric, tags: [])
      statsd.decrement(metric, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd.
    # @param [String] metric Metric name.
    # @param [Integer] ms Timing in milliseconds.
    # @param [Array<String>] tags Additional tags.
    def timing(metric, ms, tags: [])
      statsd.timing(metric, ms, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd.
    # @param [String] metric Metric name.
    # @param [Numeric] value Distribution value.
    # @param [Array<String>] tags Additional tags.
    def distribution(metric, value, tags: [])
      statsd.distribution(metric, value, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd.
    # @param [String] metric Metric name.
    # @param [Numeric] value Gauge value.
    # @param [Array<String>] tags Additional tags.
    def gauge(metric, value, tags: [])
      statsd.gauge(metric, value, tags: combine_tags(tags))
      flush
    end

    # Delegate to statsd.
    # @param [String] metric Metric name.
    # @param [Numeric] value Count value.
    # @param [Array<String>] tags Additional tags.
    def count(metric, value, tags: [])
      statsd.count(metric, value, tags: combine_tags(tags))
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
