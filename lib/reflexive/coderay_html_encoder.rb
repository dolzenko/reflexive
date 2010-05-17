require "reflexive/routing_helpers"

require "coderay"
require "coderay/encoder"
require "coderay/encoders/html"

module Reflexive
  class CodeRayHtmlEncoder < ::CodeRay::Encoders::HTML
    include RoutingHelpers
    
    def token(text, type = :plain, tags = {})
      if constant_access = tags[:constant_access]
        name, scope = constant_access.values_at(:name, :scope)
        @out << "<a href='#{ constant_lookup_path(name, scope) }'>"
        super(text, type)
        @out << "</a>"
      elsif type == :meta_scope
        # pass
      elsif type == :content && tags[:load_path]
        @out << "<a href='#{ load_path_lookup_path(text) }'>"
        super(text, type)
        @out << "</a>"
      elsif method_call = tags[:method_call]
        @out << "<a href='#{ method_call_path(method_call) }'>"
        super(text, type)
        @out << "</a>"
      elsif local_variable_assignment = tags[:local_variable_assignment]
        @out << "<span id='lv:#{ local_variable_assignment }'>"
        super(text, type)
        @out << "</span>"
      elsif local_variable_access = tags[:local_variable_access]
        @out << "<a href='#lv:#{ local_variable_access }' class='lva'>"
        super(text, type)
        @out << "</a>"
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