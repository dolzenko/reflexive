require "zlib"
require "reflexive/variables_scope"

module Reflexive
  class ParseTreeTopDownWalker
    def initialize(events_tree)
      @events_tree = events_tree
      @local_variables = []
      @dynamic_variables = []
      @variables_scope_id = 1
      VariablesScope.reset_guid
      # empty - top level
      # ["Module", "Class"] - class Class in module Module, class dev level
      # ["Module", "Class", :instance] - class Class in module Module, instance level
      @scope = [] # @scope.last - is basically "implicit self"
      # also used for constant lookup
    end

    def push_namespace_scope(namespace_name)
      @scope << namespace_name
    end

    def push_namespace_instance_scope
      @scope << :instance
    end

    def pop_namespace_scope
      @scope.pop
    end

    def current_variables_scope
      (@dynamic_variables.size > 0 ? @dynamic_variables : @local_variables).last
    end

    def add_local_variable(scanner_event)
      current_variables_scope.merge!(scanner_event[:ident] => scanner_event)
      local_variable_assignment(scanner_event)
    end

    def variables_scope
      merged_scope = @dynamic_variables.dup.reverse
      merged_scope << @local_variables.last if @local_variables.size > 0
      merged_scope
    end

    # TODO crazy, replace that with something more appropriate
    def variables_scope_id
      current_variables_scope.guid
    end

    def local_variable_defined?(name)
      variables_scope.any? { |variables| variables.has_key?(name) }
    end

    def local_variable_scope_id(name)
      variables_scope.detect { |variables| variables.has_key?(name) }.guid
    end

    def add_local_variables_from_lhs(lhs_event)
      # [:var_field, {:ident=>"v1"}]
      if lhs_event[0] == :var_field
        if (scanner_event = lhs_event[1]).is_a?(Hash)
          if scanner_event[:ident]
            add_local_variable(scanner_event)
          end
        end
      end
      # raise "don't know how to add local variables from lhs_event : #{ lhs_event }"
    end

    def add_local_variables_from_mlhs(mlhs_event)
      # [{:ident=>"a"}, {:ident=>"b"}],
      if mlhs_event.is_a?(Array)
        if mlhs_event[0] == :mlhs_add_star
          add_local_variables_from_mlhs(mlhs_event[1])
          add_local_variable(mlhs_event[2]) if mlhs_event[2][:ident]
          add_local_variables_from_mlhs(mlhs_event[3]) if mlhs_event[3].is_a?(Array)
        else
          mlhs_event.each do |event|
            next unless scanner_event?(event)
            if event[:ident]
              add_local_variable(event)
            end
          end
        end
      end
      # raise "don't know how to add local variables from lhs_event : #{ lhs_event }"
    end

    def add_local_variables_from_params_event(params_event)
      return unless params_event
      params_event = params_event[1] if params_event[0] == :paren # ?
      found = false

      if options_arguments = params_event[2]
        options_arguments.each do |optional_argument|
          if scanner_event?(event = optional_argument[0])
            add_local_variable(event)
            keep_walking(optional_argument[1..-1])
          end
        end
      end

      for scanner_event in extract_scanner_events_from_tree(params_event.values_at(1,3,4,5))
        if scanner_event[:ident]
          found = true
          add_local_variable(scanner_event)
        end
      end
      # raise "don't know how to add local variables from params_event: #{ params_event }" unless found
    end

    def extract_scanner_events_from_tree(tree)
      tree.flatten.select { |e| scanner_event?(e) }
    end

    def push_local_variables_context
      @local_variables << VariablesScope.new
    end

    def pop_local_variables_context
      @local_variables.pop
    end

    def push_dynamic_variables_context
      @dynamic_variables << VariablesScope.new
    end

    def pop_dynamic_variables_context
      @dynamic_variables.pop
    end

    def walk(event = @events_tree)
      type, *args = event
      if respond_to?("on_#{ type }")
        send("on_#{ type }", *args) #rescue r($!, event)
      else
        on_default(type, args)
      end
    end

    def on_default(type, event_args)
      return unless event_args # no-args event
      event_args.each do |arg|
        if arg == nil
          # empty arg - pass

          # why the following isn't reported with scanner events?
        elsif type == :call && [:".", :"::"].include?(arg)
        elsif type == :var_ref && [:".", :"::"].include?(arg)
        elsif type == :field && [:".", :"::"].include?(arg)
        elsif type == :command_call && ([:".", :"::"].include?(arg) || arg == false)
        elsif type == :args_add_block && arg == false
        elsif type == :unary && arg.is_a?(Symbol)
        elsif type == :binary && arg.is_a?(Symbol)
        elsif scanner_event?(arg)
          # scanner event - pass
        elsif (parser_events?(arg) rescue r(type, event_args))
          arg.each do |event|
            walk(event)
          end
        elsif parser_event?(arg)
          walk(arg)
        end
      end
    end

    def keep_walking(*args)
      on_default(nil, args)
    end

    def on_program(body)
      push_local_variables_context
      keep_walking(body)
      pop_local_variables_context
    end

    def on_def(name, params, body)
      push_local_variables_context
      # TODO this is hack :(
      push_namespace_instance_scope unless @in_singleton_class_defition
      add_local_variables_from_params_event(params)
      keep_walking(body)
      pop_namespace_scope unless @in_singleton_class_defition
      pop_local_variables_context
    end

    def on_defs(target, period, name, params, body)
      push_local_variables_context
      add_local_variables_from_params_event(params)
      keep_walking(body)
      pop_local_variables_context
    end

    def on_class(name, ancestor, body)
      keep_walking(name, ancestor)
      push_local_variables_context
      push_namespace_scope(resolve_constant_ref(name))
      keep_walking(body)
      pop_namespace_scope
      pop_local_variables_context
    end

    def on_sclass(target, body)
      push_local_variables_context
      @in_singleton_class_defition = true
      keep_walking(body)
      @in_singleton_class_defition = false
      pop_local_variables_context
    end

    def on_module(name, body)
      keep_walking(name)
      push_local_variables_context
      push_namespace_scope(resolve_constant_ref(name))
      keep_walking(body)
      pop_namespace_scope
      pop_local_variables_context
    end

    def on_do_block(params, body)
      push_dynamic_variables_context
      add_local_variables_from_params_event(params)
      keep_walking(body)
      pop_dynamic_variables_context
    end

    def on_brace_block(params, body)
      push_dynamic_variables_context
      add_local_variables_from_params_event(params)
      keep_walking(body)
      pop_dynamic_variables_context
    end

    def on_assign(lhs, rhs)
      add_local_variables_from_lhs(lhs)
      keep_walking(rhs)
    end

    def on_massign(mlhs, mrhs)
      add_local_variables_from_mlhs(mlhs)
      keep_walking(mrhs)
    end

    def on_command(operation, command_args)
      method_call(operation, nil) if is_ident?(operation)
      if operation[:ident] == "autoload" &&
              (arguments = resolve_arguments(command_args))

        if [:const, :tstring_content].include?(arguments[0].keys.first)
          constant_access(arguments[0], arguments[0].values.first)
        end
      end
      keep_walking(command_args)
    end

    def resolve_arguments(arguments)
      arguments = arguments[1] if arguments[0] == :arg_paren
      if arguments[0] == :args_add_block
        if arguments[1].is_a?(Array)
          arguments[1].map { |a| resolve_argument(a) }
        end
      end
    end

    def resolve_argument(argument)
      if argument[0] == :symbol_literal
        # [:symbol_literal, [:symbol, {:const=>"C"}]]
        if argument[1].is_a?(Array)
          if argument[1][0] == :symbol
            argument[1][1] # {:const=>"C"}
          end
        end
      elsif argument[0] == :string_literal
        # [:string_literal, [:string_content, {:tstring_content=>"C"}]]
        if argument[1].is_a?(Array)
          if argument[1][0] == :string_content
            argument[1][1] # {:tstring_content=>"C"}
          end
        end
      end
    end

    def on_fcall(operation)
      method_call(operation, nil) if is_ident?(operation)
    end

    def on_method_add_arg(method, arguments)

      if method[0] == :fcall &&
              scanner_event?(method[1]) &&
              method[1][:ident] == "autoload"
        if arguments = resolve_arguments(arguments)
          if [:const, :tstring_content].include?(arguments[0].keys.first)
            constant_access(arguments[0], arguments[0].values.first)
          end
        end
      end
      keep_walking(method, arguments)
    end

    # primary_value => anything
    # operation2	: tIDENTIFIER
    #		| tCONSTANT
    #		| tFID
    #		| op
    #		;
    # command_args => anything
    def on_command_call(receiver, dot, method, args)
      if is_ident?(method) &&
              (constant = resolve_constant_ref(receiver))
        method_call(method, [constant])
      end
      keep_walking(receiver, args)
    end

    def resolve_constant_ref(events)
      if events[0] == :var_ref || events[0] == :const_ref &&
              scanner_event?(events[1]) &&
              events[1][:const]
        events[1][:const]
      elsif events[0] == :top_const_ref &&
              scanner_event?(events[1]) &&
              events[1][:const]
        "::" + events[1][:const]
      elsif events[0] == :const_path_ref &&
              (constant = resolve_constant_ref(events[1]))
        "#{ constant }::#{ events[2][:const] }"
      end
    end

    def resolve_receiver(receiver)
      resolve_constant_ref(receiver)
    end

    #  [:call,
    #             [:var_ref, {:ident=>"subclasses"}]
    def on_call(receiver, dot, method)
      if rcv = resolve_receiver(receiver)
        method_call(method, [rcv])
      end
       
      keep_walking(receiver)
    end

    def on_var_ref(ref_event)
      # [:var_ref, {:kw=>"false"}]
      # [:var_ref, {:cvar=>"@@subclasses"}]
      # [:var_ref, {:ident=>"child"}] (sic!)
      #   [:binary,
