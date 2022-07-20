# frozen_string_literal: true
require 'singleton'

module NexusSemanticLogger
  # Application wide location to get datadog objects.
  # Can be moved to its own gem in future, and there is scope to make the usage code even leaner.
  class DatadogSingleton
    include Singleton
    attr_accessor :statsd, :tags

    def flush
      statsd&.flush(sync: Rails.env.development?) # Force flush sync in development, speed up checks.
    end
  end
end
