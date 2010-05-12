require "reflexive/coderay_ruby_scanner"
require "coderay/scanners/ruby"

describe Reflexive::CodeRayRubyScanner do
  def reflexive_tokens(src)
    Reflexive::CodeRayRubyScanner.new(src).tokenize
  end

  def reflexive_tokens_without_meta_and_tags(src)
    Reflexive::CodeRayRubyScanner.new(src).tokenize.
            reject { |t| t[1] == :meta_scope }.
            map { |t| t[2].is_a?(Hash) ? t[0..1] : t }
  end

  def coderay_tokens(src)
    squeezed_tokes = []
    ::CodeRay::Scanners::Ruby.new(src).tokenize.each do |token|
      if squeezed_tokes.size > 0 &&
              squeezed_tokes[-1][1] == token[1]
        squeezed_tokes[-1][0] << token[0]
      else
        squeezed_tokes << token
      end
    end
  end

  it "squeezes constants" do
    src = <<-RUBY
      class ConstRef < Const::PathRef
        RefenceConstInClassBody = ::TopConstRef
        def m
          Const::PathRef
        end
      end

      class Const::PathRef < ::TopConstRef
        def self.m
          reference_in_method_body ::TopConstRef
        end
      end

      class ::TopConstRef
      end

      class Const::Deeply::Nested::PathRef < ConstRef
      end
    RUBY
    tokens = reflexive_tokens(src)
    tokens.should include(["ConstRef", :constant, { :scope => nil }])
    tokens.should include(["Const::PathRef", :constant, { :scope => ["ConstRef"] }])
    tokens.should include(["Const::PathRef", :constant, { :scope => nil }])
    tokens.should include(["::TopConstRef", :constant, { :scope => nil }])
    tokens.should include(["::TopConstRef", :constant, { :scope => ["Const::PathRef"] }])
    tokens.should include(["Const::Deeply::Nested::PathRef", :constant, { :scope => nil }])
  end

  ONE_LINERS = <<-RUBY.gsub(/^ */, "")
    %Q{str}
    %r<regexp>
    :symbol
    :@instance_var_symbol
    :@@class_var_symbol
    :$global_var_symbol
    :ConstantSymbol
    :+
    :if
    #!/usr/bin/env ruby
    %q[haha! [nesting [rocks] ] ! ]
    %Q[hehe! \#{ %Q]nesting \#{"really"} rocks] } ! ]
    some_string.to_i /\\s+/
    S = 'bla' * 100 + "\n" + "\t"*4
    :"\#{undef :blubb}\#@@cv"
    undef :"bla", /, :"\#{undef :blubb}\#@@cv"
    @hash.delete_if { |o,| yield(o) }
    "double quoted string"
    # comment
    "a \#{ b + "c"}"
    42 if true
    /regexp with modifiers/xm
    a = ?s
    q = "\\n"
    call_something()
    a = 1 && 2 || 3
    @ivar = 123
    @@cvar = 345
    $gvar = 345
    float = 1.2345
    `shell`
    v = %w(w1 w2)
    "a\#{" b \#{@c} d" if @c} d \#{@e}; f."
  RUBY

  #  ONE_LINERS.split("\n").each do |src|
  #    it "should parse `#{ src }' just as CodeRay parser does" do
  #      reflexive_tokens(src).should == coderay_tokens(src)
  #    end
  #  end


  it "generates CodeRay compatible token stream" do
    src = <<-RUBY.gsub(/^ */, "")
      #{ ONE_LINERS }
      [].each do |*args, &block|
        self.class.define_method do
        end
      end
      class Qwe < Asd
        alias qwe asd
        module Sdf
          def self.sm
          end
        end
      end
      =begin
        heredoc1
      =end
      <<-QWE
      QWE
      if 1 > 0
      elsif false
      end
      begin
        42
      rescue Exception => e
        [] << 'q'
      end
      def `(cmd)
      end
    RUBY
    expected_tokens = [
    [:open, :string], ["%Q{", :delimiter], ["str", :content], ["}", :delimiter], [:close, :string], ["\n", :space],
    [:open, :regexp], ["%r<", :delimiter], ["regexp", :content], [">", :delimiter], [:close, :regexp], ["\n", :space],
    [:open, :symbol], [":", :delimiter], ["symbol", :content], [:close, :symbol], ["\n", :space],
    [:open, :symbol], [":", :delimiter], ["@instance_var_symbol", :content], [:close, :symbol], ["\n", :space],
    [:open, :symbol], [":", :delimiter], ["@@class_var_symbol", :content], [:close, :symbol], ["\n", :space],
    [:open, :symbol], [":", :delimiter], ["$global_var_symbol", :content], [:close, :symbol], ["\n", :space],
    [:open, :symbol], [":", :delimiter], ["ConstantSymbol", :content], [:close, :symbol], ["\n", :space],
    [:open, :symbol], [":", :delimiter], ["+", :content], [:close, :symbol], ["\n", :space],
    [:open, :symbol], [":", :delimiter], ["if", :content], [:close, :symbol], ["\n", :space],
    ["#!/usr/bin/env ruby\n", :comment], [:open, :string], ["%q[", :delimiter], ["haha! [nesting [rocks] ] ! ", :content], ["]", :delimiter], [:close, :string], ["\n", :space],
    [:open, :string], ["%Q[", :delimiter], ["hehe! ", :content], [:open, :inline], ["\#{", :inline_delimiter], [" ", :space], [:open, :string], ["%Q]", :delimiter], ["nesting ", :content], [:open, :inline], ["\#{", :inline_delimiter], [:open, :string], ["\"", :delimiter], ["really", :content], ["\"", :delimiter], [:close, :string], ["}", :inline_delimiter], [:close, :inline], [" rocks", :content], ["]", :delimiter], [:close, :string], [" ", :space], ["}", :inline_delimiter], [:close, :inline], [" ! ", :content], ["]", :delimiter], [:close, :string], ["\n", :space],
    ["some_string", :ident], [".", :operator], ["to_i", :ident], [" ", :space], [:open, :regexp], ["/", :delimiter], ["\\s+", :content], ["/", :delimiter], [:close, :regexp], ["\n", :space],
    ["S", :constant], [" ", :space], ["=", :operator], [" ", :space], [:open, :string], ["'", :delimiter], ["bla", :content], ["'", :delimiter], [:close, :string], [" ", :space], ["*", :operator], [" ", :space], ["100", :integer], [" ", :space], ["+", :operator], [" ", :space], [:open, :string], ["\"", :delimiter], ["\n", :content], ["\"", :delimiter], [:close, :string], [" ", :space], ["+", :operator], [" ", :space], [:open, :string], ["\"", :delimiter], ["\t", :content], ["\"", :delimiter], [:close, :string], ["*", :operator], ["4", :integer], ["\n", :space],
    [:open, :symbol], [":\"", :delimiter], [:open, :inline], ["\#{", :inline_delimiter], ["undef", :content], [:close, :symbol], [" ", :space], [:open, :symbol], [":", :delimiter], ["blubb", :content], [:close, :symbol], ["}", :inline_delimiter], [:close, :inline], ["#", :escape], ["@@cv", :class_variable], ["\"", :delimiter], [:close, :string], ["\n", :space],
    ["undef", :reserved], [" ", :space], [:open, :symbol], [":\"", :delimiter], ["bla", :content], ["\"", :delimiter], [:close, :symbol], [",", :operator], [" ", :space], ["/,", :operator], [" ", :space], [:open, :symbol], [":\"", :delimiter], [:open, :inline], ["\#{", :inline_delimiter], ["undef", :content], [:close, :symbol], [" ", :space], [:open, :symbol], [":", :delimiter], ["blubb", :content], [:close, :symbol], ["}", :inline_delimiter], [:close, :inline], ["#", :escape], ["@@cv", :class_variable], ["\"", :delimiter], [:close, :string], ["\n", :space],
    ["@hash", :instance_variable], [".", :operator], ["delete_if", :ident], [" ", :space], ["{", :operator], [" ", :space], ["|", :operator], ["o", :ident], [",|", :operator], [" ", :space], ["yield", :reserved], ["(", :operator], ["o", :ident], [")", :operator], [" ", :space], ["}", :operator], ["\n", :space],
    [:open, :string], ["\"", :delimiter], ["double quoted string", :content], ["\"", :delimiter], [:close, :string], ["\n", :space],
    ["# comment\n", :comment], [:open, :string], ["\"", :delimiter], ["a ", :content], [:open, :inline], ["\#{", :inline_delimiter], [" ", :space], ["b", :ident], [" ", :space], ["+", :operator], [" ", :space], [:open, :string], ["\"", :delimiter], ["c", :content], ["\"", :delimiter], [:close, :string], ["}", :inline_delimiter], [:close, :inline], ["\"", :delimiter], [:close, :string], ["\n", :space],
    ["42", :integer], [" ", :space], ["if", :reserved], [" ", :space], ["true", :reserved], ["\n", :space],
    [:open, :regexp], ["/", :delimiter], ["regexp with modifiers", :content], ["/xm", :delimiter], [:close, :regexp], ["\n", :space],
    ["a", :ident], [" ", :space], ["=", :operator], [" ", :space], ["?s", :integer], ["\n", :space],
    ["q", :ident], [" ", :space], ["=", :operator], [" ", :space], [:open, :string], ["\"", :delimiter], ["\\n", :content], ["\"", :delimiter], [:close, :string], ["\n", :space],
    ["call_something", :ident], ["()", :operator], ["\n", :space],
    ["a", :ident], [" ", :space], ["=", :operator], [" ", :space], ["1", :integer], [" ", :space], ["&&", :operator], [" ", :space], ["2", :integer], [" ", :space], ["||", :operator], [" ", :space], ["3", :integer], ["\n", :space],
    ["@ivar", :instance_variable], [" ", :space], ["=", :operator], [" ", :space], ["123", :integer], ["\n", :space],
    ["@@cvar", :class_variable], [" ", :space], ["=", :operator], [" ", :space], ["345", :integer], ["\n", :space],
    ["$gvar", :global_variable], [" ", :space], ["=", :operator], [" ", :space], ["345", :integer], ["\n", :space],
    ["float", :ident], [" ", :space], ["=", :operator], [" ", :space], ["1.2345", :float], ["\n", :space],
    [:open, :shell], ["`", :delimiter], ["shell", :content], ["`", :delimiter], [:close, :shell], ["\n", :space],
    ["v", :ident], [" ", :space], ["=", :operator], [" ", :space], ["%w(w1 w2)", :content], ["\n", :space],
    [:open, :string], ["\"", :delimiter], ["a", :content], [:open, :inline], ["\#{", :inline_delimiter], [:open, :string], ["\"", :delimiter], [" b ", :content], [:open, :inline], ["\#{", :inline_delimiter], ["@c", :instance_variable], ["}", :inline_delimiter], [:close, :inline], [" d", :content], ["\"", :delimiter], [:close, :string], [" ", :space], ["if", :reserved], [" ", :space], ["@c", :instance_variable], ["}", :inline_delimiter], [:close, :inline], [" d ", :content], [:open, :inline], ["\#{", :inline_delimiter], ["@e", :instance_variable], ["}", :inline_delimiter], [:close, :inline], ["; f.", :content], ["\"", :delimiter], [:close, :string], ["\n\n", :space], ["[].", :operator], ["each", :ident], [" ", :space], ["do", :reserved], [" ", :space], ["|*", :operator], ["args", :ident], [",", :operator], [" ", :space], ["&", :operator], ["block", :ident], ["|", :operator], ["\n", :space],
    ["self", :reserved], [".", :operator], ["class", :ident], [".", :operator], ["define_method", :ident], [" ", :space], ["do", :reserved], ["\n", :space],
    ["end", :reserved], ["\n", :space],
    ["end", :reserved], ["\n", :space],
    ["class", :reserved], [" ", :space], ["Qwe", :constant], [" ", :space], ["<", :operator], [" ", :space], ["Asd", :constant], ["\n", :space],
    ["alias", :reserved], [" ", :space], ["qwe", :ident], [" ", :space], ["asd", :ident], ["\n", :space],
    ["module", :reserved], [" ", :space], ["Sdf", :constant], ["\n", :space],
    ["def", :reserved], [" ", :space], ["self", :reserved], [".", :operator], ["sm", :ident], ["\n", :space],
    ["end", :reserved], ["\n", :space],
    ["end", :reserved], ["\n", :space],
    ["end", :reserved], ["\n", :space],
    ["=begin\nheredoc1\n=end\n", :comment], ["<<-QWE", :heredoc_beg], ["\n", :space],
    ["if", :reserved], [" ", :space], ["1", :integer], [" ", :space], [">", :operator], [" ", :space], ["0", :integer], ["\n", :space],
    ["elsif", :reserved], [" ", :space], ["false", :reserved], ["\n", :space],
    ["end", :reserved], ["\n", :space],
    ["begin", :reserved], ["\n", :space],
    ["42", :integer], ["\n", :space],
    ["rescue", :reserved], [" ", :space], ["Exception", :constant], [" ", :space], ["=>", :operator], [" ", :space], ["e", :ident], ["\n", :space],
    ["[]", :operator], [" ", :space], ["<<", :operator], [" ", :space], [:open, :string], ["'", :delimiter], ["q", :content], ["'", :delimiter], [:close, :string], ["\n", :space],
    ["end", :reserved], ["\n", :space],
    ["def", :reserved], [" ", :space], ["`", :method], ["(", :operator], ["cmd", :ident], [")", :operator], ["\n", :space],
    ["end", :reserved], ["\n", :space]]
    reflexive_tokens_without_meta_and_tags(src).should == expected_tokens
  end
end

