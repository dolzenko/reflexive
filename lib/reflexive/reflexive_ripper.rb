require "ripper"
require "reflexive/parse_tree_top_down_walker"

module Reflexive
  # Records all scanner events, injects meta-events when scope
  # changes (required to implement constant/method look-up) 
  class ReflexiveRipper < Ripper
    attr_accessor :scanner_events

    META_EVENT = [ :meta_scope ].freeze

    def initialize(*args)
      super
      @scanner_events = []
      @await_scope_change = false
      @scope = []
      @new_scope = nil
    end

    def parse
      parse_tree = super
      
      if ENV["DEBUG"]
        require 'pp'
        pp parse_tree
      end

      ParseTreeTopDownWalker.new(parse_tree).walk
      parse_tree
    end

    # Returns array in format: [event_value, event_name, tags]
    def self.destruct_scanner_event(scanner_event)
      tags = scanner_event.delete(:tags)
      [ scanner_event.values.first, scanner_event.keys.first, tags ]  
    end

    def self.is_meta_event?(event)
      META_EVENT.include?(event)
    end

    Ripper::SCANNER_EVENTS.each do |meth|
      define_method("on_#{ meth }") do |*args|
        result = super(*args)
        @scanner_events << { meth.to_sym => args[0] }
        stop_await_scope_change
        @scanner_events[-1]
      end
    end

    def stop_await_scope_change
      # get here when any of 3 possible constant reference ends,
      # which means we have new scope in effect
      if @await_scope_change
        if @new_scope
          @scope << @new_scope.dup
          inject_current_scope
          @new_scope = nil
        end
        @await_scope_change = false
      end
    end

    def inject_current_scope
      @scanner_events << { :meta_scope => @scope.dup }
    end

    PARSER_EVENT_TABLE.each do |event, arity|
      if /_new\z/ =~ event.to_s and arity == 0
        module_eval(<<-End, __FILE__, __LINE__ + 1)
          def on_#{event}
            []
          end
        End
      elsif /_add\z/ =~ event.to_s
        module_eval(<<-End, __FILE__, __LINE__ + 1)
          def on_#{event}(list, item)
            list.push item
            list
          end
        End
      else
        module_eval(<<-End, __FILE__, __LINE__ + 1)
          def on_#{event}(*args)
            [:#{event}, *args]
          end
        End
      end
    end

    # Two parser events which fire when class/module definition ends
    def on_class(*args)
      @scope.pop
      inject_current_scope
      
      [:class, *args]
    end

    def on_module(*args)
      @scope.pop
      inject_current_scope

      [:module, *args]
    end

    def on_parse_error(*args)
      raise SyntaxError, "#{ lineno }: #{ args[0] }"
    end

#    def on_call(*args)
#      # puts "PARSE: on_call: #{ args.inspect }"
#      if args.size == 3 &&
#              (constant = resolve_constant_ref(args[0])) &&
#              args[1] == :"." &&
#              args[2][1] == :ident
#
#        meth_ident_token = args[2]
#        index = token_index(meth_ident_token)
#        tags = { :constant => constant, :method => args[2][0] }
#        # wrap the method identifier token in :method_call meta tokens
#        @scanner_events[index .. index] = [
#          # [ :method_call, :open, tags ],
#          meth_ident_token,
#          # [ :method_call, :close ]
#        ]
#      end
#      [:call, *args]
#    end
#
#    def on_var_ref(*args)
#      # puts "PARSER: var_ref: #{ args.inspect }"
#      if args.size == 1 &&
#              args[0].size == 2 &&
#              args[0][1] == :ident
#        meth_ident_token = args[0]
#        index = token_index(meth_ident_token)
#        tags = { :instance_method => args[0][0] }
#        @scanner_events[index .. index] = [
#          [ :method_call, :open, tags ],
#          meth_ident_token,
#          [ :method_call, :close ]
#        ]
#        # r @scanner_events[177]
#      end
#      [:var_ref, *args]
#    end

    def token_index(token)
      @scanner_events.index do |t|
         t.object_id == token.object_id
      end
    end

    def resolve_constant_ref(tokens)
      self.class.resolve_constant_ref(tokens)
    end

    def self.resolve_constant_ref(tokens)
      if tokens[0] == :var_ref && tokens[1][1] == :const
        # [:var_ref, ["B", :const]]
        tokens[1][0]
      elsif tokens[0] == :top_const_ref && tokens[1][1] == :const
        # [:top_const_ref, ["A", :const]]
        "::" + tokens[1][0]
        # [:const_path_ref, [:top_const_ref, ["A", :const]], ["B", :const]]
        # [:const_path_ref, [:var_ref, ["A", :const]], ["B", :const]]
      elsif tokens[0] == :const_path_ref && (constant = resolve_constant_ref(tokens[1]))
        "#{ constant }::#{ tokens[2][0] }"
      end
    end

    def on_sp(*args)
      @scanner_events << { :sp => args[0] }
      # ignore space tokens when waiting for scope changes:
      # stop_await_scope_change
      
      @scanner_events[-1]
    end

    # parse.y:
    #
    #     | k_class cpath superclass
    #     | k_module cpath
    #
    # matches "class"
    def on_kw(kw)
      if %w(class module).include?(kw)
        @await_scope_change = "k_class"
      else
        stop_await_scope_change
      end

      @scanner_events << { :kw => kw }
      
      @scanner_events[-1]
    end

    # matches "::" in two cases
    #   1. "class ::TopLevel",
    #   2. "class Nested::Class"
    def on_op(token)
      if @await_scope_change == "k_class" &&
              token == "::"
        # tCOLON2, tCOLON3
        #  cpath		: tCOLON3 cname
        #		    {
        #		    /*%%%*/
        #			$$ = NEW_COLON3($2);
        #		    /*%
        #			$$ = dispatch1(top_const_ref, $2);
        #		    %*/
        #		    }
        @await_scope_change = "k_class tCOLON3"
      elsif @await_scope_change == "k_class primary_value tCOLON2" &&
              token == "::" # tCOLON2, tCOLON3
        @new_scope << "::" # append to the last defined scope
      else
        stop_await_scope_change
      end
      
      @scanner_events << { :op => token }
      
      @scanner_events[-1]
    end

    #  cname		: tIDENTIFIER
    #          {
    #          /*%%%*/
    #        yyerror("class/module name must be CONSTANT");
    #          /*%
    #        $$ = dispatch1(class_name_error, $1);
    #          %*/
    #          }
    #      | tCONSTANT
    #      ;
    #
    # "ClassName"
    # or
    # "ClassName::NestedClassName"
    def on_const(const_name)
      if @await_scope_change == "k_class tCOLON3" # "class ::TopClass"
        @new_scope = "::#{ const_name }"
      elsif @await_scope_change == "k_class" # "class NormalClass"
        #		| cname
        #		    {
        #		    /*%%%*/
        #			$$ = NEW_COLON2(0, $$);
        #		    /*%
        #			$$ = dispatch1(const_ref, $1);
        #		    %*/
        #		    }
        @new_scope = "#{ const_name }"
        @await_scope_change = "k_class primary_value tCOLON2" # "class Class::NestedClass"
      elsif @await_scope_change == "k_class primary_value tCOLON2"
        #
        #		| primary_value tCOLON2 cname
        #		    {
        #		    /*%%%*/
        #			$$ = NEW_COLON2($1, $3);
        #		    /*%
        #			$$ = dispatch2(const_path_ref, $1, $3);
        #		    %*/
        #		    }
        #		;
        #
        # cname		: tIDENTIFIER
        @new_scope << "#{ const_name }" # append to the scope
      else
        stop_await_scope_change
      end

      @scanner_events << { :const => const_name }
      
      @scanner_events[-1]
    end
  end
end