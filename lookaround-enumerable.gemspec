
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lookaround-enumerable"

Gem::Specification.new do |spec|
  spec.name          = "lookaround-enumerable"
  spec.version       = LookaroundEnum::VERSION
  spec.authors       = ["Patrick Plenefisch"]
  spec.email         = ["simonpatp@gmail.com"]

  spec.summary       = %q{Look around at  neighbor elements in Enumerable methods}
  spec.description   = %q{Lookaround Enumerable allows acccessing previous and upcoming elements in Enumerable methods, so that computations can depend on a window of values. Particularly useful for dragged state, time series, and other semi-stateful computations.}
  spec.homepage      = "https://github.com/byteit101/lookaround-enumerable"
  spec.license       = "BSD-3-Clause"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = spec.homepage
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  spec.files         = [".rspec", "Gemfile", "README.md", "Rakefile", "lib/lookaround-enumerable.rb", "lookaround-enumerable.gemspec"]

  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
