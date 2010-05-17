Gem::Specification.new do |s|
  s.name        = "reflexive"
  s.version     = ENV["GEM_VERSION"].dup || "0.0.1"
  s.authors     = ["Evgeniy Dolzhenko"]
  s.email       = ["dolzenko@gmail.com"]
  s.homepage    = "http://github.com/dolzenko/reflexive"
  s.summary     = "Reflexive"

  s.files       = Dir.glob("{lib,public,views,spec}/**/*") + %w(reflexive.gemspec)

  s.required_ruby_version = '>= 1.9.1'

  # keeping this in sync with Gemfile manually
  s.add_dependency "rack"
  s.add_dependency "sinatra"
  s.add_dependency "sinatra_more"
  s.add_dependency "coderay"
  s.add_dependency "rdiscount"

  s.add_development_dependency "rails", "3.0.0.beta3"
  s.add_development_dependency "rspec", "2.0.0.beta.8"
  s.add_development_dependency "sinatra-reloader"
end