require "coderay"

module Reflexive
  require "reflexive/reflexive_ripper"

  # TODO Heredocs in args are royally screwed
  class CodeRayRubyScanner < ::CodeRay::Scanners::Scanner
    SCANNER_EVENT_TO_CODERAY_TOKEN =
            {
                    :kw => :reserved,
                    :nl => :space,
                    :sp => :space,
                    :ignored_nl => :space,
                    # :tstring_beg => :delimiter,
                    # :tstring_end => :delimiter,
                    :tstring_content => :content,
                    # Кipper reports rbrace always, CodeRay differentiates
                    # between blocks, and rbraces in string interpol
                    # :embexpr_beg => :inline_delimiter,
                    :lbrace => :operator,
                    :rbrace => :operator,
                    :lparen => :operator,
                    :rparen => :operator,
                    :lbracket => :operator,
                    :rbracket => :operator,
                    :comma => :operator,
                    :op => :operator,
                    :int => :integer,
                    :period => :operator,
                    :const => :constant,
                    :cvar => :class_variable,
                    :ivar => :instance_variable,
                    :gvar => :global_variable,
                    :embvar => :escape, # ?
                    :embdoc_beg => :comment,
                    :embdoc => :comment,
                    :embdoc_end => :comment,
                    :qwords_beg => :content,
                    :words_sep => :content,
                    :CHAR => :integer,
                    # * :constant => :class, CodeRay reports `class` token for
                    #   class def, we report just `const` always
                    # * Ripper doesn't have `char` event
                    # * `42 if true` - CodeRay reports `pre_constant`
            }

    def coderay_tokens(scanner_events)
      @coderay_tokens = []
      in_backtick = false
      in_symbol = false
      in_embexpr_nesting = 0
      scanner_events.each do |token_val, event|
        if event == :meta_scope
          @coderay_tokens << [token_val, event]
          next
        end

        ripper_token = SCANNER_EVENT_TO_CODERAY_TOKEN[event.to_sym] || event.to_sym
        if in_backtick && event == :lparen
          @coderay_tokens.pop # remove [:open, :shell], [token_val, :delimiter]
          @coderay_tokens.pop # and replace with method declaration
          @coderay_tokens << ["`", :method]
          @coderay_tokens << ["(", :operator]
        elsif in_embexpr_nesting > 0 && event == :rbrace
          @coderay_tokens << [token_val, :inline_delimiter]
          @coderay_tokens << [:close, :inline]
          in_embexpr_nesting -= 1
        elsif event == :embexpr_beg
          @coderay_tokens << [:open, :inline]
          @coderay_tokens << [token_val, :inline_delimiter]
          in_embexpr_nesting += 1
        elsif in_symbol && [:ident, :const, :ivar, :cvar, :gvar, :op, :kw].include?(event)
          # parse.y
          #
          # symbol		: tSYMBEG sym
          #
          #          sym		: fname
          #              | tIVAR
          #              | tGVAR
          #              | tCVAR
          #              ;
          #
          #          fname		: tIDENTIFIER
          #              | tCONSTANT
          #              | tFID
          #              | op
          #                  {
          #                lex_state = EXPR_ENDFN;
          #                $$ = $1;
          #                  }
          #              | reswords
          #                  {
          #                lex_state = EXPR_ENDFN;
          #                  /*%%%*/
          #                $$ = $<id>1;
          #                  /*%
          #                $$ = $1;
          #                  %*/
          #                  }
          #              ;
          @coderay_tokens << [token_val, :content]
          @coderay_tokens << [:close, :symbol]
          in_symbol = false
        elsif ripper_token == :regexp_beg
          @coderay_tokens << [:open, :regexp]
          @coderay_tokens << [token_val, :delimiter]
        elsif ripper_token == :regexp_end
          @coderay_tokens << [token_val, :delimiter]
          @coderay_tokens << [:close, :regexp]
        elsif ripper_token == :tstring_beg
          @coderay_tokens << [:open, :string]
          @coderay_tokens << [token_val, :delimiter]
        elsif ripper_token == :tstring_end
          @coderay_tokens << [token_val, :delimiter]
          if in_backtick
            @coderay_tokens << [:close, :shell]
            in_backtick = false
          elsif in_symbol
            @coderay_tokens << [:close, :symbol]
            in_symbol = false
          else
            @coderay_tokens << [:close, :string]
          end
        elsif ripper_token == :symbeg
          if in_symbol # nesting not supported
            @coderay_tokens << [token_val, :symbol]
          else
            @coderay_tokens << [:open, :symbol]
            @coderay_tokens << [token_val, :delimiter]
            in_symbol = true
          end
        elsif ripper_token == :backtick
          if in_backtick # nesting not supported 
            @coderay_tokens << [token_val, :operator]
          else
            @coderay_tokens << [:open, :shell]
            @coderay_tokens << [token_val, :delimiter]
            in_backtick = true
          end
        else
          if @coderay_tokens.size > 0 && @coderay_tokens[-1][1] == ripper_token
            @coderay_tokens[-1][0] << token_val
          else
            @coderay_tokens << [token_val, ripper_token]
          end
        end
      end


      inject_constant_tags(squeeze_constants(@coderay_tokens))
    end

    def squeeze_constants(coderay_tokens)
      tokens = []
      coderay_tokens.reverse_each do |token|
        if tokens.size > 0
          if token[1] == :constant &&
            tokens[-1][1] == :constant
            tokens[-1][0] = "#{ token[0] }#{ tokens[-1][0] }"
          elsif token == [ "::", :operator ] &&
            tokens[-1][1] == :constant
            tokens[-1][0] = "#{ token[0] }#{ tokens[-1][0] }"
          else
            tokens << token
          end
        else
          tokens << token
        end
      end
      tokens.reverse
    end

    def inject_constant_tags(coderay_tokens)
      scope = nil
      coderay_tokens.each do |token|
        if token[1] == :constant
          token << { :scope => scope }
        elsif token[1] == :meta_scope
          scope = token[0]
          scope = nil if scope.empty?
        end
      end
      coderay_tokens
    end

    def scan_tokens(tokens, options)
      parser = ReflexiveRipper.new(code)
      parser.parse
      tokens.replace(coderay_tokens(parser.scanner_events))
      tokens
    end
  end
end