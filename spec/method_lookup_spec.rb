require "reflexive/method_lookup"

class TestBaseClass
  def self.inherited_class_meth
  end

  def inherited_instance_meth
  end
end

class TestClass < TestBaseClass
  def initialize
  end
  
  def self.class_meth
  end

  def instance_meth
  end
end

module TestBaseModule
  def inherited_module_meth
  end
end

module TestModule
  include TestBaseModule
  
  def self.class_module_meth
  end

  def instance_module_meth
  end
end

class TestCoreMethodsCallingClass
  #  # Module is class
  #  # Module class
  #  Module.new
  #  Module.nesting
  #  Module.constants
  #
  #  # Module instance
  #  class_eval do
  #
  #  end
  #  # many more...
  #
  #  # Class class
  #  Class.inherited
  #  Class.new
  #
  #  # Class instance
  #  allocate
  #  new
  #  superclass
  #
  #  # Object instance
  #  Object.new # single
  #
  #  # Object instance
  #  clone
  #  dup
  #  freeze
  #
  #  # Kernel is module
  #  # Kernel instance
  #  Array
  #  caller
  #  # many more...
end

describe Reflexive::MethodLookup do
  def ml(*args)
    Reflexive::MethodLookup.new(*args)
  end

  def lookup_definitions(klass, level, name)
    Reflexive::MethodLookup.new(klass: klass, level: level, name: name).definitions
  end

  def lookup_documentations(klass, level, name)
    Reflexive::MethodLookup.new(klass: klass, level: level, name: name).documentations
  end

  it "requires :klass, :level, :name as constructor arguments" do
    proc { ml }.should raise_error(ArgumentError)
    proc { ml(klass: TestClass) }.should raise_error(ArgumentError)
    proc { ml(level: :instance) }.should raise_error(ArgumentError)
    proc { ml(name: :meth) }.should raise_error(ArgumentError)
    proc { ml(klass: TestClass, level: :class) }.should raise_error(ArgumentError)
    proc { ml(klass: TestClass, level: :class, name: "meth") }.should_not raise_error
  end

  it "finds defined inherited instance methods for class" do
    lookup_definitions(TestClass, :instance, :inherited_instance_meth).should ==
            [[TestClass, :instance, :inherited_instance_meth]]
  end

  it "handles level and module names passed as strings normalizing them to symbols" do
    lookup_definitions(TestClass, "instance", "inherited_instance_meth").should ==
            [[TestClass, :instance, :inherited_instance_meth]]
  end

  it "finds defined inherited instance methods for module" do
    lookup_definitions(TestModule, :instance, :inherited_module_meth).should ==
            [[TestModule, :instance, :inherited_module_meth]]
  end

  it "finds defined owned instance methods for class" do
    lookup_definitions(TestClass, :instance, :instance_meth).should ==
            [[TestClass, :instance, :instance_meth]]
  end

  it "finds defined owned instance methods for module" do
    lookup_definitions(TestModule, :instance, :instance_module_meth).should ==
            [[TestModule, :instance, :instance_module_meth]]
  end

  it "finds defined inherited class methods" do
    lookup_definitions(TestClass, :class, :inherited_class_meth).should ==
            [[TestClass, :class, :inherited_class_meth]]
  end

  it "finds defined owned class methods for class" do
    lookup_definitions(TestClass, :class, :class_meth).should ==
            [[TestClass, :class, :class_meth]]
  end

  it "finds defined owned class methods for module" do
    lookup_definitions(TestModule, :class, :class_module_meth).should ==
            [[TestModule, :class, :class_module_meth]]
  end

  it "redirects class new method to instance initialize for classes" do
    lookup_definitions(TestClass, :class, :new).should ==
            [[TestClass, :instance, :initialize]]
  end

  describe "lookup of core native methods" do
    it "for Kernel always redirects to instance methods" do
      lookup_documentations(TestClass, :class, :require).should ==
              [[Kernel, :instance, :require]]

      lookup_documentations(TestClass, :instance, :require).should ==
              [[Kernel, :instance, :require]]
    end

    it "for Module redirects to instance methods mostly" do
      lookup_documentations(TestClass, :class, :class_eval).should ==
              [[Module, :instance, :class_eval]]

      lookup_documentations(Module, :class, :nesting).should ==
              [[Module, :class, :nesting]]

#      lookup_documentations(TestClass, :instance, :require).should ==
#              [[Kernel, :instance, :require]]
    end

    it "for Class redirects to instance methods mostly" do
      lookup_documentations(TestClass, :class, :superclass).should ==
              [[Class, :instance, :superclass]]


