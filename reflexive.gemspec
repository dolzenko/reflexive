Gem::Specification.new do |s|
  s.name        = "reflexive"
  s.version     = ENV["GEM_VERSION"].dup || "0.0.1"
  s.authors     = ["Evgeniy Dolzhenko"]
  s.email       = ["dolzenko@gmail.com"]
  s.homepage    = "http://github.com/dolzenko/reflexive"
  s.summary     = "Reflexive"

  s.files       = Dir.glob("{lib,public,views}/**/*") +
                    Dir.glob("spec/*.rb") +
                    %w(reflexive.gemspec Rakefile Gemfile config.ru)

  s.required_ruby_version = '>= 1.9.1'

  # keeping this in sync with Gemfile manually
  s.add_dependency "rack", "1.1.0"
  s.add_dependency "sinatra", "1.0"
  s.add_dependency "sinatra_more", "0.3.40"
  s.add_dependency "coderay", "0.9.3"
  #  s.add_dependency "rdiscount"

  s.add_development_dependency "rails", "3.0.0.beta3"
  s.add_development_dependency "rspec", "2.0.0.beta.8"
  s.add_development_dependency "sinatra-reloader", "0.4.1"
  s.add_development_dependency "thin", "1.2.7"
  s.add_development_dependency "rack-test", "0.5.3"
  s.add_development_dependency "webrat", "0.7.1"
end