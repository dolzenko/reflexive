require "reflexive/core_ext/kernel/singleton_class"

module Reflexive
  class Methods
    def initialize(klass_or_module, options = {})
      @klass_or_module = klass_or_module
      @ancestor_name_formatter = options.fetch(:ancestor_name_formatter,
                                               default_ancestor_name_formatter)
      @exclude_trite = options.fetch(:exclude_trite, true)
    end

    def all
      @all ||= find_all
    end

    def files
      @files ||= find_all_files
    end

    def constants
      @constants ||= @klass_or_module.constants(true).map do |c|
        @klass_or_module.const_get(c) rescue nil
      end.compact.select do |c|
        c.instance_of?(Class) || c.instance_of?(Module)
      end # rescue r(@klass_or_module.constants)
    end

    def descendants
      @descendants ||= Reflexive.descendants(@klass_or_module)
    end

    VISIBILITIES = [ :public, :protected, :private ].freeze

    protected

    def each_immediate_class_and_instance_method(&block)
      VISIBILITIES.each do |visibility|
        [ @klass_or_module, @klass_or_module.singleton_class ].each do |klass|
          methods = klass.send("#{ visibility }_instance_methods", false)
          methods.each { |m| block.call(klass.instance_method(m)) }
        end
      end
    end

    def find_all_files
      source_locations = []
      each_immediate_class_and_instance_method do |meth|
        if location = meth.source_location
          source_locations << location[0] unless source_locations.include?(location[0])
        end
      end
      source_locations
    end

    def default_ancestor_name_formatter
      proc do |ancestor, singleton|
        ancestor_name(ancestor, singleton)
      end
    end
  
    def find_all
      ancestors = [] # flattened ancestors (both normal and singleton)

      (@klass_or_module.ancestors - trite_ancestors).each do |ancestor|
        ancestor_singleton = ancestor.singleton_class

        # Modules don't inherit class methods from included modules
        unless @klass_or_module.instance_of?(Module) && ancestor != @klass_or_module
          class_methods = collect_instance_methods(ancestor_singleton)
        end

        instance_methods = collect_instance_methods(ancestor)

        append_ancestor_entry(ancestors, @ancestor_name_formatter[ancestor, false],
                              class_methods, instance_methods)

        (singleton_ancestors(ancestor) || []).each do |singleton_ancestor|
          class_methods = collect_instance_methods(singleton_ancestor)
          append_ancestor_entry(ancestors, @ancestor_name_formatter[singleton_ancestor, true],
                                class_methods)
        end
      end

      ancestors
    end

    # singleton ancestors with ancestor introduced
    def singleton_ancestors(ancestor)
      @singleton_ancestors ||= all_singleton_ancestors
      @singleton_ancestors[ancestor]
    end

    def all_singleton_ancestors
      all = {}
      seen = []
      (@klass_or_module.ancestors - trite_ancestors).reverse.each do |ancestor|
        singleton_ancestors = ancestor.singleton_class.ancestors - trite_singleton_ancestors
        introduces = singleton_ancestors - seen
        all[ancestor] = introduces unless introduces.empty?
        seen.concat singleton_ancestors
      end
      all
    end

    def ancestor_name(ancestor, singleton)
      "#{ singleton ? "S" : ""}[#{ ancestor.is_a?(Class) ? "C" : "M" }] #{ ancestor.name || ancestor.to_s }"
    end

    # ancestor is included only when contributes some methods
    def append_ancestor_entry(ancestors, ancestor, class_methods, instance_methods = nil)
      if class_methods || instance_methods
        ancestor_entry = {}
        ancestor_entry[:class] = class_methods if class_methods
        ancestor_entry[:instance] = instance_methods if instance_methods
        ancestors << {ancestor => ancestor_entry}
      end
    end

    # Returns hash { :public => [...public methods...],
    #                :protected => [...private methods...],
    #                :private => [...private methods...] }
    # keys with empty values are excluded,
    # when no methods are found - returns nil
    def collect_instance_methods(klass)
      methods_with_visibility = VISIBILITIES.map do |visibility|
        methods = klass.send("#{ visibility }_instance_methods", false)
        [visibility, methods] unless methods.empty?
      end.compact
      Hash[methods_with_visibility] unless methods_with_visibility.empty?
    end

    def trite_singleton_ancestors
      return [] unless @exclude_trite
      @trite_singleton_ancestors ||= Class.new.singleton_class.ancestors
    end

    def trite_ancestors
      return [] unless @exclude_trite
      @trite_ancestors ||= Class.new.ancestors
    end
  end
end