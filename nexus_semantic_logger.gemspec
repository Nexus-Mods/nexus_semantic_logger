Gem::Specification.new do |spec|
  spec.name        = "nexus_semantic_logger"
  spec.version     = "1.0.0"
  spec.summary     = "semantic_logger usage for nexus"
  spec.authors     = ["Johnathon Harris"]
  spec.email       = "john.harris@nexusmods.com"
  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    %x(git ls-files -z).split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
end

