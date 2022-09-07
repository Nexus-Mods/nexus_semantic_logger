# frozen_string_literal: true
require 'semantic_logger'

module NexusSemanticLogger
  # Some attributes are reserved for use by Datadog.
  #  https://docs.datadoghq.com/logs/log_configuration/attributes_naming_convention/#reserved-attributes
  #   host     Supported by super.
  #   source   Overridden by this class.
  #   status   Supported by super as level, this class moves to status.
  #   date     Supported by super as time, this class configures as date.
  #   message  Supported by super.
  #   env      Added by this class.
  #   service  Added by this class.
  class DatadogFormatter < SemanticLogger::Formatters::Raw
    def initialize(service)
      super(time_format: :iso_8601, time_key: :date)
      @service = service
    end

    def call(log, logger)
      hash = super(log, logger).clone
      hash[:source] = :rails
      level = hash.delete(:level)
      hash[:status] = level
      hash[:railsenv] = Rails.env
      hash[:service] = @service
      hash.delete(:application)
      hash.delete(:environment)
      hash.delete('')
      # ddtrace correlation inserted via log_tags, but datadog expects them in the root hash.
      named_tags = hash.delete(:named_tags)
      if named_tags.is_a?(Hash)
        hash.deep_merge!(named_tags)
      end
      hash.to_json
    end
  end
end
