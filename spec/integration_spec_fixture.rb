require "ostruct"

module IntegrationSpecFixture
  module TestBaseModule
  end

  module TestModule
    include TestBaseModule
    def module_meth
    end

    def self.module_class_meth
    end
  end

  class TestBaseClass
    def inherited_meth
    end

    def self.inherited_class_meth
    end

    def self.another_inherited_class_meth
    end
  end

  class TestClass < TestBaseClass
    include TestModule

    another_inherited_class_meth
    
    def self.class_meth
      inherited_class_meth
    end
    
    def public_meth
      inherited_meth
    end

    class_eval do
    end

    protected
    def protected_meth
      local_var = 42
      another_local_var = 42 + local_var
      not_defined_meth
    end

    private
    def private_meth
    end

    class NestedClass
      def meth
      end
    end
  end

  module HeuristicLookupBaseModule
  end

  class HeuristicLookupIncludingClass1
    include HeuristicLookupBaseModule
    def meth
    end
  end

  class HeuristicLookupIncludingClass2
    include HeuristicLookupBaseModule
    def meth
    end
  end

  class HeuristicLookupBaseClass
  end

  class HeuristicLookupInheritingClass1 < HeuristicLookupBaseClass
    def meth
    end
  end

  class HeuristicLookupInheritingClass2 < HeuristicLookupBaseClass 
    def meth
    end
  end
end