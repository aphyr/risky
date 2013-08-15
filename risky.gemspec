# -*- encoding: utf-8 -*-
require File.expand_path('../lib/risky/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Kyle Kingsbury"]
  gem.email         = ["aphyr@aphyr.com"]
  gem.description   = %q{A lightweight Ruby ORM for Riak.}
  gem.summary       = %q{A Ruby ORM for the Riak distributed database.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "risky"
  gem.require_paths = ["lib"]
  gem.version       = Risky::VERSION

  gem.add_dependency "riak-client", "~> 1.2.0"
  gem.add_development_dependency "rspec"
end
