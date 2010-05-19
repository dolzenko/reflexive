require "reflexive/methods"

Rspec::Matchers.define :generate_methods do |expected|
  match do |actual|
    Reflexive::Methods.new(actual).all == eval(expected)
  end

  failure_message_for_should do |actual|
    require "pp"
    require "stringio"
    pp_out = StringIO.new
    PP.pp(Reflexive::Methods.new(actual).all, pp_out)
    "expected:\n#{ expected }\ngot:\n#{ pp_out.string }"
  end
end

describe "Ruby reflection capabilities" do
  describe "for Modules" do
    describe "#singleton_class" do
      specify ".public_instance_methods(false) returns empty list for empty module" do
        Module.new.singleton_class.
                reflexive_public_instance_methods(false).should == []
      end

      specify ".protected_instance_methods(false) returns empty list for empty module" do
        Module.new.singleton_class.
                reflexive_protected_instance_methods(false).should == []
      end

      specify ".private_instance_methods(false) returns empty list for empty module" do
        Module.new.singleton_class.
                reflexive_private_instance_methods(false).should == []
      end

      specify ".public_instance_methods(false) returns public methods" do
        Module.new { def self.m; end }.singleton_class.
                reflexive_public_instance_methods(false).should == [:m]
      end

      specify ".protected_instance_methods(false) returns protected methods" do
        Module.new { class << self; protected; def m; end end }.singleton_class.
                reflexive_protected_instance_methods(false).should == [:m]
      end

      specify ".private_instance_methods(false) returns private methods" do
        Module.new { class << self; private; def m; end end }.singleton_class.
                reflexive_private_instance_methods(false).should == [:m]
      end
    end

    specify ".public_instance_methods(false) returns empty list for empty module" do
      Module.new.
              reflexive_public_instance_methods(false).should == []
    end

    specify ".protected_instance_methods(false) returns empty list for empty module" do
      Module.new.
              reflexive_protected_instance_methods(false).should == []
    end

    specify ".private_instance_methods(false) returns empty list for empty module" do
      Module.new.
              reflexive_private_instance_methods(false).should == []
    end

    specify ".public_instance_methods(false) returns public methods" do
      Module.new { def m; end }.
              reflexive_public_instance_methods(false).should == [:m]
    end

    specify ".protected_instance_methods(false) returns protected methods" do
      Module.new { protected; def m; end }.
              reflexive_protected_instance_methods(false).should == [:m]
    end

    specify ".private_instance_methods(false) returns private methods" do
      Module.new { private; def m; end }.
              reflexive_private_instance_methods(false).should == [:m]
    end
  end

  describe "for Classes" do
    class ::RubyReflectionCapabilitiesEmptyClass
    end

    class ::RubyReflectionCapabilitiesSingletonMethodsClass
      class << self
        def publ
        end
        protected
        def prot
        end
        private
        def priv
        end
      end
    end

    class ::RubyReflectionCapabilitiesInstanceMethodsClass
      def publ
      end
      protected
      def prot
      end
      private
      def priv
      end
    end

    describe "#singleton_class" do
      specify ".public_instance_methods(false) returns empty list for empty class" do
        RubyReflectionCapabilitiesEmptyClass.singleton_class.
                reflexive_public_instance_methods(false).should == []
      end

      specify ".protected_instance_methods(false) returns empty list for empty class" do
        RubyReflectionCapabilitiesEmptyClass.singleton_class.
                reflexive_protected_instance_methods(false).should == []
      end

      specify ".private_instance_methods(false) returns empty list for empty class" do
        RubyReflectionCapabilitiesEmptyClass.singleton_class.
                reflexive_private_instance_methods(false).should == []
      end

      specify ".public_instance_methods(false) returns public methods" do
        RubyReflectionCapabilitiesSingletonMethodsClass.singleton_class.
                reflexive_public_instance_methods(false).should == [:publ]
      end

      specify ".protected_instance_methods(false) returns protected methods" do
        RubyReflectionCapabilitiesSingletonMethodsClass.singleton_class.
                reflexive_protected_instance_methods(false).should == [:prot]
      end

      specify ".private_instance_methods(false) returns private methods" do
        RubyReflectionCapabilitiesSingletonMethodsClass.singleton_class.
                reflexive_private_instance_methods(false).should == [:priv]
      end
    end

    describe "#" do
      specify ".public_instance_methods(false) returns empty list for empty class" do
        RubyReflectionCapabilitiesEmptyClass.
                reflexive_public_instance_methods(false).should == []
      end

      specify ".protected_instance_methods(false) returns empty list for empty class" do
        RubyReflectionCapabilitiesEmptyClass.
                reflexive_protected_instance_methods(false).should == []
      end

      specify ".private_instance_methods(false) returns empty list for empty class" do
        RubyReflectionCapabilitiesEmptyClass.
                reflexive_private_instance_methods(false).should == []
      end

     specify ".public_instance_methods(false) returns public methods" do
        RubyReflectionCapabilitiesInstanceMethodsClass.
                reflexive_public_instance_methods(false).should == [:publ]
      end

      specify ".protected_instance_methods(false) returns protected methods" do
        RubyReflectionCapabilitiesInstanceMethodsClass.
                reflexive_protected_instance_methods(false).should == [:prot]
      end

      specify ".private_instance_methods(false) returns private methods" do
        RubyReflectionCapabilitiesInstanceMethodsClass.
                reflexive_private_instance_methods(false).should == [:priv]
      end
    end
  end