#                 [:var_ref, {:ident=>"nonreloadables"}],
#                 :<<,
#                 [:var_ref, {:ident=>"klass"}]
      #
      #[:call,
#                 [:var_ref, {:ident=>"klass"}],
#                 :".",
#                 {:ident=>"instance_variables"}],
      #
      #
      if scanner_event?(ref_event)
        if ref_event[:ident]
          if local_variable_defined?(ref_event[:ident])
            local_variable_access(ref_event)
          else
            method_call(ref_event, nil)
          end
        elsif ref_event[:const]
          constant_access(ref_event)
        end
      end
    end

    def on_const_ref(const_ref_event)
      if scanner_event?(const_ref_event)
        if const_ref_event[:const]
          constant_access(const_ref_event)
        end
      end
    end

    def on_const_path_ref(primary_value, name)
      keep_walking(primary_value)
      if (constant = resolve_constant_ref(primary_value)) &&
              scanner_event?(name) && name[:const]
        constant_access(name, "#{ constant }::#{ name[:const] }")
      end
    end

    def method_call(scanner_event, receiver, *args)
      unless receiver
        # implict self concept (will be fetched from constant_access_scope)
        receiver = @scope.last == :instance ? :instance : :class
      end
      merge_tags(scanner_event,
                 {:method_call =>
                         {:name => scanner_event[:ident],
                          :receiver => receiver,
                          :scope => constant_access_scope}})
    end

    def local_variable_access(scanner_event)
      existing_variable_id = "#{ local_variable_scope_id(scanner_event[:ident]) }:#{ scanner_event[:ident] }"
      merge_tags(scanner_event,
                 :local_variable_access => existing_variable_id )
    end

    def constant_access_scope
      scope = @scope.dup
      scope.pop if scope.last == :instance # class/instance doesn't matter for constant lookup
      scope
    end

    def constant_access(scanner_event, name = nil)
      unless name
        name = scanner_event[:const]
      end
      merge_tags(scanner_event,
                 :constant_access => { :name => name,
                                       :scope => constant_access_scope })
    end

    def local_variable_assignment(scanner_event)
      merge_tags(scanner_event,
                 :local_variable_assignment => variable_id(scanner_event))
    end    

    def variable_id(scanner_event)
      "#{ variables_scope_id }:#{ scanner_event[:ident] }"
    end

    def merge_tags(scanner_event, tags)
      scanner_event[:tags] ||= {}
      scanner_event[:tags].merge!(tags)
    end

    def scanner_event?(event)
      event.is_a?(Hash)
    end

    def parser_event?(event)
      event.is_a?(Array) && event[0].is_a?(Symbol)
    end

    def parser_events?(events)
      events.all? { |event| parser_event?(event) }
    end

    def is_ident?(event)
      scanner_event?(event) && event[:ident]
    end
  end
end