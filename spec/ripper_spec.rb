require "ripper"

require File.expand_path("../sexp_builder_with_scanner_events", __FILE__)

describe Ripper do
  def events_tree(src)
    parser = SexpBuilderWithScannerEvents.new(src)
    parser.parse
  end

  Rspec::Matchers.define :parse_as do |*expected_events_tree|
    match do |source|
      events_tree(source)[1][0] == expected_events_tree
    end

    failure_message_for_should do |source|
      require "pp"
      "expected \"#{ source }\" to generate events:\n" <<
              "#{ expected_events_tree.pretty_inspect }" <<
              "got:\n#{ events_tree(source)[1][0].pretty_inspect }"
    end
  end

  BODYSTMT_VOID = [:bodystmt, [[:void_stmt]], nil, nil, nil].freeze
  PARAMS_VOID = [:params, nil, nil, nil, nil, nil].freeze

  describe "parser events" do
    specify "class definition (class)" do
      "class C < D; end".should parse_as(:class,
                                         [:const_ref, {:const=>"C"}],
                                         [:var_ref, {:const=>"D"}],
                                         BODYSTMT_VOID)
    end

    specify "singleton class definition (sclass)" do
      "class << self; end".should parse_as(:sclass,
                                           [:var_ref, {:kw=>"self"}],
                                           BODYSTMT_VOID)
    end

    specify "module definition (module)" do
      "module M; end".should parse_as(:module,
                                      [:const_ref, {:const=>"M"}],
                                      BODYSTMT_VOID)
    end

    specify "method definition (def)" do
      "def m; end".should parse_as(:def,
                                   {:ident=>"m"},
                                   PARAMS_VOID,
                                   BODYSTMT_VOID)
    end

    specify "method definition complete (def)" do
      "def m(a,o=1,*r,a2,&b); rescue E1,E2 => e; 1; rescue E3; 1; else v = 1; v = 1; ensure 1; end".should(parse_as(
              :def,
              {:ident=>"m"},
              [:paren,
               [:params,
                [{:ident=>"a"}],
                [[{:ident=>"o"}, {:int=>"1"}]],
                [:rest_param, {:ident=>"r"}],
                [{:ident=>"a2"}],
                [:blockarg, {:ident=>"b"}]]],
              [:bodystmt,
               [[:void_stmt]],
               [:rescue,
                [:mrhs_new_from_args,
                 [[:var_ref, {:const=>"E1"}]],
                 [:var_ref, {:const=>"E2"}]],
                [:var_field, {:ident=>"e"}],
                [{:int=>"1"}],
                [:rescue, [[:var_ref, {:const=>"E3"}]], nil, [{:int=>"1"}], nil]],
               [:else,
                [[:assign, [:var_field, {:ident=>"v"}], {:int=>"1"}],
                 [:assign, [:var_field, {:ident=>"v"}], {:int=>"1"}]]],
               [:ensure, [{:int=>"1"}]]]))
    end

    specify "singleton method definition (defs)" do
      "def self.m; end".should parse_as(:defs,
                                        [:var_ref, {:kw=>"self"}],
                                        {:period=>"."},
                                        {:ident=>"m"},
                                        PARAMS_VOID,
                                        BODYSTMT_VOID)
    end

    specify "do block definition (do_block)" do
      "m do end".should parse_as(:method_add_block,
                                 [:method_add_arg, [:fcall, {:ident=>"m"}], []],
                                 [:do_block, nil, [[:void_stmt]]])
    end

    specify "brace block definition (brace_block)" do
      "m { }".should parse_as(:method_add_block,
                              [:method_add_arg, [:fcall, {:ident=>"m"}], []],
                              [:brace_block, nil, [[:void_stmt]]])
    end

    def f_arg
      [{:ident=>"a"}]
    end

    def f_arg2
      [{:ident=>"a2"}]
    end

    def f_block_optarg
      [[{:ident=>"o"}, {:int=>"1"}]]
    end

    def f_optarg
      [[{:ident=>"o"}, {:int=>"1"}]]
    end

    def f_rest_arg
      [:rest_param, {:ident=>"r"}]
    end

    def opt_f_block_arg
      [:blockarg, {:ident=>"b"}]
    end

    describe "block variables according to parse.y" do
      def block_variables(src, *variables)
        variables = nil if variables == [nil]
        src.should(parse_as(*[:method_add_block,
                              [:method_add_arg, [:fcall, {:ident=>"m"}], []],
                              [:do_block,
                               [:block_var, PARAMS_VOID, variables],
                               [[:void_stmt]]]]))
      end

      def block_params_and_variables(src, params, variables)
        src.should(parse_as(*[:method_add_block,
                              [:method_add_arg, [:fcall, {:ident=>"m"}], []],
                              [:do_block,
                               [:block_var, [:params, *params], variables],
                               [[:void_stmt]]]]))
      end

      specify "'|' opt_bv_decl '|' => blockvar_new(params_new(Qnil,Qnil,Qnil,Qnil,Qnil), escape_Qundef($2))" do
        block_variables("m do |;v1| end",
                        {:ident=>"v1"})
        block_variables("m do |;v1,v2| end",
                        {:ident=>"v1"}, {:ident=>"v2"})
      end

      specify "tOROP => blockvar_new(params_new(Qnil,Qnil,Qnil,Qnil,Qnil), Qnil);" do
        block_variables("m do || end", nil)
      end

      specify "'|' block_param opt_bv_decl '|' => blockvar_new(escape_Qundef($2), escape_Qundef($3));" do
        block_params_and_variables("m do |a,o=1,*r,a2,&b;v1,v2| end",
                                   [f_arg, f_block_optarg, f_rest_arg, f_arg2, opt_f_block_arg],
                                   [{:ident=>"v1"}, {:ident=>"v2"}])
      end
    end

    describe "block params according to parse.y" do
      def block_params(src, *params)
        src.should(parse_as(*[:method_add_block,
                              [:method_add_arg, [:fcall, {:ident=>"m"}], []],
                              [:do_block,
                               [:block_var, [:params, *params], nil], # ???
                               [[:void_stmt]]]]))
      end

      specify "f_arg ',' f_block_optarg ',' f_rest_arg ',' f_arg opt_f_block_arg => params_new($1, $3, $5, $7, escape_Qundef($8));" do
        block_params("m do |a,o=1,*r,a2,&b| end",
                     f_arg, f_block_optarg, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      # the rest are mere combinations

      specify "f_arg ',' f_block_optarg ',' f_rest_arg opt_f_block_arg => params_new($1, $3, $5, Qnil, escape_Qundef($6));" do
        block_params("m do |a,o=1,*r,&b| end",
                     f_arg, f_block_optarg, f_rest_arg, nil, opt_f_block_arg)
      end

      specify "f_arg ',' f_block_optarg opt_f_block_arg => params_new($1, $3, Qnil, Qnil, escape_Qundef($4));" do
        block_params("m do |a,o=1,&b| end",
                     f_arg, f_block_optarg, nil, nil, opt_f_block_arg)
      end

      specify "f_arg ',' f_block_optarg ',' f_arg opt_f_block_arg => params_new($1, $3, Qnil, $5, escape_Qundef($6));" do
        block_params("m do |a,o=1,a2,&b| end",
                     f_arg, f_block_optarg, nil, f_arg2, opt_f_block_arg)
      end

      specify "f_arg ',' f_rest_arg opt_f_block_arg => params_new($1, Qnil, $3, Qnil, escape_Qundef($4));" do
        block_params("m do |a,*r,&b| end",
                     f_arg, nil, f_rest_arg, nil, opt_f_block_arg)
      end

      specify "f_arg ',' => params_new($1, Qnil, Qnil, Qnil, Qnil);" do
        block_params("m do |a,| end",
                     f_arg, nil, nil, nil, nil)
      end

      specify "f_arg ',' f_rest_arg ',' f_arg opt_f_block_arg => params_new($1, Qnil, $3, $5, escape_Qundef($6));" do
        block_params("m do |a,*r,a2,&b| end",
                     f_arg, nil, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      specify "f_arg opt_f_block_arg => params_new($1, Qnil, Qnil, Qnil, escape_Qundef($2));" do
        block_params("m do |a,&b| end",
                     f_arg, nil, nil, nil, opt_f_block_arg)
      end

      specify "f_block_optarg ',' f_rest_arg opt_f_block_arg => params_new(Qnil, $1, $3, Qnil, escape_Qundef($4));" do
        block_params("m do |o=1,*r,&b| end",
                     nil, f_block_optarg, f_rest_arg, nil, opt_f_block_arg)
      end

      specify "f_block_optarg ',' f_rest_arg ',' f_arg opt_f_block_arg => params_new(Qnil, $1, $3, $5, escape_Qundef($6));" do
        block_params("m do |o=1,*r,a2,&b| end",
                     nil, f_block_optarg, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      specify "f_block_optarg opt_f_block_arg => params_new(Qnil, $1, Qnil, Qnil,escape_Qundef($2));" do
        block_params("m do |o=1,&b| end",
                     nil, f_block_optarg, nil, nil, opt_f_block_arg)
      end

      specify "f_block_optarg ',' f_arg opt_f_block_arg => params_new(Qnil, $1, Qnil, $3, escape_Qundef($4));" do
        block_params("m do |o=1,a2,&b| end",
                     nil, f_block_optarg, nil, f_arg2, opt_f_block_arg)
      end

      specify "f_rest_arg opt_f_block_arg => params_new(Qnil, Qnil, $1, Qnil, escape_Qundef($2));" do
        block_params("m do |*r,&b| end",
                     nil, nil, f_rest_arg, nil, opt_f_block_arg)
      end


      specify "f_rest_arg ',' f_arg opt_f_block_arg => params_new(Qnil, Qnil, $1, $3, escape_Qundef($4));" do
        block_params("m do |*r,a2,&b| end",
                     nil, nil, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      specify "f_block_arg => params_new(Qnil, Qnil, Qnil, Qnil, $1);" do
        block_params("m do |&b| end",
                     nil, nil, nil, nil, opt_f_block_arg)
      end

      specify "none" do
        block_params("m do || end",
                     nil, nil, nil, nil, nil)
      end
    end

    describe "method params according to parse.y" do
      def def_params(src, *params)
        src.should(parse_as(*[:def,
                              {:ident=>"m"},
                              [:paren, [:params, *params]],
                              BODYSTMT_VOID]))
      end

      specify "f_arg ',' f_optarg ',' f_rest_arg ',' f_arg opt_f_block_arg => params_new($1, $3, $5, $7, escape_Qundef($8));" do
        def_params("def m(a,o=1,*r,a2,&b); end",
                   f_arg, f_optarg, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      # the rest are mere combinations

      specify "f_arg ',' f_optarg ',' f_rest_arg opt_f_block_arg => params_new($1, $3, $5, Qnil, escape_Qundef($6))" do
        def_params("def m(a,o=1,*r,&b); end",
                   f_arg, f_optarg, f_rest_arg, nil, opt_f_block_arg)
      end

      specify "f_arg ',' f_optarg opt_f_block_arg => params_new($1, $3, Qnil, Qnil, escape_Qundef($4));" do
        def_params("def m(a,o=1,&b); end",
                   f_arg, f_optarg, nil, nil, opt_f_block_arg)
      end

      specify "f_arg ',' f_optarg ',' f_arg opt_f_block_arg => params_new($1, $3, Qnil, $5, escape_Qundef($6));" do
        def_params("def m(a,o=1,a2,&b); end",
                   f_arg, f_optarg, nil, f_arg2, opt_f_block_arg)
      end

      specify "f_arg ',' f_rest_arg opt_f_block_arg => params_new($1, Qnil, $3, Qnil, escape_Qundef($4));" do
        def_params("def m(a,*r,&b); end",
                   f_arg, nil, f_rest_arg, nil, opt_f_block_arg)
      end

      specify "f_arg ',' f_rest_arg ',' f_arg opt_f_block_arg => params_new($1, Qnil, $3, $5, escape_Qundef($6));" do
        def_params("def m(a,*r,a2,&b); end",
                   f_arg, nil, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      specify "f_arg opt_f_block_arg => params_new($1, Qnil, Qnil, Qnil, escape_Qundef($2));" do
        def_params("def m(a,&b); end",
                   f_arg, nil, nil, nil, opt_f_block_arg)
      end

      specify "f_optarg ',' f_rest_arg opt_f_block_arg => params_new(Qnil, $1, $3, Qnil, escape_Qundef($4));" do
        def_params("def m(o=1,*r,&b); end",
                   nil, f_optarg, f_rest_arg, nil, opt_f_block_arg)
      end

      specify "f_optarg ',' f_rest_arg ',' f_arg opt_f_block_arg => params_new(Qnil, $1, $3, $5, escape_Qundef($6));" do
        def_params("def m(o=1,*r,a2,&b); end",
                   nil, f_optarg, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      specify "f_optarg opt_f_block_arg => params_new(Qnil, $1, Qnil, Qnil, escape_Qundef($2));" do
        def_params("def m(o=1,&b); end",
                   nil, f_optarg, nil, nil, opt_f_block_arg)
      end

      specify "f_optarg ',' f_arg opt_f_block_arg => params_new(Qnil, $1, Qnil, $3, escape_Qundef($4));" do
        def_params("def m(o=1,a2,&b); end",
                   nil, f_optarg, nil, f_arg2, opt_f_block_arg)
      end

      specify "f_rest_arg opt_f_block_arg => params_new(Qnil, Qnil, $1, Qnil,escape_Qundef($2));" do
        def_params("def m(*r,&b); end",
                   nil, nil, f_rest_arg, nil, opt_f_block_arg)
      end

      specify "f_rest_arg ',' f_arg opt_f_block_arg => params_new(Qnil, Qnil, $1, $3, escape_Qundef($4));" do
        def_params("def m(*r,a2,&b); end",
                   nil, nil, f_rest_arg, f_arg2, opt_f_block_arg)
      end

      specify "f_block_arg => params_new(Qnil, Qnil, Qnil, Qnil, $1);" do
        def_params("def m(&b); end",
                   nil, nil, nil, nil, opt_f_block_arg)
      end

      specify "/* none */ => params_new(Qnil, Qnil, Qnil, Qnil, Qnil);" do
        def_params("def m(); end",
                   nil, nil, nil, nil, nil)
      end
    end

    describe "assignment according to parse.y" do
      describe "lhs '=' command_call => dispatch2(assign, $1, $3);" do
        specify "constant to local variable" do
          "v = 1".should parse_as(:assign,
                                  [:var_field, {:ident=>"v"}],
                                  {:int=>"1"})
        end

        specify "result of method call to local variable" do
          "v = m()".should parse_as(:assign,
                                    [:var_field, {:ident=>"v"}],
                                    [:method_add_arg, [:fcall, {:ident=>"m"}], [:arg_paren, nil]])
        end

        specify "variable to local variable" do
          "v = v2".should parse_as(:assign,
                                   [:var_field, {:ident=>"v"}],
                                   [:var_ref, {:ident=>"v2"}])
        end
      end

      describe "mlhs '=' command_call => dispatch2(massign, $1, $3);" do
        specify "constants to multiple local variables" do
          "v1, v2 = 1, 2".should parse_as(:massign,
                                          [{:ident=>"v1"}, {:ident=>"v2"}],
                                          [:mrhs_new_from_args, [{:int=>"1"}], {:int=>"2"}])
        end

        specify "result ot method calls to multiple local variables" do
          "v1, v2 = m1, m2".should parse_as(:massign,
                                            [{:ident=>"v1"}, {:ident=>"v2"}],
                                            [:mrhs_new_from_args,
                                             [[:var_ref, {:ident=>"m1"}]],
                                             [:var_ref, {:ident=>"m2"}]])

          "v1, v2, v3 = m1, m2, m3".should parse_as(:massign,
                                                    [{:ident=>"v1"}, {:ident=>"v2"}, {:ident=>"v3"}],
                                                    [:mrhs_new_from_args,
                                                     [[:var_ref, {:ident=>"m1"}], [:var_ref, {:ident=>"m2"}]],
                                                     [:var_ref, {:ident=>"m3"}]])
        end

        specify "result ot star method calls to multiple local variables" do
          "v1, v2, v3 = *m".should parse_as(:massign,
                                            [{:ident=>"v1"}, {:ident=>"v2"}, {:ident=>"v3"}],
                                            [:mrhs_add_star, [], [:var_ref, {:ident=>"m"}]]) # command_call, value_expr
        end
      end

      describe "var_lhs tOP_ASGN command_call => dispatch3(opassign, $1, $2, $3);" do
        specify "operator assignment (like a += 1)" do
          "v += 1".should parse_as(:opassign,
                                   [:var_field, {:ident=>"v"}],
                                   {:op=>"+="}, # operator 
                                   {:int=>"1"}) # command_call
        end
      end

      specify "primary_value '[' opt_call_args rbracket tOP_ASGN command_call => \
               dispatch2(aref_field, $1, escape_Qundef($3)); dispatch3(opassign, $$, $5, $6);" do
        "v[1] += 1".should parse_as(:opassign,
                                    [:aref_field, # opt_call_args 
                                     [:var_ref, {:ident=>"v"}],
                                     [:args_add_block, [{:int=>"1"}], false]], # ?
                                    {:op=>"+="}, # operator
                                    {:int=>"1"}) # command_call
      end

      specify "primary_value '.' tIDENTIFIER tOP_ASGN command_call => \
               $$ = dispatch3(field, $1, ripper_id2sym('.'), $3); dispatch3(opassign, $$, $4, $5);" do
        "v.q += 1".should parse_as(:opassign,
                                   [:field,
                                    [:var_ref, {:ident=>"v"}], :".", {:ident=>"q"}],
                                   {:op=>"+="},
                                   {:int=>"1"})
      end

      specify "primary_value '.' tCONSTANT tOP_ASGN command_call => \
               $$ = dispatch3(field, $1, ripper_id2sym('.'), $3); dispatch3(opassign, $$, $4, $5);" do
        "v.C += 1".should parse_as(:opassign,
                                   [:field, [:var_ref, {:ident=>"v"}], :".", {:const=>"C"}],
                                   {:op=>"+="},
                                   {:int=>"1"})
      end

      specify "primary_value tCOLON2 tIDENTIFIER tOP_ASGN command_call =>\
               $$ = dispatch3(field, $1, ripper_intern('::'), $3); dispatch3(opassign, $$, $4, $5);" do
        "v::i += 1".should parse_as(:opassign,
                                    [:field, [:var_ref, {:ident=>"v"}], :"::", {:ident=>"i"}],
                                    {:op=>"+="},
                                    {:int=>"1"})
      end

      specify "lhs '=' mrhs => dispatch2(assign, $1, $3);" do
        "v::i += 1".should parse_as(:opassign,
                                    [:field, [:var_ref, {:ident=>"v"}], :"::", {:ident=>"i"}],
                                    {:op=>"+="},
                                    {:int=>"1"})
      end

      specify "result ot star method calls to multiple local variables (lhs '=' mrhs)" do
        "v1, v2, v3 = *m".should parse_as(:massign,
                                          [{:ident=>"v1"}, {:ident=>"v2"}, {:ident=>"v3"}],
                                          [:mrhs_add_star, [], [:var_ref, {:ident=>"m"}]]) # command_call, value_expr
      end

      specify "lhs '=' arg modifier_rescue arg => dispatch2(assign, $1, dispatch2(rescue_mod, $3, $5));" do
        "v = a rescue b".should parse_as(:assign,
                                         [:var_field, {:ident=>"v"}],
                                         [:rescue_mod, [:var_ref, {:ident=>"a"}], [:var_ref, {:ident=>"b"}]])
      end

      # assign(lhs, something)
    end

    describe "method calls" do
      specify "command" do
        "r 'f', &ba".should parse_as(:command,
                                     {:ident=>"r"},
                                     [:args_add_block,
                                      [[:string_literal, [:string_content, {:tstring_content=>"f"}]]],
                                      [:var_ref, {:ident=>"ba"}]])
      end

      specify "command with paren" do
        "r('f', &ba)".should parse_as(:method_add_arg,
                                      [:fcall, {:ident=>"r"}],
                                      [:arg_paren,
                                       [:args_add_block,
                                        [[:string_literal, [:string_content, {:tstring_content=>"f"}]]],
                                        [:var_ref, {:ident=>"ba"}]]])
      end

      specify "block_call '.' operation2 command_args" do
        "m do end.o(a).m(a)".should parse_as(:method_add_arg,
                                             [:call,
                                              [:method_add_arg,
                                               [:call,
                                                [:method_add_block,
                                                 [:method_add_arg, [:fcall, {:ident=>"m"}], []],
                                                 [:do_block, nil, [[:void_stmt]]]],
                                                :".",
                                                {:ident=>"o"}],
                                               [:arg_paren, [:args_add_block, [[:var_ref, {:ident=>"a"}]], false]]],
                                              :".",
                                              {:ident=>"m"}],
                                             [:arg_paren, [:args_add_block, [[:var_ref, {:ident=>"a"}]], false]])

      end

      specify "block_call tCOLON2 operation2 command_args" do
        "m1 do end::o(a)::m2(a)".should parse_as(:method_add_arg,
                                                 [:call,
                                                  [:method_add_arg,
                                                   [:call,
                                                    [:method_add_block,
                                                     [:method_add_arg, [:fcall, {:ident=>"m1"}], []],
                                                     [:do_block, nil, [[:void_stmt]]]],
                                                    :".",
                                                    {:ident=>"o"}],
                                                   [:arg_paren, [:args_add_block, [[:var_ref, {:ident=>"a"}]], false]]],
                                                  :".",
                                                  {:ident=>"m2"}],
                                                 [:arg_paren, [:args_add_block, [[:var_ref, {:ident=>"a"}]], false]])
      end

      describe "block_call :" do
        specify "command do_block" do
          "m do end".should parse_as(:method_add_block,
                                     [:method_add_arg, [:fcall, {:ident=>"m"}], []],
                                     [:do_block, nil, [[:void_stmt]]])
        end

        specify "block_call '.' operation2 opt_paren_args" do
          "m1 do end.m2(a)".should parse_as(:method_add_arg,
                                            [:call,
                                             [:method_add_block,
                                              [:method_add_arg, [:fcall, {:ident=>"m1"}], []],
                                              [:do_block, nil, [[:void_stmt]]]],
                                             :".",
                                             {:ident=>"m2"}],
                                            [:arg_paren, [:args_add_block, [[:var_ref, {:ident=>"a"}]], false]])
        end

        specify "block_call tCOLON2 operation2 opt_paren_args" do
          "m() { }::m(a)".should parse_as(:method_add_arg,
                                          [:call,
                                           [:method_add_block,
                                            [:method_add_arg, [:fcall, {:ident=>"m"}], [:arg_paren, nil]],
                                            [:brace_block, nil, [[:void_stmt]]]],
                                           :".",
                                           {:ident=>"m"}],
                                          [:arg_paren, [:args_add_block, [[:var_ref, {:ident=>"a"}]], false]])
        end

        specify "subclasses.each { }" do
          "subclasses.each { }".should parse_as(:method_add_block,
                                                [:call, [:var_ref, {:ident=>"subclasses"}], :".", {:ident=>"each"}],
                                                [:brace_block, nil, [[:void_stmt]]])
        end

        specify ":command_call event" do
          "A::B.c d unless 1".should parse_as(:unless_mod,
                                              {:int=>"1"},
                                              [:command_call,
                                               [:const_path_ref, [:var_ref, {:const=>"A"}], {:const=>"B"}],
                                               :".",
                                               {:ident=>"c"},
                                               [:args_add_block, [[:var_ref, {:ident=>"d"}]], false]])
        end

        specify ":command_call event" do
          "::B.c d unless 1".should parse_as(:unless_mod,
                                             {:int=>"1"},
                                             [:command_call,
                                              [:top_const_ref, {:const=>"B"}],
                                              :".",
                                              {:ident=>"c"},
                                              [:args_add_block, [[:var_ref, {:ident=>"d"}]], false]])
        end

        specify ":command_call event" do
          "a(c).c d unless 1".should parse_as(:unless_mod,
                                              {:int=>"1"},
                                              [:command_call,
                                               [:method_add_arg,
                                                [:fcall, {:ident=>"a"}],
                                                [:arg_paren, [:args_add_block, [[:var_ref, {:ident=>"c"}]], false]]],
                                               :".",
                                               {:ident=>"c"},
                                               [:args_add_block, [[:var_ref, {:ident=>"d"}]], false]])
        end

        pending "operation command_args cmd_brace_block" do
          # wrong!
#        	|
#		    {
#		    /*%%%*/
#			block_dup_check($2,$3);
#		        $3->nd_iter = NEW_FCALL($1, $2);
#			$$ = $3;
#			fixpos($$, $2);
#		    /*%
#			$$ = dispatch2(command, $1, $2);
#			$$ = method_add_block($$, $3);
#		    %*/
#		    }
          "q next i { 42 }".should parse_as(:command,
                                            {:const=>"C"},
                                            [[:next,
                                              [:args_add_block,
                                               [[:method_add_block,
                                                 [:method_add_arg, [:fcall, {:ident=>"i"}], []],
                                                 [:brace_block, nil, [{:int=>"42"}]]]],
                                               false]]])
        end

        pending "primary_value '.' operation2 command_args	%prec tLOWEST" do
#		| primary_value '.' operation2 command_args	%prec tLOWEST
#		    {
#		    /*%%%*/
#			$$ = NEW_CALL($1, $3, $4);
#			fixpos($$, $1);
#		    /*%
#			$$ = dispatch4(command_call, $1, ripper_id2sym('.'), $3, $4);
#		    %*/
#		    }
          "yield.pv.o(a)".should parse_as()
        end

#        specify "" do
#          "".should parse_as()
#        end

        pending "primary_value '.' operation2 command_args cmd_brace_block" do
#		| primary_value '.' operation2 command_args cmd_brace_block
#		    {
#		    /*%%%*/
#			block_dup_check($4,$5);
#		        $5->nd_iter = NEW_CALL($1, $3, $4);
#			$$ = $5;
#			fixpos($$, $1);
#		    /*%
#			$$ = dispatch4(command_call, $1, ripper_id2sym('.'), $3, $4);
#			$$ = method_add_block($$, $5);
#		    %*/
#		   }
          "".should parse_as(:void_stmt)
        end

        pending "primary_value tCOLON2 operation2 command_args	%prec tLOWEST" do
#		| primary_value tCOLON2 operation2 command_args	%prec tLOWEST
#		    {
#		    /*%%%*/
#			$$ = NEW_CALL($1, $3, $4);
#			fixpos($$, $1);
#		    /*%
#			$$ = dispatch4(command_call, $1, ripper_intern("::"), $3, $4);
#		    %*/
#		    }
          "".should parse_as(:void_stmt)
        end

        pending "primary_value tCOLON2 operation2 command_args cmd_brace_block" do
#		| primary_value tCOLON2 operation2 command_args cmd_brace_block
#		    {
#		    /*%%%*/
#			block_dup_check($4,$5);
#		        $5->nd_iter = NEW_CALL($1, $3, $4);
#			$$ = $5;
#			fixpos($$, $1);
#		    /*%
#			$$ = dispatch4(command_call, $1, ripper_intern("::"), $3, $4);
#			$$ = method_add_block($$, $5);
#		    %*/
#		   }
          "".should parse_as(:void_stmt)
        end
      end

      specify "primary		: literal" do
        "m!".should parse_as(:method_add_arg, [:fcall, {:ident=>"m!"}], [])
      end

      specify "| operation brace_block" do
        "m! { }".should parse_as(:method_add_block,
                                 [:method_add_arg, [:fcall, {:ident=>"m!"}], []],
                                 [:brace_block, nil, [[:void_stmt]]])
      end

      specify "" do
        "".should parse_as(:void_stmt)
      end

      specify "" do

#        else if (is_local_id(id)) {
#      if (dyna_in_block() && dvar_defined(id)) return NEW_DVAR(id);
#      if (local_id(id)) return NEW_LVAR(id);
#      /* method call without arguments */
#      return NEW_VCALL(id);
#        }
#        else if (is_global_id(id)) {
#      return NEW_GVAR(id);
#        }
#        else if (is_instance_id(id)) {
#      return NEW_IVAR(id);
#        }
#        else if (is_const_id(id)) {
#      return NEW_CONST(id);
#        }
#        else if (is_class_id(id)) {
#      return NEW_CVAR(id);
#        }

        # | var_lhs tOP_ASGN command_call
        #
        # may result in
        #   $$->nd_value = NEW_CALL(gettable(vid), $2, NEW_LIST($3));
        # while dispatching only
        #   $$ = dispatch3(opassign, $1, $2, $3);

        # | var_lhs tOP_ASGN arg
        # $$ = NEW_OP_ASGN_OR(gettable(vid), $1);

        # | var_lhs tOP_ASGN arg modifier_rescue arg
        # $$ = NEW_OP_ASGN_OR(gettable(vid), $1);

        #var_ref		: variable
        #		    {
        #		    /*%%%*/
        #			if( ! ($$ = gettable($1)) ) 
        #       $$ = NEW_BEGIN(0);
        #		    /*%
        #			$$ = dispatch1(var_ref, $1);
        #		    %*/
        #		    }
        #		;


#      | tUMINUS_NUM tINTEGER tPOW arg
#          {
#          /*%%%*/
#        $$ = NEW_CALL(call_bin_op($2, tPOW, $4), tUMINUS, 0);
#          /*%
#        $$ = dispatch3(binary, $2, ripper_intern("**"), $4);
#        $$ = dispatch2(unary, ripper_intern("-@"), $$);

#      | tUMINUS_NUM tFLOAT tPOW arg
#          {
#          /*%%%*/
#        $$ = NEW_CALL(call_bin_op($2, tPOW, $4), tUMINUS, 0);
#          /*%
#        $$ = dispatch3(binary, $2, ripper_intern("**"), $4);
#        $$ = dispatch2(unary, ripper_intern("-@"), $$);
#          %*/
#          }

#      | primary_value '[' opt_call_args rbracket
#          {
#          /*%%%*/
#        if ($1 && nd_type($1) == NODE_SELF)
#            $$ = NEW_FCALL(tAREF, $3);
#        else
#            $$ = NEW_CALL($1, tAREF, $3);
#        fixpos($$, $1);
#          /*%
#        $$ = dispatch2(aref, $1, escape_Qundef($3));
#          %*/
#          }

      end
    end

    describe "variable reference" do

    end
  end
end