end

describe Reflexive::Methods do
  describe "#trite_singleton_ancestors" do
    it "returns some common trite objects" do
      Reflexive::Methods.new(nil).
              send(:trite_singleton_ancestors).
              should(include(Class, Module, Object, BasicObject, Kernel))
    end
  end

  describe "#trite_ancestors" do
    it "returns some common trite objects" do
      Reflexive::Methods.new(nil).
              send(:trite_ancestors).
              should(include(Object, Kernel, BasicObject))
    end
  end

  describe "#collect_instance_methods" do
    class ::CollectInstanceMethodsC
      def public_instance_meth
      end
      protected
      def protected_instance_meth
      end
      private
      def private_instance_meth
      end
    end
    
    it "collects own (defined in class) instance methods for class" do
      Reflexive::Methods.new(nil).
              send(:collect_instance_methods, ::CollectInstanceMethodsC).
              should == { :public => [ :public_instance_meth ],
                          :protected => [ :protected_instance_meth ],
                          :private => [ :private_instance_meth ] }
    end

    module ::CollectInstanceMethodsEmptyM
    end

    it "reports empty own instance methods for empty module" do
      Reflexive::Methods.new(nil).
              send(:collect_instance_methods, ::CollectInstanceMethodsEmptyM).
              should == nil
    end

    it "reports empty own class methods for empty module" do
      Reflexive::Methods.new(nil).
              send(:collect_instance_methods, ::CollectInstanceMethodsEmptyM.singleton_class).
              should == nil
    end
  end

  describe "ModuleInclusionC" do
    module ::ModuleInclusionA
      def module_instance_from_A_WTF!
      end
    end

    module ::ModuleInclusionB
      include ::ModuleInclusionA

      def module_instance_from_B_WTF!
      end
    end

    module ::ModuleInclusionC
      include ::ModuleInclusionB
    end

    it "has ModuleInclusionA and ModuleInclusionB ancestors" do
      ModuleInclusionC.ancestors.should =~ [ ModuleInclusionC,
                                             ModuleInclusionA,
                                             ModuleInclusionB ] 
    end

    it "works" do
      ::ModuleInclusionC.should generate_methods(<<-METHODS_PP)
      [{"[M] ModuleInclusionB"=>
       {:instance=>{:public=>[:module_instance_from_B_WTF!]}}},
       {"[M] ModuleInclusionA"=>
       {:instance=>{:public=>[:module_instance_from_A_WTF!]}}}]
      METHODS_PP
    end
  end
  
  describe "Inheritance" do
    class ::InheritanceA
      def self.singleton_inherited_from_A_WTF!
      end
    end

    class ::InheritanceB < ::InheritanceA
    end

    class ::InheritanceC < ::InheritanceB
      def test
      end
    end
    
    it "works" do
      InheritanceC.should generate_methods(<<-METHODS_PP)
      [{"[C] InheritanceC"=>{:instance=>{:public=>[:test]}}},
       {"[C] InheritanceA"=>{:class=>{:public=>[:singleton_inherited_from_A_WTF!]}}}]
      METHODS_PP
    end
  end

  describe "SingletonAndInstance" do
    module ::M
      def instance_from_moduleWTF!
      end
    end

    module ::SM
      def singleton_from_moduleWTF!
      end
    end

    class ::SingletonAndInstanceTest
      include ::M
      extend ::SM

      def self.singletonWTF!
      end

      def instanceWTF!
      end
    end
    
    it "works" do
      SingletonAndInstanceTest.should generate_methods(<<-METHODS_PP)
      [{"[C] SingletonAndInstanceTest"=>
         {:class=>{:public=>[:singletonWTF!]},
          :instance=>{:public=>[:instanceWTF!]}}},
       {"S[M] SM"=>{:class=>{:public=>[:singleton_from_moduleWTF!]}}},
       {"[M] M"=>{:instance=>{:public=>[:instance_from_moduleWTF!]}}}]
      METHODS_PP
    end
  end

  describe "ExtendWithInstanceAndClass" do
    module ::ExtendWithInstanceAndClassM
      def self.singleton_WTF!
      end

      def instance_WTF!
      end
    end

    class ::ExtendWithInstanceAndClass
      extend ::ExtendWithInstanceAndClassM
    end

    it "works" do
      ::ExtendWithInstanceAndClass.should generate_methods(<<-METHODS_PP)
      [{"S[M] ExtendWithInstanceAndClassM"=>{:class=>{:public=>[:instance_WTF!]}}}]
      METHODS_PP
    end
  end

  describe "SingletonVisibility" do
    class ::SingletonVisibility
      def self.class_method
      end

      class << self

        def public_singleton_method
        end
        public :public_singleton_method

        def protected_singleton_method
        end
        protected :protected_singleton_method

        def private_singleton_method
        end
        private :private_singleton_method
      end
    end

    it "works" do
      ::SingletonVisibility.should generate_methods(<<-METHODS_PP)
      [{"[C] SingletonVisibility"=>
         {:class=>
           {:public=>[:class_method, :public_singleton_method],
            :protected=>[:protected_singleton_method],
            :private=>[:private_singleton_method]}}}]
      METHODS_PP
    end
  end

  describe "SingletonOverrides" do
    class ::SingletonOverridesA
      def self.overriden
        puts "A"
        # super
      end
    end

    module ::SingletonOverridesMB
      def overriden
        puts "  MB"
        super
      end
    end

    class ::SingletonOverridesB < ::SingletonOverridesA
      extend ::SingletonOverridesMB

      def self.overriden
      end
    end

    module ::SingletonOverridesMC
      def overriden
      end

      def singleton_WTF
      end
    end

    class ::SingletonOverridesC < ::SingletonOverridesB
      extend ::SingletonOverridesMC

      def self.class_WTF
      end

      def self.overriden
      end
    end
    
    it "works" do
      ::SingletonOverridesC.should generate_methods(<<-METHODS_PP)
        [{"[C] SingletonOverridesC"=>{:class=>{:public=>[:class_WTF, :overriden]}}},
         {"S[M] SingletonOverridesMC"=>
           {:class=>{:public=>[:overriden, :singleton_WTF]}}},
         {"[C] SingletonOverridesB"=>{:class=>{:public=>[:overriden]}}},
         {"S[M] SingletonOverridesMB"=>{:class=>{:public=>[:overriden]}}},
         {"[C] SingletonOverridesA"=>{:class=>{:public=>[:overriden]}}}]
      METHODS_PP
    end
  end
end
