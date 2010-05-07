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

describe Reflexive::Methods do
  describe "ModuleInclusionC" do
    module ModuleInclusionA
      def module_instance_from_A_WTF!
      end
    end

    module ModuleInclusionB
      include ModuleInclusionA

      def module_instance_from_B_WTF!
      end
    end

    module ModuleInclusionC
      include ModuleInclusionB
    end

    it "works" do
      ModuleInclusionC.should generate_methods(<<-METHODS_PP)
      [{"[M] ModuleInclusionB"=>
       {:instance=>{:public=>[:module_instance_from_B_WTF!]}}},
       {"[M] ModuleInclusionA"=>
       {:instance=>{:public=>[:module_instance_from_A_WTF!]}}}]
      METHODS_PP
    end
  end
  describe "Inheritance" do
    class InheritanceA
      def self.singleton_inherited_from_A_WTF!
      end
    end

    class InheritanceB < InheritanceA
    end

    class InheritanceC < InheritanceB
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
    module M
      def instance_from_moduleWTF!
      end
    end

    module SM
      def singleton_from_moduleWTF!
      end
    end

    class SingletonAndInstanceTest
      include M
      extend SM

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
    module ExtendWithInstanceAndClassM
      def self.singleton_WTF!
      end

      def instance_WTF!
      end
    end

    class ExtendWithInstanceAndClass
      extend ExtendWithInstanceAndClassM
    end

    it "works" do
      ExtendWithInstanceAndClass.should generate_methods(<<-METHODS_PP)
      [{"S[M] ExtendWithInstanceAndClassM"=>{:class=>{:public=>[:instance_WTF!]}}}]
      METHODS_PP
    end
  end

  describe "SingletonVisibility" do
    class SingletonVisibility
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
      SingletonVisibility.should generate_methods(<<-METHODS_PP)
      [{"[C] SingletonVisibility"=>
         {:class=>
           {:public=>[:class_method, :public_singleton_method],
            :protected=>[:protected_singleton_method],
            :private=>[:private_singleton_method]}}}]
      METHODS_PP
    end
  end

  describe "SingletonOverrides" do
    class SingletonOverridesA
      def self.overriden
        puts "A"
        # super
      end
    end

    module SingletonOverridesMB
      def overriden
        puts "  MB"
        super
      end
    end

    class SingletonOverridesB < SingletonOverridesA
      extend SingletonOverridesMB

      def self.overriden
      end
    end

    module SingletonOverridesMC
      def overriden
      end

      def singleton_WTF
      end
    end

    class SingletonOverridesC < SingletonOverridesB
      extend SingletonOverridesMC

      def self.class_WTF
      end

      def self.overriden
      end
    end
    
    it "works" do
      SingletonOverridesC.should generate_methods(<<-METHODS_PP)
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
