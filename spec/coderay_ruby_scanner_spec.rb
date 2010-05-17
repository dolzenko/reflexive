require "reflexive/coderay_ruby_scanner"
require "coderay/scanners/ruby"

describe Reflexive::CodeRayRubyScanner do
  def reflexive_tokens(src)
    Reflexive::CodeRayRubyScanner.new(src).tokenize
  end

  def reflexive_tokens_without_meta_and_tags(src)
    Reflexive::CodeRayRubyScanner.new(src).tokenize.
            reject { |t| t[1] == :meta_scope }.
            reject { |t| t[0] == :method_call }.
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

  it "injects load_path tags" do
    reflexive_tokens("require('f')").should include(["f", :content, { :load_path => true }])
    reflexive_tokens("require 'f'").should include(["f", :content, { :load_path => true }])
  end

  SOURCE_TO_TOKENS = {
          '%Q{str}' => [[:open, :string], ["%Q{", :delimiter], ["str", :content], ["}", :delimiter], [:close, :string]],
          '%r<regexp>' => [[:open, :regexp], ["%r<", :delimiter], ["regexp", :content], [">", :delimiter], [:close, :regexp]],
          ":symbol" => [[:open, :symbol], [":", :delimiter], ["symbol", :content], [:close, :symbol]],
          ":@instance_var_symbol" => [[:open, :symbol], [":", :delimiter], ["@instance_var_symbol", :content], [:close, :symbol]],
          ":@@class_var_symbol" => [[:open, :symbol], [":", :delimiter], ["@@class_var_symbol", :content], [:close, :symbol]],
          ":$global_var_symbol" => [[:open, :symbol], [":", :delimiter], ["$global_var_symbol", :content], [:close, :symbol]],
          ":ConstantSymbol" => [[:open, :symbol], [":", :delimiter], ["ConstantSymbol", :content], [:close, :symbol]],
          ":+" => [[:open, :symbol], [":", :delimiter], ["+", :content], [:close, :symbol]],
          ":if" => [[:open, :symbol], [":", :delimiter], ["if", :content], [:close, :symbol]],
          "#!/usr/bin/env ruby" => [["#!/usr/bin/env ruby", :comment]],
          '%q[haha! [nesting [rocks] ] ! ]' => [[:open, :string], ["%q[", :delimiter], ["haha! [nesting [rocks] ] ! ", :content],
                                              ["]", :delimiter], [:close, :string]],
          '%Q[hehe! #{ %Q]nesting #{"really"} rocks] } ! ]' => [[:open, :string], ["%Q[", :delimiter], ["hehe! ", :content],
                                                                [:open, :inline], ["\#{", :inline_delimiter], [" ", :space],
                                                                [:open, :string], ["%Q]", :delimiter], ["nesting ", :content],
                                                                [:open, :inline], ["\#{", :inline_delimiter], [:open, :string],
                                                                ["\"", :delimiter], ["really", :content], ["\"", :delimiter],
                                                                [:close, :string], ["}", :inline_delimiter], [:close, :inline],
                                                                [" rocks", :content], ["]", :delimiter], [:close, :string],
                                                                [" ", :space], ["}", :inline_delimiter], [:close, :inline],
                                                                [" ! ", :content], ["]", :delimiter], [:close, :string]],
          'some_string.to_i /\\s+/' => [["some_string", :ident], [".", :operator], ["to_i", :ident], [" ", :space], [:open, :regexp], ["/", :delimiter], ["\\s+", :content], ["/", :delimiter], [:close, :regexp]],
          'S = \'bla\' * 100 + "\n" + "\t"*4' => [["S", :constant], [" ", :space], ["=", :operator],
                                                  [" ", :space], [:open, :string], ["'", :delimiter],
                                                  ["bla", :content], ["'", :delimiter], [:close, :string],
                                                  [" ", :space], ["*", :operator], [" ", :space],
                                                  ["100", :integer], [" ", :space], ["+", :operator],
                                                  [" ", :space], [:open, :string], ["\"", :delimiter],
                                                  ["\\n", :content], ["\"", :delimiter], [:close, :string],
                                                  [" ", :space], ["+", :operator], [" ", :space], [:open, :string],
                                                  ["\"", :delimiter], ["\\t", :content], ["\"", :delimiter], [:close, :string],
                                                  ["*", :operator], ["4", :integer]],
          ':"#{undef :blubb}#@@cv"' => [[:open, :symbol], [":\"", :delimiter], [:open, :inline], 
                                          ["\#{", :inline_delimiter], ["undef", :content],
                                          [:close, :symbol], [" ", :space], [:open, :symbol],
                                          [":", :delimiter], ["blubb", :content], [:close, :symbol],
                                          ["}", :inline_delimiter], [:close, :inline], ["#", :escape],
                                          ["@@cv", :class_variable], ["\"", :delimiter], [:close, :string]],
          'undef :"bla", /, :"#{undef :blubb}#@@cv"' => [["undef", :reserved], [" ", :space],
                                                           [:open, :symbol], [":\"", :delimiter],
                                                           ["bla", :content], ["\"", :delimiter],
                                                           [:close, :symbol], [",", :operator], [" ", :space],
                                                           ["/,", :operator], [" ", :space], [:open, :symbol],
                                                           [":\"", :delimiter], [:open, :inline], ["\#{", :inline_delimiter],
                                                           ["undef", :content], [:close, :symbol], [" ", :space], [:open, :symbol],
                                                           [":", :delimiter], ["blubb", :content], [:close, :symbol],
                                                           ["}", :inline_delimiter], [:close, :inline], ["#", :escape],
                                                           ["@@cv", :class_variable], ["\"", :delimiter], [:close, :string]],
          '@hash.delete_if { |o,| yield(o) }' => [["@hash", :instance_variable], [".", :operator], ["delete_if", :ident], [" ", :space], ["{", :operator], [" ", :space], ["|", :operator], ["o", :ident], [",|", :operator], [" ", :space], ["yield", :reserved], ["(", :operator], ["o", :ident], [")", :operator], [" ", :space], ["}", :operator]],
          '"double quoted string"' => [[:open, :string], ["\"", :delimiter], ["double quoted string", :content], ["\"", :delimiter], [:close, :string]],
          '# comment' => [["# comment", :comment]],
          '"a #{ b + "c"}"' => [[:open, :string], ["\"", :delimiter], ["a ", :content], [:open, :inline], ["\#{", :inline_delimiter], [" ", :space], ["b", :ident], [" ", :space], ["+", :operator], [" ", :space], [:open, :string], ["\"", :delimiter], ["c", :content], ["\"", :delimiter], [:close, :string], ["}", :inline_delimiter], [:close, :inline], ["\"", :delimiter], [:close, :string]],
          '42 if true' => [["42", :integer], [" ", :space], ["if", :reserved], [" ", :space], ["true", :reserved]],
          '/regexp with modifiers/xm' => [[:open, :regexp], ["/", :delimiter], ["regexp with modifiers", :content], ["/xm", :delimiter], [:close, :regexp]],
          'a = ?s' => [["a", :ident], [" ", :space], ["=", :operator], [" ", :space], ["?s", :integer]],
          'q = "\\n"' => [["q", :ident], [" ", :space], ["=", :operator], [" ", :space], [:open, :string], ["\"", :delimiter], ["\\n", :content], ["\"", :delimiter], [:close, :string]],
          'call_something()' => [["call_something", :ident], ["()", :operator]],
          'a = 1 && 2 || 3' => [["a", :ident], [" ", :space], ["=", :operator], [" ", :space], ["1", :integer], [" ", :space], ["&&", :operator], [" ", :space], ["2", :integer], [" ", :space], ["||", :operator], [" ", :space], ["3", :integer]],
          '@ivar = 123' => [["@ivar", :instance_variable], [" ", :space], ["=", :operator], [" ", :space], ["123", :integer]],
          '@@cvar = 345' => [["@@cvar", :class_variable], [" ", :space], ["=", :operator], [" ", :space], ["345", :integer]],
          '$gvar = 345' => [["$gvar", :global_variable], [" ", :space], ["=", :operator], [" ", :space], ["345", :integer]],
          'float = 1.2345' => [["float", :ident], [" ", :space], ["=", :operator], [" ", :space], ["1.2345", :float]],
          '`shell`' => [[:open, :shell], ["`", :delimiter], ["shell", :content], ["`", :delimiter], [:close, :shell]],
          'v = %w(w1 w2)' => [["v", :ident], [" ", :space], ["=", :operator], [" ", :space], ["%w(w1 w2)", :content]],
          '"a#{" b #{@c} d" if @c} d #{@e}; f."' => [[:open, :string], ["\"", :delimiter], ["a", :content],
                                                     [:open, :inline], ["\#{", :inline_delimiter], [:open, :string],
                                                     ["\"", :delimiter], [" b ", :content], [:open, :inline],
                                                     ["\#{", :inline_delimiter], ["@c", :instance_variable], ["}", :inline_delimiter],
                                                     [:close, :inline], [" d", :content], ["\"", :delimiter], [:close, :string],
                                                     [" ", :space], ["if", :reserved], [" ", :space], ["@c", :instance_variable],
                                                     ["}", :inline_delimiter], [:close, :inline], [" d ", :content], [:open, :inline],
                                                     ["\#{", :inline_delimiter], ["@e", :instance_variable], ["}", :inline_delimiter],
                                                     [:close, :inline], ["; f.", :content], ["\"", :delimiter], [:close, :string]],
          '[].each do |*args, &block|
            self.class.define_method do
            end
          end' => [["[].", :operator], ["each", :ident], [" ", :space], ["do", :reserved], [" ", :space], ["|*", :operator], ["args", :ident], [",", :operator], [" ", :space], ["&", :operator], ["block", :ident], ["|", :operator], ["\n", :space],
                    ["self", :reserved], [".", :operator], ["class", :ident], [".", :operator], ["define_method", :ident], [" ", :space], ["do", :reserved], ["\n", :space],
                    ["end", :reserved], ["\n", :space],
                    ["end", :reserved]
                    ],

          'class Qwe < Asd
            alias qwe asd
            module Sdf
              def self.sm
              end
            end
          end' => [["class", :reserved], [" ", :space], ["Qwe", :constant], [" ", :space], ["<", :operator], [" ", :space],
                   ["Asd", :constant], ["\n", :space],
                   ["alias", :reserved], [" ", :space], ["qwe", :ident], [" ", :space], ["asd", :ident], ["\n", :space],
                   ["module", :reserved], [" ", :space], ["Sdf", :constant], ["\n", :space],
                   ["def", :reserved], [" ", :space], ["self", :reserved], [".", :operator], ["sm", :ident], ["\n", :space],
                   ["end", :reserved], ["\n", :space],
                   ["end", :reserved], ["\n", :space],
                   ["end", :reserved]],
          '=begin
             heredoc1
           =end' => [["=begin\nheredoc1\n=end", :comment]],

          '<<-QWE
           QWE' =>
                  (RUBY_VERSION > '1.9.1' ?
                          [["<<-QWE", :heredoc_beg], ["\n", :space]] : 
                          [["<<-QWE", :heredoc_beg], ["QWE", :heredoc_end], ["\n", :space]]), 

          'if 1 > 0
           elsif false
           end' => [["if", :reserved], [" ", :space], ["1", :integer], [" ", :space], [">", :operator], [" ", :space], ["0", :integer], ["\n", :space], ["elsif", :reserved], [" ", :space], ["false", :reserved], ["\n", :space], ["end", :reserved]],

          'begin
             42
           rescue Exception => e
             [] << \'q\'
           end' => [["begin", :reserved], ["\n", :space], ["42", :integer], ["\n", :space], ["rescue", :reserved], [" ", :space], ["Exception", :constant], [" ", :space], ["=>", :operator], [" ", :space], ["e", :ident], ["\n", :space], ["[]", :operator], [" ", :space], ["<<", :operator], [" ", :space], [:open, :string], ["'", :delimiter], ["q", :content], ["'", :delimiter], [:close, :string], ["\n", :space], ["end", :reserved]],

          'def `(cmd)
           end' => [["def", :reserved], [" ", :space], ["`", :method], ["(", :operator], ["cmd", :ident], [")", :operator], ["\n", :space], ["end", :reserved]],
        }

  SOURCE_TO_TOKENS.each do |source, tokens|
    it "parses #{ source } just as CodeRay parser does" do
      reflexive_tokens_without_meta_and_tags(source.dup.gsub(/^ */, "")).should == tokens
    end
  end
end

