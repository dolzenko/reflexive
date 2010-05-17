$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

desc "Run specs (without Rails integration spec - requires rvm, run manually with `spec ./spec/rails_integration_spec.rb')"
task :spec do
  sh "spec #{ (Dir["./spec/*_spec.rb"] - ["./spec/rails_integration_spec.rb"]).join(" ") }"
end

GEM_NAME = "reflexive"

desc "Relese next version of reflexive gem (do that just after `git commit')"
task :release do
  require "rubygems"
  require "rubygems/version"
  require "yaml"

  current_version = YAML.load(`gem specification #{ GEM_NAME } -r`)["version"] || Gem::Version.new("0.0.0")
  new_version = (current_version.segments[0..-2] + [current_version.segments[-1].succ]).join(".")
  ENV["GEM_VERSION"] = new_version

  puts "Releasing #{ GEM_NAME } #{ new_version }"

  sh "gem build #{ GEM_NAME }.gemspec --verbose"

  sh "gem push #{ GEM_NAME }-#{ new_version }.gem --verbose"

  sh "gem install #{ GEM_NAME } --version=#{ new_version } --local --verbose"

  File.delete("#{ GEM_NAME }-#{ new_version }.gem")
  
  sh "git push"
end

task :default => :spec
