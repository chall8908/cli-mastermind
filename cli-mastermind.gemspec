lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cli/mastermind/version"

Gem::Specification.new do |spec|
  spec.name          = "cli-mastermind"
  spec.version       = CLI::Mastermind.gem_version
  spec.authors       = ["Chris Hall"]
  spec.email         = ["chall8908@gmail.com"]

  spec.summary       = "Mastermind is a library for constructing command line toolboxes."
  spec.description   = <<-DESC
                         Take over the world from your command line!
                         With mastermind, you can quickly build and generate
                         command line toolkits without having to custom build
                         everything for every project.
                       DESC
  spec.homepage      = "https://github.com/chall8908/cli-mastermind"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "cli-ui", "~> 1.2", ">= 1.2.1"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rspec", "~> 3.0"
end
