begin
  # Require the preresolved locked set of gems.
  require ::File.expand_path('../.bundle/environment', __FILE__)
rescue LoadError
  # Fallback on doing the resolve at runtime.
  require "rubygems"
  require "bundler"
  Bundler.setup
end

require "sinatra/base"
require "sinatra/reloader" if ENV["SINATRA_RELOADER"]
require "sinatra_more/markup_plugin"

require "coderay"
require "andand"
require "ostruct"
require "open-uri"

require "looksee"
Looksee.styles.each { |k, _| Looksee.styles[k] = "%s" }

require "reflexive/faster_open_struct"
require "reflexive/helpers"
require "reflexive/columnizer"
require "reflexive/constantize"
require "reflexive/descendants"
require "reflexive/methods"

require "rails/all" if ENV["SINATRA_RELOADER"]

module Reflexive
  class Application < Sinatra::Base
    register SinatraMore::MarkupPlugin
    include Reflexive::Helpers

    configure(:development) do
      if ENV["SINATRA_RELOADER"]
        register Sinatra::Reloader
        also_reload "lib/**/*.rb"
      end
    end    

    class << self
      def root
        require "pathname"
        Pathname("../../../").expand_path(__FILE__)
      end
    end

    set :app_file, __FILE__    
    set :public, self.root + "public"
    set :views, self.root + "views"

    get "/reflexive/dashboard" do
      erb :dashboard
    end

    get "/reflexive/files/*" do |path|
      @path = "/" + path
      if File.stat(@path).directory?
        erb :directories_show
      else
        @source = CodeRay.highlight_file(@path,
                                         :line_numbers => :inline,
                                         :css => :class)
        erb :files_show
      end
    end

    get "/reflexive/constants/:klass/class_methods/:method/definition" do
      find_klass
      @method_name = params[:method]
      @path, @line = @klass.method(@method_name).source_location
      @source = CodeRay.highlight_file(@path,
                                       :line_numbers => :inline,
                                       :css => :class,
                                       :highlight_lines => [@line])
      erb :methods_definition
    end

    get "/reflexive/constants/:klass/instance_methods/:method/definition" do
      find_klass
      @method_name = params[:method]
      @path, @line = @klass.instance_method(@method_name).source_location
      @source = CodeRay.highlight_file(@path,
                                       :line_numbers => :inline,
                                       :css => :class,
                                       :highlight_lines => [@line])
      erb :methods_definition
    end

    get "/reflexive/constants/:klass/methods/:method/apidock" do
      find_klass
      @method_name = params[:method]
      erb :methods_apidock
    end

    get "/reflexive/constants/:klass/class_methods/:method" do
      find_klass
      if @klass.method(params[:method]).source_location
        redirect(class_method_definition_path(params[:klass], params[:method]) +
                "#highlighted")
      else
        redirect(method_documentation_path(params[:klass], params[:method]))
      end
    end

    get "/reflexive/constants/:klass/instance_methods/:method" do
      find_klass
      if @klass.instance_method(params[:method]).source_location
        redirect(instance_method_definition_path(params[:klass], params[:method]) +
                "#highlighted")
      else
        redirect(method_documentation_path(params[:klass], params[:method]))
      end
    end

    get "/reflexive/constants/:klass" do
      find_klass
      @methods = Reflexive::Methods.new(@klass)
      #      @methods = Faster::OpenStruct.new(:klass => Faster::OpenStruct.new,
      #                                        :instance => Faster::OpenStruct.new)
      #
      #      %w(public protected private).each do |visibility|
      #        if (methods = @klass.send("#{ visibility }_methods").sort).present?
      #          @methods.klass.send("#{ visibility }=", methods)
      #        end
      #
      #        if (methods = @klass.send("#{ visibility }_instance_methods").sort).present?
      #          @methods.instance.send("#{ visibility }=", methods)
      #        end
      #      end
      #
      erb :constants_show
    end

    protected

    error(404) { @app.call(env) if @app }

    def r(*args)
      raise((args.size == 1 ? args[0] : args).inspect)
    end

    def find_klass
      @klass = Reflexive.constantize(params[:klass]) if params[:klass]
    end
  end
end