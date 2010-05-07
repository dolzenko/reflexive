require File.expand_path("../lib/reflexive/application", __FILE__)

set :app_file, File.expand_path("../lib/reflexive/application", __FILE__)
set :public, File.expand_path("../public", __FILE__)
set :views, File.expand_path("../views", __FILE__)
set :env, :production
disable :run, :reload

run Reflexive::Application