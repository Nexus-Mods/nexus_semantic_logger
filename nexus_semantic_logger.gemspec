# frozen_string_literal: true
require_relative 'lib/nexus_semantic_logger/version'

Gem::Specification.new do |spec|
  spec.name = "nexus_semantic_logger"
  spec.version = NexusSemanticLogger::VERSION
  spec.summary = "semantic_logger usage for nexus"
  spec.authors = ["Johnathon Harris"]
  spec.email = "john.harris@nexusmods.com"
  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    %x(git ls-files -z).split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']
  spec.add_dependency('amazing_print', '~> 1.4.0')
  spec.add_dependency('ddtrace', '~> 0.54.2') # For datadog tracing/profiling.
  spec.add_dependency('dogstatsd-ruby', '~> 5.4.0') # For custom application metrics.
  spec.add_dependency('google-protobuf', '~> 3.21.7')
  spec.add_dependency('net_tcp_client', '~> 2.2.0') # For TCP logging.
  spec.add_dependency('rails_semantic_logger', '~> 4.10.0')
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')
end
