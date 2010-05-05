module Reflexive
  module Helpers
    def shorten_file_path(path)
      require "rbconfig"
      path.
        gsub(/\A#{ Regexp.escape(Gem.dir) }/, '#{ Gem.dir }').
        gsub(/\A#{ Config::CONFIG["rubylibdir"] }/, '#{ rubylibdir }')
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

    def link_to_method(constant, method_name, visibility)
      link_text = truncate(method_name)
      link_to(Rack::Utils.escape_html(link_text),
              method_path(constant, method_name),
              :title => (method_name if link_text.include?("...")))
    end

    def constant_path(constant)
      "/constants/#{ constant }"
    end

    def method_path(constant, method_name)
      "/reflexive/constants/#{ constant }/methods/#{ Rack::Utils.escape method_name }"
    end

    def apidock_path(constant, method_name)
      "http://apidock.com/ruby/#{ constant }/#{ Rack::Utils.escape method_name }"
    end

    def method_definition_path(constant, method_name)
      method_path(constant, method_name) + "/definition"
    end

    def method_documentation_path(constant, method_name)
      method_path(constant, method_name) + "/apidock"
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