require "reflexive/routing_helpers"
require "reflexive/coderay_ruby_scanner"
require "reflexive/coderay_html_encoder"

module Reflexive
  def self.class_reloading_active?
    if defined?(Rails)
      !Rails.configuration.cache_classes rescue false
    else
      false
    end
  end

  FILE_EXT = /\.\w+\z/
  DL_EXT = /\.s?o\z/
  def self.load_path_lookup(path)
    path_with_rb_ext = path.sub(FILE_EXT, "") + ".rb"

    $LOAD_PATH.each do |load_path|
      if feature = File.join(load_path, path_with_rb_ext)
        return feature if File.exists?(feature)
      end
    end

    nil
  end

  def self.loaded_features_lookup(path)
    path_without_ext = path.sub(FILE_EXT, "")

    $LOADED_FEATURES.reverse.reject do |feature|
      feature =~ DL_EXT
    end.detect do |feature|
      feature_without_ext = feature.sub(FILE_EXT, "")

      feature_without_ext =~ /\/#{ Regexp.escape(path_without_ext) }\z/
    end    
  end

  module Helpers
    include RoutingHelpers

    def filter_existing_constants(constants)
      constants.
              select { |c| Kernel.const_defined?(c) }.
              map { |c| Kernel.const_get(c) }
    end

    CODERAY_ENCODER_OPTIONS = {
      :wrap => :div,
      :css => :class,
      :line_numbers => :inline
    }.freeze

    def highlight_file(path, options = {})
      options = CODERAY_ENCODER_OPTIONS.merge(options)
      if path =~ /\.rb$/
        src = IO.read(path)
        tokens = CodeRayRubyScanner.new(src).tokenize
        encoder = CodeRayHtmlEncoder.new(options)
        encoder.encode_tokens(tokens)
#      elsif path =~ /\.(markdown|md)$/
#        require "rdiscount"
#        src = IO.read(path)
#        markdown = RDiscount.new(src)
#        markdown.to_html
      else
        CodeRay.scan_file(path).html(options).div
      end
    end    
    
    def constant_name(klass)
      klass.name || klass.to_s
    end

    def link_to_file(path, options = {})
      link_text = if options[:file_name_only]
        File.basename(path) + (path[-1] == ?/ ? "/" : "")
      else
        shorten_file_path(path)
      end

      link_to(link_text,
              file_path(path),
              :title => path,
              :class => "path")
    end

    def shorten_file_path(path)
      require "rbconfig"
      path.
        gsub(/\A#{ Regexp.escape(Gem.dir) }\/gems/, '#{gems}').
        gsub(/\A#{ Config::CONFIG["rubylibdir"] }/, '#{rubylib}')
    end

    def load_and_highlight(location)
      tokens = CodeRay.scan(IO.read(location), :ruby)

      tokens.html(:line_numbers => :inline, :wrap => :page)
    end

    def methods_table(constant, lookup_path)
      linked_methods = lookup_path.map do |name, visibility|
        link_to_method(lookup_path.module_name.gsub(/\[|\]/, ""),
                       name,
                       visibility)
      end

      Reflexive::Columnizer.columnize(linked_methods, 120)
    end

    def new_methods_table(constant, level, methods)
      linked_methods = methods.sort.map do |name|
        new_link_to_method(constant, level, name)
      end
      Reflexive::Columnizer.columnize(linked_methods, 120)
    end

    def constants_table(base_constant, constants, width = 120)
      Reflexive::Columnizer.columnize(constants_links(base_constant, constants), width)
    end

    def constants_list(base_constant, constants)
      constants_links(base_constant, constants).join("<br/>")
    end

    def constants_links(base_constant, constants)
      constants.map do |constant|
        full_name = constant_name(constant)
        [ full_name, constant ]
      end.sort_by(&:first).map do |full_name, constant|
        link_text = full_name.gsub("#{ base_constant }::", "")
        link_to(link_text, constant_path(constant), :title => full_name)
      end      
    end

    def instance_methods_table(lookup_path)
      linked_methods = []

      %w(public protected private).each do |visibility|
        methods = lookup_path.module.send("#{ visibility }_instance_methods", false)
        
        linked_methods += methods.map do |name|
          link_to_method(lookup_path.module_name.gsub(/\[|\]/, ""),
                         name,
                         visibility)
        end
      end

      Reflexive::Columnizer.columnize(linked_methods, 120)
    end

    def just_methods_table(klass)
      linked_methods = []

      ancestors_with_methods = ActiveRecord::Base.ancestors.map do |a|
        [a, a.methods(false).sort] unless a.methods(false).empty?
      end.compact

      ancestors_with_methods.each do |ancestor, ancestor_methods|
        linked_methods += ancestor_methods.map do |name|
          link_to_method(ancestor.name, name)
        end
      end
      
      Reflexive::Columnizer.columnize(linked_methods, 120)
    end

    def link_to_method(constant, method_name, visibility = nil)
      link_text = truncate(method_name)
      link_to(Rack::Utils.escape_html(link_text),
              method_path(constant, method_name),
              :title => (method_name if link_text.include?("...")))
    end

    def new_link_to_method(constant, level, method_name)
      link_text = truncate(method_name)
      link_to(Rack::Utils.escape_html(link_text),
              new_method_path(constant, level, method_name),
              :title => (method_name if link_text.include?("...")))
    end

    def full_name_link_to_method(constant, level, method_name)
      link_text = "#{ constant }#{ level == :instance ? "#" : "." }#{ method_name }"
      link_to(Rack::Utils.escape_html(link_text),
              new_method_path(constant, level, method_name))
    end

    ##
    # Truncates a given text after a given :length if text is longer than :length (defaults to 30).
    # The last characters will be replaced with the :omission (defaults to "в_│") for a total length not exceeding :length.
    #
    # ==== Examples
    #
    #   truncate("Once upon a time in a world far far away", :length => 8) => "Once upon..."
    #
    def truncate(text, options={})
      options.reverse_merge!(:length => 30, :omission => "...")
      if text
        len = options[:length] - options[:omission].length
        chars = text
        (chars.length > options[:length] ? chars[0...len] + options[:omission] : text).to_s
      end
    end
  end
end