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
      hash[:service] = @service
      hash.delete(:application)
      hash.delete(:environment)
      hash.delete('')
      # datadog correlation inserted via log_tags, but datadog expects them in the root hash.
      named_tags = hash.delete(:named_tags)
      if named_tags.is_a?(Hash)
        hash.deep_merge!(named_tags)
      end
      hash_to_json(hash)
    end

    # Serialise hash to json while ensuring we don't abort due to an infinite loop.
    # SystemStackError while serialising indicates an infinite loop- determine which key is affected.
    def hash_to_json(hash)
      hash.to_json
    rescue SystemStackError
      as_json_serialise_errors = []
      hash.keys.each do |key|
        hash[key].as_json
      rescue SystemStackError
        hash.delete(key)
        as_json_serialise_errors << key
      end
      hash[:as_json_serialise_errors] = as_json_serialise_errors
      hash.to_json
    end
  end
end
