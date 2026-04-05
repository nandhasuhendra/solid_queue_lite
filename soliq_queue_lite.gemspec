require_relative "lib/soliq_queue_lite/version"

Gem::Specification.new do |spec|
  spec.name        = "soliq_queue_lite"
  spec.version     = SoliqQueueLite::VERSION
  spec.authors     = [ "Nanda Suhendra" ]
  spec.email       = [ "nandhasuhendra@gmail.com" ]
  spec.summary     = "A lightweight, zero-build dashboard for Solid Queue."
  spec.description = "Sidekiq-style operational visibility and telemetry without the asset pipeline baggage or database locking."
  spec.homepage    = "https://github.com/nandhasuhendra/soliq_queue_lite"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] =  "https://github.com/nandhasuhendra/soliq_queue_lite"
  spec.metadata["changelog_uri"] = "https://github.com/nandhasuhendra/soliq_queue_lite/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.1.0"
  spec.add_dependency "solid_queue", ">= 1.0"
end
