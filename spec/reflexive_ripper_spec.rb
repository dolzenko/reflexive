require "reflexive/reflexive_ripper"

Rspec::Matchers.define :have_scopes do |*expected_scopes|
  match do |actual_scanner_events|
    @actual_scopes = actual_scanner_events.
                       select { |e| e[1] == :meta_scope }.
                       map { |e| e[0] }
    @actual_scopes == expected_scopes
  end

  failure_message_for_should do |actual_scanner_events|
    "expected that scanner events: #{ actual_scanner_events } \n" <<
            "(with scopes #{ @actual_scopes }) \n" <<
            "would have following scopes: #{ expected_scopes }"
  end
end

describe Reflexive::ReflexiveRipper do
  def scanner_events_for(source)
    parser = Reflexive::ReflexiveRipper.new(source)
    parser.parse
    parser.scanner_events
  end

  it "collects scanner events" do
    scanner_events_for("a = 42").should == [["a", :ident],
                                            [" ", :sp], ["=", :op],
                                            [" ", :sp], ["42", :int]]
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
              have_scopes([["TC"],
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
                           []]))
  end
end
