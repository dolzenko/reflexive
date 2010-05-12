require "ripper"

module Reflexive
  # Records all scanner events, injects meta-events when scope
  # changes (required to implement constant/method look-up) 
  class ReflexiveRipper < Ripper
    attr_accessor :scanner_events

    META_EVENT = [ :meta_scope ].freeze
    
    def self.is_meta_event?(event)
      META_EVENT.include?(event)
    end

    def initialize(*args)
      super
      @scanner_events = []
      @await_scope_change = false
      @scope = []
      @new_scope = nil
    end

    Ripper::SCANNER_EVENTS.each do |meth|
      define_method("on_#{ meth }") do |*args|
        result = super(*args)
        @scanner_events << [args[0], meth.to_sym]
        stop_await_scope_change
        result
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
      @scanner_events << [ @scope.dup, :meta_scope ]
    end

    # Two parser events which fire when class/module definition ends
    def on_class(*args)
      @scope.pop
      inject_current_scope
      
      super
    end

    def on_module(*args)
      @scope.pop
      inject_current_scope

      super
    end

    def on_parse_error(*args)
      raise SyntaxError, "#{ lineno }: #{ args[0] }"
    end

    def on_sp(*args)
      @scanner_events << [args[0], :sp]
      # ignore space tokens when waiting for scope changes:
      # stop_await_scope_change
      
      super
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

      @scanner_events << [kw, :kw]
      
      super
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
      
      @scanner_events << [token, :op]
      
      super
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

      @scanner_events << [const_name, :const]
      
      super
    end
  end
end