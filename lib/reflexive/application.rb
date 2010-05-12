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

if ENV["SINATRA_RELOADER"]
  require "rails/all"
  require "arel"

  module ::Kernel
    def r(*args)
      raise((args.size == 1 ? args[0] : args).inspect)
    end
  end
end

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

    set :public, self.root + "public"
    set :views, self.root + "views"

    def get(path, &block)
      super("/reflexive/#{ path }", &block)
    end

    get "dashboard" do
      erb :dashboard
    end

    get "constant_lookup" do
      name = params[:name]
      scope = eval(params[:scope])
      if scope && name !~ /^::/
        begin
          name_with_scope = "#{ scope.join("::") }::#{ name }"
          klass = Reflexive.constantize(name_with_scope)
          redirect(constant_path(klass.name))
        rescue NameError, ArgumentError
          # For defined top-level module, when looked up from another class:
          # ArgumentError: Object is not missing constant Taggable!
          #        from /usr/local/rvm/gems/ruby-1.9.2-head@selfport/gems/activesupport-2.3.5/lib/active_support/dependencies.rb:417:in `load_missing_constant'
          retry if scope.pop
        end
        "Failed to lookup constant: #{ params.inspect }"
      else
        redirect(constant_path(name))
      end
    end

    get "files/*" do |path|
      @path = "/" + path
      if File.stat(@path).directory?
        erb :directories_show
      else
        @source = highlight_file(@path)
        erb :files_show
      end
    end

    get "constants/:klass/class_methods/:method/definition" do
      find_klass
      @method_name = params[:method]
      @path, @line = @klass.method(@method_name).source_location
      @source = highlight_file(@path, :highlight_lines => [@line])
      erb :methods_definition
    end

    get "constants/:klass/instance_methods/:method/definition" do
      find_klass
      @method_name = params[:method]
      @path, @line = @klass.instance_method(@method_name).source_location
      @source = highlight_file(@path, :highlight_lines => [@line])
      erb :methods_definition
    end

    get "/reflexive/constants/:klass/methods/:method/apidock" do
      find_klass
      @method_name = params[:method]
      erb :methods_apidock
    end

    get "constants/:klass/class_methods/:method" do
      find_klass
      if @klass.method(params[:method]).source_location
        redirect(class_method_definition_path(params[:klass], params[:method]) +
                "#highlighted")
      else
        redirect(method_documentation_path(params[:klass], params[:method]))
      end
    end

    get "constants/:klass/instance_methods/:method" do
      find_klass
      if @klass.instance_method(params[:method]).source_location
        redirect(instance_method_definition_path(params[:klass], params[:method]) +
                "#highlighted")
      else
        redirect(method_documentation_path(params[:klass], params[:method]))
      end
    end

    get "constants/:klass" do
      # r Class.constants
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

    def find_klass
      @klass = Reflexive.constantize(params[:klass]) if params[:klass]
    end
  end
end