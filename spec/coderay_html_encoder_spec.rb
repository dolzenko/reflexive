require "reflexive/coderay_html_encoder"

describe Reflexive::CodeRayHtmlEncoder do
  it "emits links for :constant tokens" do
    encoder = Reflexive::CodeRayHtmlEncoder.new(:wrap => :div, :css => :style)
    encoder.encode_tokens([["Cons", :constant]]).should include("<a href")
  end

  it "emits links with proper nesting info" do
    require "cgi" unless defined?(CGI) && defined?(CGI::escape)
    
    encoder = Reflexive::CodeRayHtmlEncoder.new(:wrap => :div, :css => :style)
    scope = ["Asd", "Qwe::Zxc"]
    tokens = [["Cons", :constant, :scope => scope]]
    esc_scope = CGI.escape(scope.inspect)
    
    encoder.encode_tokens(tokens).should include("?name=Cons&scope=#{ esc_scope }")
  end
end