#      lookup_documentations(TestClass, :instance, :require).should ==
#              [[Kernel, :instance, :require]]
    end

    class InheritedFromDir < Dir
    end

    it "doesn't handle normal library classes in a specific way" do
      lookup_documentations(File, :class, :expand_path).should ==
              [[File, :class, :expand_path]]
      lookup_documentations(Dir, :instance, :path).should ==
              [[Dir, :instance, :path]]
      lookup_documentations(InheritedFromDir, :instance, :path).should ==
              [[Dir, :instance, :path]]
      lookup_documentations(InheritedFromDir, :class, :entries).should ==
              [[Dir, :class, :entries]]
    end
  end

  describe "heuristic lookup" do

    describe "for just included module" do
      module JustIncludedModule
        def module_instance_meth
          instance_meth
        end
      end

      class IncludesJustIncludedModule
        include JustIncludedModule

        def instance_meth
          42
        end
      end

      class IncludesJustIncludedModuleAnother
        include JustIncludedModule

        def instance_meth
          43
        end
      end

      class IncludesJustIncludedModuleYetAnother
        include JustIncludedModule
      end

      it "should setup sane fixture" do
        IncludesJustIncludedModule.new.module_instance_meth.should == 42
        IncludesJustIncludedModuleAnother.new.module_instance_meth.should == 43
      end

      it "finds instance_meth" do
        lookup_definitions(JustIncludedModule, :instance, :instance_meth).should =~
                [[IncludesJustIncludedModule, :instance, :instance_meth],
                 [IncludesJustIncludedModuleAnother, :instance, :instance_meth]]
      end
    end

    describe "for module included in singleton class" do
      module JustIncludedInSingletonModule
        def module_class_meth
          class_meth
        end
      end

      class IncludesJustIncludedInSingletonModule
        extend JustIncludedInSingletonModule

        def self.class_meth
          42
        end
      end

      it "should setup sane fixture" do
        IncludesJustIncludedInSingletonModule.module_class_meth.should == 42
      end

      it "finds class_meth" do
        lookup_definitions(JustIncludedInSingletonModule, :instance, :class_meth).should ==
                [[IncludesJustIncludedInSingletonModule, :class, :class_meth]]
      end
    end

    describe "for module included in module included in class in turn" do
      module IncludedInModuleIncludedInClass
        def module_instance_meth
          class_instance_meth
        end
      end

      module IncludesIncludedInModuleIncludedInClass
        include IncludedInModuleIncludedInClass
      end

      class IncludesIncludesIncludedInModuleIncludedInClass
        include IncludesIncludedInModuleIncludedInClass
        def class_instance_meth
          42
        end
      end

      it "should setup sane fixture" do
        IncludesIncludesIncludedInModuleIncludedInClass.new.module_instance_meth.should == 42
      end

      it "finds class_instance_meth" do
        lookup_definitions(IncludedInModuleIncludedInClass, :instance, :class_instance_meth).should ==
                [[IncludesIncludesIncludedInModuleIncludedInClass, :instance, :class_instance_meth]]
      end
    end

    describe "for base class instance methods" do
      class HeuristicLookupBaseClassInstanceMethods
        def base_class_instance_meth
          inherited_class_instance_meth
        end
      end

      class HeuristicLookupInheritedClassInstanceMethods < HeuristicLookupBaseClassInstanceMethods
        def inherited_class_instance_meth
          42
        end
      end

      class HeuristicLookupInheritedClassInstanceMethodsAnother < HeuristicLookupBaseClassInstanceMethods
        def inherited_class_instance_meth
          43
        end
      end

      it "should setup sane fixture" do
        HeuristicLookupInheritedClassInstanceMethods.new.base_class_instance_meth.should == 42
      end

      it "finds inherited_class_instance_meth" do
        lookup_definitions(HeuristicLookupBaseClassInstanceMethods, :instance, :inherited_class_instance_meth).should =~
                [[HeuristicLookupInheritedClassInstanceMethods, :instance, :inherited_class_instance_meth],
                 [HeuristicLookupInheritedClassInstanceMethodsAnother, :instance, :inherited_class_instance_meth]]
      end
    end

    describe "for base class class methods" do
      class HeuristicLookupBaseClassClassMethods
        def self.base_class_class_meth
          inherited_class_class_meth
        end
      end

      class HeuristicLookupInheritedClassClassMethods < HeuristicLookupBaseClassClassMethods
        def self.inherited_class_class_meth
          42
        end
      end

      it "should setup sane fixture" do
        HeuristicLookupInheritedClassClassMethods.base_class_class_meth.should == 42
      end

      it "finds inherited_class_class_meth" do
        lookup_definitions(HeuristicLookupBaseClassClassMethods, :class, :inherited_class_class_meth).should ==
                [[HeuristicLookupInheritedClassClassMethods, :class, :inherited_class_class_meth]]
      end
    end

    describe "last resort lookup" do
      module LastResortTestModule
      end

      class LastResortTestClass
        def some_really_uniq_instance_method
        end
      end

      it "finds some_really_uniq_instance_method" do
        lookup_definitions(LastResortTestModule, :instance, :some_really_uniq_instance_method).should ==
                [[LastResortTestClass, :instance, :some_really_uniq_instance_method]]
      end
    end
  end
end

