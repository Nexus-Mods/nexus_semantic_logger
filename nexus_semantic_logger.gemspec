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
  spec.add_dependency('datadog', '~> 2.24') # For datadog tracing/profiling.
  spec.add_dependency('dogstatsd-ruby', '~> 5.7') # For custom application metrics.
  spec.add_dependency('google-protobuf', '>= 3.25.5') # 3.25.x doesn't support ruby >= 3.4; allow 4.x too.
  spec.add_dependency('net_tcp_client', '~> 2.2.0') # For TCP logging.
  # Wide on purpose. Rails 8.1 needs rails_semantic_logger 5.x, older Rails
  # resolves 4.x because 5.x requires railties >= 7.2.
  spec.add_dependency('rails_semantic_logger', '>= 4.17', '< 6')
  spec.add_dependency('semantic_logger', '>= 4.16.1', '< 6')
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')
end
