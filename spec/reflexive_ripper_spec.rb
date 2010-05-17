require "reflexive/reflexive_ripper"

Rspec::Matchers.define :have_scopes do |*expected_scopes|
  match do |actual_scanner_events|
    @actual_scopes = actual_scanner_events.
                       map { |e| e[:meta_scope] }.compact
    @actual_scopes == expected_scopes
  end

  failure_message_for_should do |actual_scanner_events|
    "expected that scanner events: #{ actual_scanner_events } \n" <<
            "(with scopes:                #{ @actual_scopes }) \n" <<
            "would have following scopes: #{ expected_scopes[0] }"
  end
end

Rspec::Matchers.define :have_tags do |*expected_tags|
  match do |actual_scanner_events|
    @actual_tags = actual_scanner_events.map { |e| e[:tags] }.compact
    (expected_tags - @actual_tags).empty?
  end

  failure_message_for_should do |actual_scanner_events|
    "expected that scanner events: #{ actual_scanner_events } \n" <<
            "(with tags:                #{ @actual_tags }) \n" <<
            "would have following tags: #{ expected_tags }"
  end
end

Rspec::Matchers.define :have_exact_tags do |*expected_tags|
  match do |actual_scanner_events|
    @actual_tags = actual_scanner_events.map { |e| e[:tags] }.compact
    expected_tags == @actual_tags  
  end

  failure_message_for_should do |actual_scanner_events|
    "expected that scanner events: #{ actual_scanner_events } \n" <<
            "(with tags:                #{ @actual_tags }) \n" <<
            "would have exact tags: #{ expected_tags[0] }"
  end
end

