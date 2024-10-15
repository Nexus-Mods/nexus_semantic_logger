# frozen_string_literal: true
require 'puma'
require 'puma/plugin'
require 'socket'
require 'nexus_semantic_logger'

# Forked from puma-plugin-statsd.
# Uses the same datadog settings as nexus_semantic_logger.
# To use, add to puma.rb:
#   plugin :nexus_puma_statsd

# Wrap puma's stats in a safe API
class PumaStats
  def initialize(stats)
    @stats = stats
  end

  def clustered?
    @stats.key?(:workers)
  end

  def workers
    @stats.fetch(:workers, 1)
  end

  def booted_workers
    @stats.fetch(:booted_workers, 1)
  end

  def old_workers
    @stats.fetch(:old_workers, 0)
  end

  def running
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:running, 0) }.inject(0, &:+)
    else
      @stats.fetch(:running, 0)
    end
  end

  def backlog
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:backlog, 0) }.inject(0, &:+)
    else
      @stats.fetch(:backlog, 0)
    end
  end

  def pool_capacity
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:pool_capacity, 0) }.inject(0, &:+)
    else
      @stats.fetch(:pool_capacity, 0)
    end
  end

  def max_threads
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:max_threads, 0) }.inject(0, &:+)
    else
      @stats.fetch(:max_threads, 0)
    end
  end

  def requests_count
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:requests_count, 0) }.inject(0, &:+)
    else
      @stats.fetch(:requests_count, 0)
    end
  end
end

Puma::Plugin.create do
  # We can start doing something when we have a launcher:
  def start(launcher)
    @launcher = launcher
    @log_writer =
      if Gem::Version.new(Puma::Const::PUMA_VERSION) >= Gem::Version.new(6)
        @launcher.log_writer
      else
        @launcher.events
      end

    @log_writer.debug('statsd: enabled')

    register_hooks
  end

  private

  def register_hooks
    in_background(&method(:stats_loop))
  end

  def environment_variable_tags
    # Tags are separated by spaces, and while they are normally a tag and
    # value separated by a ':', they can also just be tagged without any
    # associated value.
    #
    # Examples: simple-tag-0 tag-key-1:tag-value-1
    #
    tags = []

    if ENV.key?('HOSTNAME')
      tags << "pod_name:#{ENV['HOSTNAME']}"
    end

    # Standardised datadog tag attributes, so that we can share the metric
    # tags with the application running
    #
    # https://docs.datadoghq.com/agent/docker/?tab=standard#global-options
    #
    if ENV.key?("DD_TAGS")
      ENV["DD_TAGS"].split(/\s+|,/).each do |t|
        tags << t
      end
    end

    # Support the Unified Service Tagging from Datadog, so that we can share
    # the metric tags with the application running
    #
    # https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging
    if ENV.key?('DD_ENV')
      tags << "env:#{ENV['DD_ENV']}"
    end

    if ENV.key?('DD_SERVICE')
      tags << "service:#{ENV['DD_SERVICE']}"
    end

    if ENV.key?('DD_VERSION')
      tags << "version:#{ENV['DD_VERSION']}"
    end

    # Support the origin detection over UDP from Datadog, it allows DogStatsD
    # to detect where the container metrics come from, and tag metrics automatically.
    #
    # https://docs.datadoghq.com/developers/dogstatsd/?tab=kubernetes#origin-detection-over-udp
    if ENV.key?('DD_ENTITY_ID')
      tags << "dd.internal.entity_id:#{ENV['DD_ENTITY_ID']}"
    end

    return nil if tags.empty?

    tags
  end

  # Send data to statsd every few seconds
  def stats_loop
    tags = environment_variable_tags

    sleep(5)
    loop do
      @log_writer.debug('statsd: notify statsd')
      begin
        stats = ::PumaStats.new(Puma.stats_hash)
        NexusSemanticLogger.metrics.gauge('puma.workers', stats.workers, tags: tags)
        NexusSemanticLogger.metrics.gauge('puma.booted_workers', stats.booted_workers, tags: tags)
        NexusSemanticLogger.metrics.gauge('puma.old_workers', stats.old_workers, tags: tags)
        NexusSemanticLogger.metrics.gauge('puma.running', stats.running, tags: tags)
        NexusSemanticLogger.metrics.gauge('puma.backlog', stats.backlog, tags: tags)
        NexusSemanticLogger.metrics.gauge('puma.pool_capacity', stats.pool_capacity, tags: tags)
        NexusSemanticLogger.metrics.gauge('puma.max_threads', stats.max_threads, tags: tags)
        NexusSemanticLogger.metrics.count('puma.requests_count', stats.requests_count, tags: tags)
      rescue StandardError => e
        @log_writer.unknown_error(e, nil, '! statsd: notify stats failed')
      ensure
        sleep(2)
      end
    end
  end
end
