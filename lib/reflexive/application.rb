require "sinatra/base"
require "sinatra_more/markup_plugin"

require "coderay"
require "ostruct"
require "open-uri"

require "looksee"
Looksee.styles.each { |k, _| Looksee.styles[k] = "%s" }

require "reflexive/faster_open_struct"
require "reflexive/helpers"
require "reflexive/columnizer"
require "reflexive/constantize"

module Reflexive
  class Application < Sinatra::Base
    register SinatraMore::MarkupPlugin
    include Reflexive::Helpers

    class << self
      def root
        require "pathname"
        Pathname("../../../").expand_path(__FILE__)
      end
    end

    set :public, self.root + "public"
    set :views, self.root + "views"

    get "/reflexive/constants/:klass/methods/:method/definition" do
      find_klass
      @method_name = params[:method]
      @path, @line = @klass.method(@method_name).source_location
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

    get "/reflexive/constants/:klass/methods/:method" do
      find_klass
      if @klass.method(params[:method]).source_location
        redirect(method_definition_path(params[:klass], params[:method]) +
                "#highlighted")
      else
        redirect(method_documentation_path(params[:klass], params[:method]))
      end
    end

    get "/reflexive/constants/:klass" do
      find_klass
      @methods = Faster::OpenStruct.new(:klass => Faster::OpenStruct.new,
                                        :instance => Faster::OpenStruct.new)

      %w(public protected private).each do |visibility|
        if (methods = @klass.send("#{ visibility }_methods").sort).present?
          @methods.klass.send("#{ visibility }=", methods)
        end

        if (methods = @klass.send("#{ visibility }_instance_methods").sort).present?
          @methods.instance.send("#{ visibility }=", methods)
        end
      end

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