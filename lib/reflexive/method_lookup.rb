require "reflexive/constantize"

module Reflexive
  class MethodLookup
    def initialize(options)
      unless (@klass, @level, @name = options.values_at(:klass, :level, :name)).all?
        raise ArgumentError, "must pass :klass, :level, :name as named arguments"
      end
      @level, @name = @level.to_sym, @name.to_sym
    end

    def definitions
      lookup unless @lookup_done
      @definitions
    end

    def documentations
      lookup unless @lookup_done
      @documentations
    end

    private

    def lookup
      begin
        defined_method_lookup
      rescue NameError => e
        # don't swallow NameError if it's not related to the method we're looking for
        raise unless e.message.include?(@name.to_s)
        heuristic_lookup
        last_resort_lookup unless lookup_succeed?
      end
      @lookup_done = true
    end

    def lookup_succeed?
      @definitions && @definitions.size > 0 ||
              @documentations && @documentations.size > 0
    end

    def defined_method_lookup
      unbound_method = @klass.send(method_getter, @name)
      if unbound_method.source_location
        @definitions = [[@klass, @level, @name]]
      elsif @klass.instance_of?(Class) && @level == :class && @name == :new &&
              (@klass.instance_method(:initialize).source_location rescue false)
        @definitions = [[@klass, :instance, :initialize]]
      elsif core_klass = unbound_method.owner
        if core_klass == Kernel
          @documentations = [[Kernel, :instance, @name]]
        elsif core_klass == Module || core_klass.to_s == "#<Class:Module>"
          if (Module.methods(false) + Module.private_methods(false)).include?(@name)
            @documentations = [[Module, :class, @name]]
          else
            @documentations = [[Module, :instance, @name]]
          end
        elsif core_klass == Class
          if (Class.methods(false) + Class.private_methods(false)).include?(@name)
            @documentations = [[Class, :class, @name]]
          else
            @documentations = [[Class, :instance, @name]]
          end
        else
          if @level == :class
            if core_klass == @klass
              @documentations = [[core_klass, :class, @name]]
            elsif core_klass.to_s =~ /^#<Class:(.+)>$/
              # get class from singleton class
             @documentations = [[Reflexive.constantize($1), :class, @name]]
            end
          else
            @documentations = [[core_klass, @level, @name]]
          end
        end
      end
    end

    def heuristic_lookup
      if @klass.instance_of?(Module) && @level == :instance
        # only instance methods are inherited from modules
        potential_receivers = included_by_classes.select do |included_by_class|
          all_instance_methods(included_by_class).include?(@name)
        end

        potential_receivers += included_by_modules.select do |included_by_module|
          all_instance_methods(included_by_module).include?(@name)
        end

        potential_receivers.uniq.each do |receiver|
          # TODO heuristic lookup shouldn't assume that found method is not core method
          (@definitions ||= []) << [receiver, :instance, @name]
        end

        potential_class_receivers = included_by_singleton_classes.select do |included_by_singleton_class|
          all_class_methods(included_by_singleton_class).include?(@name)
        end

        potential_class_receivers.uniq.each do |class_receiver|
          (@definitions ||= []) << [class_receiver, :class, @name]
        end
      elsif @klass.instance_of?(Class)
        # both instance and class methods are inherited by classes

        potential_receivers = inherited_by_classes.select do |inherited_by_class|
          all_level_methods(inherited_by_class).include?(@name)
        end

        potential_receivers.uniq.each do |receiver|

          (@definitions ||= []) << [receiver, @level, @name]
        end
      end
    end

    def last_resort_lookup
      seen = []
      [Module, Class].each do |module_or_class|
        ObjectSpace.each_object(module_or_class) do |m|
          next if seen.include?(m)
          if all_instance_methods(m).include?(@name)
            (@definitions ||= []) << [m, :instance, @name]
          end
          if all_class_methods(m).include?(@name)
            (@definitions ||= []) << [m, :class, @name]
          end
          seen << m
        end
      end
    end

    def all_instance_methods(klass)
      klass.instance_methods(false) + klass.private_instance_methods(false)
    end

    def all_class_methods(klass)
      klass.methods(false) + klass.private_methods(false)
    end

    def all_level_methods(klass)
      @level == :instance ? all_instance_methods(klass) : all_class_methods(klass)
    end

    def included_by_classes
      included_by = []
      ObjectSpace.each_object(Class) do |c|
        next if c == @klass

        ancestors = c.ancestors
        included_by << c if ancestors.include?(@klass)
      end
      included_by
    end

    alias inherited_by_classes included_by_classes

    def included_by_modules
      included_by = []
      ObjectSpace.each_object(Module) do |m|
        next if m == @klass

        ancestors = m.ancestors
        included_by << m if ancestors.include?(@klass)
      end
      included_by
    end

    def included_by_singleton_classes
      included_by = []
      ObjectSpace.each_object(Class) do |c|
        next if c == @klass

        ancestors = c.singleton_class.ancestors
        included_by << c if ancestors.include?(@klass)
      end
      included_by
    end

    def method_getter
      @level == :instance ? :instance_method : :method
    end

    def methods_getter
      @level == :instance ? :instance_methods : :methods
    end

    def reverse_methods_getter
      @level == :instance ? :methods : :instance_methods
    end

    def reverse_level
      @level == :instance ? :class : :instance
    end
  end
end