Gem::Specification.new do |s|
  s.name        = "reflexive"
  s.version     = ENV["GEM_VERSION"].dup || "0.0.1"
  s.authors     = ["Evgeniy Dolzhenko"]
  s.email       = ["dolzenko@gmail.com"]
  s.homepage    = "http://github.com/dolzenko/reflexive"
  s.summary     = "Reflexive"
  s.files       = Dir.glob("{lib,public,views}/**/*") + %w(reflexive.gemspec)
  s.add_dependency("rack")
  s.add_dependency("sinatra")
  s.add_dependency("sinatra_more")
  s.add_dependency("coderay")
  s.add_dependency("looksee")
end