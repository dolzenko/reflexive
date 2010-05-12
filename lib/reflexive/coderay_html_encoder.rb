require "reflexive/routing_helpers"

require "coderay"
require "coderay/encoder"
require "coderay/encoders/html"

module Reflexive
  class CodeRayHtmlEncoder < ::CodeRay::Encoders::HTML
    require "cgi" unless defined?(CGI) && defined?(CGI::escape)

    include RoutingHelpers
    
    def token(text, type = :plain, tags = {})
      if type == :constant
        @out << "<a href='#{ constant_lookup_path(text, tags[:scope]) }'>"
        super(text, type)
        @out << "</a>"
      elsif type == :meta_scope
        # pass
      else
        super(text, type) rescue raise([text, type].inspect)
      end
    end

    def compile(tokens, options)
      for token in tokens
        token(*token)
      end
    end
  end
end