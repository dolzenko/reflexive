require "sinatra/base"
require "sinatra/reloader" if ENV["SINATRA_RELOADER"]
require "sinatra_more/markup_plugin"

require "coderay"
require "ostruct"
require "open-uri"

require "reflexive/faster_open_struct"
require "reflexive/helpers"
require "reflexive/columnizer"
require "reflexive/constantize"
require "reflexive/descendants"
require "reflexive/methods"
require "reflexive/method_lookup"
require "reflexive/core_ext/reflexive_url"

if ENV["SINATRA_RELOADER"]
  require "rails/all"
  require "arel"
  require File.expand_path("../../../spec/integration_spec_fixture", __FILE__)

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

      def default_url_prefix
        "http://localhost:3000"
      end
    end

    set :public, self.root + "public"
    set :views, self.root + "views"

    def self.action(path, &block)
      get("/reflexive/#{ path }", &block)
    end

    before do
      if request.host == "reflexive-demo.heroku.com"
        response["Cache-Control"] = "max-age=10800, public" # 3 hours
      end
    end

    def e(message)
      @message = message
      erb :error
    end

    action "dashboard" do
      erb :dashboard
    end

    action "constant_lookup" do
      if (klass = Reflexive.constant_lookup(*params.values_at(:name, :scope))) &&
              (klass.instance_of?(Class) || klass.instance_of?(Module)) 
        redirect(constant_path(klass.to_s))
      else
        e "failed to lookup class/module with name `#{ params[:name] }' in scope #{ params[:scope] }"
      end
    end

    action "files/*" do |path|
      @path = "/" + path
      if File.stat(@path).directory?
        erb :directories_show
      else
        @source = highlight_file(@path)
        erb :files_show
      end
    end

    get "/reflexive/load_path_lookup" do
      path = params[:path]
      feature = Reflexive.loaded_features_lookup(path) || Reflexive.load_path_lookup(path)
      if feature
        redirect(file_path(feature))
      else
        e "failed to find feature: #{ path }"
      end
    end

    def definition_action(klass, level, name)
      find_klass(klass)
      @method_name = name
      @path, @line = @klass.send(level == :class ? :method : :instance_method, @method_name).source_location
      if @path.include?("(eval)")
        e "#{ name } #{ level } method was generated using `eval' function and can't be browsed"
      else
        @source = highlight_file(@path, :highlight_lines => [@line])
        erb :methods_definition
      end
    end

    get %r</reflexive/constants/([^/&#]+)/class_methods/([^/&#]+)/definition> do |klass, method|
      definition_action(klass, :class, method)
    end

    get %r</reflexive/constants/([^/&#]+)/instance_methods/([^/&#]+)/definition> do |klass, method|
      definition_action(klass, :instance, method)
    end

    get %r</reflexive/constants/([^/&#]+)/instance_methods/([^/&#]+)/apidock> do |klass, method|
      find_klass(klass)
      @method_name = method
      @level = :instance
      erb :methods_apidock
    end

    get %r</reflexive/constants/([^/&#]+)/class_methods/([^/&#]+)/apidock> do |klass, method|
      find_klass(klass)
      @method_name = method
      @level = :class
      erb :methods_apidock
    end

    def method_lookup_action(klass, level, name)
      lookup = MethodLookup.new(klass: klass, level: level, name: name)
      if definitions = lookup.definitions
        if definitions.size == 1
          redirect(new_method_definition_path(*definitions[0]) + "#highlighted")
        else
          @definitions, @klass, @level, @name, @last_resort_lookup_used =
                  definitions, klass, level, name, lookup.last_resort_lookup_used?
          erb :methods_choose
        end
      elsif documentations = lookup.documentations
        if documentations.size == 1
          redirect(method_documentation_path(*documentations[0]))
        else
          raise ArgumentError, "don't know how to handle multiple documentations"
        end
      else
        e "failed to find `#{ name }' #{ level } method for #{ klass }"
      end
      #
      # e "failed to find `#{ method }' instance method for #{ klass }"
    end

    get %r</reflexive/constants/([^/&#]+)/class_methods/([^/&#]+)> do |klass, method|
      find_klass(klass)
      method_lookup_action(@klass, :class, method)
    end

    get %r</reflexive/constants/([^/&#]+)/instance_methods/([^/&#]+)> do |klass, method|
      find_klass(klass)
      method_lookup_action(@klass, :instance, method)
    end

    get %r</reflexive/constants/([^/&#]+)> do |klass|
      find_klass(klass)

      exclude_trite = ![ BasicObject, Object ].include?(@klass)
      @methods = Reflexive::Methods.new(@klass, :exclude_trite => exclude_trite)

      ancestors_without_self_and_super = @klass.ancestors[2..-1] || []
      class_ancestors = ancestors_without_self_and_super.select { |ancestor| ancestor.class == Class }
      @class_ancestors = class_ancestors if class_ancestors.size > 0
      
      if @klass.respond_to?(:superclass) &&
          @klass.superclass != Object &&
          @klass.superclass != nil
        @superclass = @klass.superclass  
      end

      erb :constants_show
    end

    protected

    error(404) { @app.call(env) if @app }

    def find_klass(klass = params[:klass])
      @klass = Reflexive.constantize(klass) if klass 
    end
  end
end