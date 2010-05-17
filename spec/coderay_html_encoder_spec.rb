require "reflexive/coderay_html_encoder"

describe Reflexive::CodeRayHtmlEncoder do
  def encoder
    Reflexive::CodeRayHtmlEncoder.new(:wrap => :div, :css => :style)
  end
  
  it "emits links for :constant tokens" do
    encoder = Reflexive::CodeRayHtmlEncoder.new(:wrap => :div, :css => :style)
    encoder.encode_tokens([["Cons", :constant,
                            {:constant_access=>{:name=>"Cons", :scope=>[]}}]]).should(include("<a href"))
  end

  it "emits links with proper nesting info" do
    tokens = [["Cons", :constant,
               {:constant_access=>{:name=>"Cons", :scope=>["A", "B"]}}]]
    
    encoder.encode_tokens(tokens).should include("constant_lookup?name=Cons&scope=A%3A%3AB")
  end

  it "emits load_path links" do
    tokens = [["f", :content, { :load_path => true }]]
    encoder.encode_tokens(tokens).should include("?path=f")
  end

  it "emits class method links" do
    tokens = [ [
                  "m!", :ident,
                  {:method_call=>{:name=>"m!", :receiver=>["A"]} }
             ] ]
    encoder.encode_tokens(tokens).should include("/constants/A/class_methods/m%21")
  end

  it "emits instance method links" do
    tokens = [ [
                  "m!", :ident,
                  {:method_call=>{:name=>"m!", :receiver=>["A", :instance]} }
             ] ]
    encoder.encode_tokens(tokens).should include("/constants/A/instance_methods/m%21")
  end

  it "emits variable assignment id" do
    tokens = [ [
                  "a", :ident,
                  {:local_variable_assignment=>"1:a"}
             ] ]
    encoder.encode_tokens(tokens).should include("span id='lv:1:a'")
  end

  it "emits variable access links" do
    tokens = [ [
                  "a", :ident,
                  {:local_variable_access=>"1:a"}
             ] ]
    encoder.encode_tokens(tokens).should include("href='#lv:1:a'")
  end
end