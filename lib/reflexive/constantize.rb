module Reflexive
  module_function

  def constant_lookup(name, scope)
    if name =~ /^::/
      begin
        return Reflexive.constantize(name)
      rescue NameError, ArgumentError
        return nil
      end
    end

    scope_parts = scope.split("::")
    
    begin
      name_with_scope = "#{ scope_parts.join("::") }::#{ name }"
      return Reflexive.constantize(name_with_scope)
    rescue NameError, ArgumentError
      # For defined top-level module, when looked up from another class:
      # ArgumentError: Object is not missing constant TopLevelConst!
      #        from .../activesupport-2.3.5/lib/active_support/dependencies.rb:417:in `load_missing_constant'
      retry if scope_parts.pop
    end
    
    nil
  end

  # from C:\Users\work\Documents\ubuntu_shared\edge\vendor\rails\activesupport\lib\active_support\inflector\methods.rb
  # Ruby 1.9 introduces an inherit argument for Module#const_get and
  # #const_defined? and changes their default behavior.
  if Module.method(:const_get).arity == 1
    # Tries to find a constant with the name specified in the argument string:
    #
    #   "Module".constantize     # => Module
    #   "Test::Unit".constantize # => Test::Unit
    #
    # The name is assumed to be the one of a top-level constant, no matter whether
    # it starts with "::" or not. No lexical context is taken into account:
    #
    #   C = 'outside'
    #   module M
    #     C = 'inside'
    #     C               # => 'inside'
    #     "C".constantize # => 'outside', same as ::C
    #   end
    #
    # NameError is raised when the name is not in CamelCase or the constant is
    # unknown.
    def constantize(camel_cased_word)
      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end
  else
    def constantize(camel_cased_word) #:nodoc:
      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name, false) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end
  end
end
