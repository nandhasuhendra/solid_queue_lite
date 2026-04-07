require_relative "lib/solid_queue_lite/version"

Gem::Specification.new do |spec|
  spec.name        = "solid_queue_lite"
  spec.version     = SolidQueueLite::VERSION
  spec.authors     = [ "Nanda Suhendra" ]
  spec.email       = [ "nandhasuhendra@gmail.com" ]
  spec.summary     = "A lightweight, zero-build dashboard for Solid Queue."
  spec.description = "Sidekiq-style operational visibility and telemetry without the asset pipeline baggage or database locking."
  spec.homepage    = "https://github.com/nandhasuhendra/solid_queue_lite"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/nandhasuhendra/solid_queue_lite/tree/main"
  spec.metadata["changelog_uri"]     = "https://github.com/nandhasuhendra/solid_queue_lite/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/nandhasuhendra/solid_queue_lite#readme"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/nandhasuhendra/solid_queue_lite/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "CHANGELOG.md", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 7.1", ">= 7.1.0"
  spec.add_dependency "solid_queue", "~> 1.0", ">= 1.0"
end
