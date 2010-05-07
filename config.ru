require "sinatra/base"
require File.expand_path("../lib/reflexive/application", __FILE__)

run Reflexive::Application
