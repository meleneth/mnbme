# frozen_string_literal: true

require_relative "lib/mel/mnbme/version"

Gem::Specification.new do |spec|
  spec.name = "mel-mnbme"
  spec.version = Mel::MNBME::VERSION
  spec.authors = ["Meleneth"]
  spec.email = ["meleneth@gmail.com"]

  spec.summary = "Make Number Bigger: Microservices Edition"
  spec.description = "This is shared backend code to share code among services"
  spec.homepage = "https://github.com/meleneth/mnbme"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://none"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/meleneth/mnbme"
  spec.metadata["changelog_uri"] = "https://github.com/meleneth/mnbme/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir['lib/**/*']
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