describe Reflexive::ReflexiveRipper do
  def scanner_events_for(source)
    parser = Reflexive::ReflexiveRipper.new(source)
    parser.parse
    parser.scanner_events
  end

  it "collects scanner events as hashes" do
    scanner_events_for("a = 42").should == [
            {:ident=>"a", :tags=>{:local_variable_assignment=>"1:a"}},
            {:sp=>" "}, {:op=>"="}, {:sp=>" "}, {:int=>"42"}
    ]
  end

  describe "injects method call scanner event tags" do
    specify "m!" do
      scanner_events_for("m!").should(have_tags(
              {:method_call=>{:name=>"m!", :receiver=>[], :scope => []}}
      ))
    end

    specify "A.b!()" do
      scanner_events_for("A.b!").should(have_tags(
              {:method_call=>{:name=>"b!", :receiver=>["A"], :scope => []}}
      ))
    end

    specify "A::B.c!()" do
      scanner_events_for("A::B.c!()").should(have_tags(
              {:method_call=>{:name=>"c!", :receiver=>["A::B"], :scope => []}}
      ))
    end

    specify "module A; B.c!(); end" do
      scanner_events_for("module A; B.c!(); end").should(have_tags(
              {:method_call=>{:name=>"c!", :receiver=>["B"], :scope => ["A"]}}
      ))
    end
  end

  describe "injects local variable assignment event tags" do
    specify "v = 1" do
      scanner_events_for("a = 42").should(have_tags(
              :local_variable_assignment=>"1:a"))
    end

    specify "def m(arg) end" do
      scanner_events_for("def m(arg); end").should(have_tags(
              :local_variable_assignment=>"2:arg"))
    end

    specify "a, b = 1, 2" do
      scanner_events_for("a, b = 1, 2").should(have_tags(
              {:local_variable_assignment=>"1:a"},
              {:local_variable_assignment=>"1:b"}))
    end

    specify "a, b, *c, d = 1, 2" do
      scanner_events_for("a, b, *c, d = 1, 2").should(have_tags(
              {:local_variable_assignment=>"1:a"},
              {:local_variable_assignment=>"1:b"},
              {:local_variable_assignment=>"1:c"},
              {:local_variable_assignment=>"1:d"}
      ))
    end

    specify "1.tap { (dv = 1).tap { puts dv } }" do
      scanner_events_for("1.tap { (dv = 1).tap { puts dv } }").should(have_exact_tags(
              {:local_variable_assignment=>"2:dv"},
              {:method_call=>{:name=>"puts", :receiver=>[], :scope => []}},
              {:local_variable_access=>"2:dv"}
      ))
    end

    specify "1.tap { x = 1; 1.tap { puts x } }" do
      scanner_events_for("1.tap { x = 1; 1.tap { puts x } }").should(have_tags(
              {:local_variable_assignment=>"2:x"},
              {:local_variable_assignment=>"2:x"}))
    end

    specify "tv = 1; def m; puts tv; end" do
      scanner_events_for("tv = 1; def m; puts tv; end").should(have_tags(
              {:local_variable_assignment=>"1:tv"},
              {:method_call=>{:name=>"puts", :receiver=>[:instance], :scope => []}},
              {:method_call=>{:name=>"tv", :receiver=>[:instance], :scope => []}}))
    end

  end

  describe "scope handling" do
    describe "for method calls" do
      specify "from top level" do
        scanner_events_for("m()").should(have_tags(
              {:method_call=>{:name=>"m", :receiver=>[], :scope => []}}))
      end

      specify "class definition level" do
        scanner_events_for("class C; cm(); end").should(have_tags(
              {:method_call=>{:name=>"cm", :receiver=>["C"], :scope => ["C"]}}))
        scanner_events_for("module M; cm(); end").should(have_tags(
              {:method_call=>{:name=>"cm", :receiver=>["M"], :scope => ["M"]}}))
      end

      specify "class instance level" do
        scanner_events_for("class C; def im1; im2; end end").should(have_tags(
              {:method_call=>{:name=>"im2", :receiver=>["C", :instance], :scope => ["C"]}}))
        scanner_events_for("module M; def im1; im2; end end").should(have_tags(
              {:method_call=>{:name=>"im2", :receiver=>["M", :instance], :scope => ["M"]}}))
      end

      specify "class singleton level" do
        scanner_events_for("class C; def self.cm1() cm2; end end").should(have_tags(
              {:method_call=>{:name=>"cm2", :receiver=>["C"], :scope => ["C"]}}))
        scanner_events_for("module M; def self.cm1() cm2; end end").should(have_tags(
              {:method_call=>{:name=>"cm2", :receiver=>["M"], :scope => ["M"]}}))
      end

      pending "nested method calls with constant references" do
        src = <<-RUBY
          module M
            class C
              def self.m
              end
            end
          end
          class M::C
            def m
              c = C.m
            end
          end
        RUBY
      end
    end

    describe "for constant references" do
      specify "top level" do
        scanner_events_for("C").should(have_tags(
              :constant_access=>{:name=>"C", :scope=>[]}
        ))
      end

      specify "path" do
        scanner_events_for("A::B").should(have_tags(
              {:constant_access=>{:name=>"A", :scope=>[]}},
              {:constant_access=>{:name=>"A::B", :scope=>[]}}
        ))
        scanner_events_for("A::B::C").should(have_tags(
              {:constant_access=>{:name=>"A", :scope=>[]}},
              {:constant_access=>{:name=>"A::B", :scope=>[]}},
              {:constant_access=>{:name=>"A::B::C", :scope=>[]}}
        ))
      end

      specify "top path" do
        scanner_events_for("::A::B").should(have_tags(
              {:constant_access=>{:name=>"::A::B", :scope=>[]}}
        ))
      end

      specify "nested" do
        scanner_events_for("module A; module B; C; end end").should(have_tags(
              {:constant_access=>{:name=>"A", :scope=>[]}},
              {:constant_access=>{:name=>"B", :scope=>["A"]}},
              {:constant_access=>{:name=>"C", :scope=>["A", "B"]}}
        ))
        scanner_events_for("module A; class B; C; end end").should(have_tags(
              {:constant_access=>{:name=>"A", :scope=>[]}},
              {:constant_access=>{:name=>"B", :scope=>["A"]}},
              {:constant_access=>{:name=>"C", :scope=>["A", "B"]}}
        ))
      end

      specify "combined (nested with path)" do
        scanner_events_for("module M; C::D; end").should(have_tags(
                {:constant_access=>{:name=>"M", :scope=>[]}},
                {:constant_access=>{:name=>"C", :scope=>["M"]}},
                {:constant_access=>{:name=>"C::D", :scope=>["M"]}}
        ))
      end

      specify "combined (nested with top level)" do
        scanner_events_for("module M; ::C::D; end").should(have_tags(
              {:constant_access=>{:name=>"M", :scope=>[]}},
              {:constant_access=>{:name=>"::C::D", :scope=>["M"]}}
        ))
      end

      specify "from instance methods" do
        scanner_events_for("def m; C; end").should(have_tags(
              {:constant_access=>{:name=>"C", :scope=>[]}}
        ))

      end
    end
  end

  describe "injects scope meta events" do
    example "simple class def" do
      scanner_events_for("class C; end").should(
        have_scopes(["C"], []))
    end

    example "nested class def" do
      scanner_events_for("class C; class D; end end").should(
        have_scopes(["C"], ["C", "D"], ["C"], []))
    end

    example "class inside module def" do
      scanner_events_for("module M; class C; end end").should(
              have_scopes(["M"], ["M", "C"], ["M"], []))
    end

    it "handles const_path_ref" do
      scanner_events_for("class Const::PathRef < ::TopConstRef; end").should(
              have_scopes(["Const::PathRef"], []))
    end

    it "handles top_const_ref" do
      scanner_events_for("class ::TopConstRef; end").should(
              have_scopes(["::TopConstRef"], []))
    end
  end

  #  describe "injects require/load argument tag" do
  #    specify "require" do
  #      scanner_events_for("require 'f'").should(have_tags(
  #          {:local_variable_assignment=>"1:tv"}
  #      ))
  #    end
  #  end

  it "shouldn't get confused with non-scope changing const refs" do
    scanner_events_for("v = :class; SomeConst = 123").should(
              have_scopes())
  end

  it "should handle complex arbitrary nesting" do
    src = <<-RUBY
      class TC
        def m
        end
      end

      module M1
        def m
        end

        module M2
          def m
          end
          class C1

          end
          class C1
            def m
            end
          end
        end

        class C3
          def m
          end
        end

      end

      module M1::M2
        class C4
          module M4
            def m
            end
          end

          class C5
            module M3
            end
            class C6
            end
          end
        end
      end
    RUBY
    scanner_events_for(src).should(
              have_scopes(["TC"],
                           [], 
                           ["M1"],
                           ["M1", "M2"],
                           ["M1", "M2", "C1"],
                           ["M1", "M2"],
                           ["M1", "M2", "C1"],
                           ["M1", "M2"],
                           ["M1"],
                           ["M1", "C3"],
                           ["M1"],
                           [],
                           ["M1::M2"],
                           ["M1::M2", "C4"],
                           ["M1::M2", "C4", "M4"],
                           ["M1::M2", "C4"],
                           ["M1::M2", "C4", "C5"],
                           ["M1::M2", "C4", "C5", "M3"],
                           ["M1::M2", "C4", "C5"],
                           ["M1::M2", "C4", "C5", "C6"],
                           ["M1::M2", "C4", "C5"],
                           ["M1::M2", "C4"],
                           ["M1::M2"],
                           []))
  end
end
