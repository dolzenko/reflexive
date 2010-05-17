require "reflexive/helpers"
require "reflexive/constantize"
require "reflexive/descendants"

describe "Reflexive.loaded_features_lookup" do
  before(:all) do
    @native_feature = $LOADED_FEATURES.detect { |f| f =~ /\.so\z/ }
    @ruby_feature = $LOADED_FEATURES.detect { |f| f =~ /\.rb\z/ }
    raise "Can't setup test: need at least one native and ruby feature loaded" unless @native_feature && @ruby_feature 
  end
  
  it "doesn't looks up native features" do
    Reflexive.loaded_features_lookup(@native_feature).should == nil
  end

  it "looks up ruby features when passed feature basename" do
    ruby_feature_basename = File.basename(@ruby_feature)
    Reflexive.loaded_features_lookup(ruby_feature_basename).should == @ruby_feature
  end
  
  it "looks up ruby features when passed feature basename and path part" do
    feature_dirname = File.dirname(@ruby_feature)
    feature_basename = File.basename(@ruby_feature)
    feature_name = File.join(feature_dirname.split("/").last(2).join("/"),
                             feature_basename) 
    Reflexive.loaded_features_lookup(feature_name).should == @ruby_feature
  end

  it "looks up ruby features when passed feature basename without extension" do
    ruby_feature_basename = File.basename(@ruby_feature).sub(/\.\w+\z/, "")
    Reflexive.loaded_features_lookup(ruby_feature_basename).should == @ruby_feature
  end
end

describe "Reflexive.constant_lookup" do
  module M1
    class C1
    end
    module M2
      module M3
        class C2
        end
      end
    end
  end

  it "looks up top-level constants" do
    Reflexive.constant_lookup("::String", "Some::Ignored::Scope").should == ::String
  end

  it "returns nil for non existing top-level constant" do
    Reflexive.constant_lookup("::StringAsd", "Some::Ignored::Scope").should == nil
  end

  it "looks up top-level constants without scope" do
    Reflexive.constant_lookup("String", "").should == ::String
  end

  it "looks up non top-level constants with scope" do
    Reflexive.constant_lookup("C1", "M1").should == ::M1::C1
    Reflexive.constant_lookup("C2", "M1::M2::M3").should == ::M1::M2::M3::C2
  end

  it "returns nil for non existing non top-level constants with scope" do
    Reflexive.constant_lookup("CNotExist", "M1").should == nil
  end
end

describe "Reflexive.load_path_lookup" do
  it "looks up features present in $LOAD_PATH" do
    feature = nil
    $LOAD_PATH.each { |p| break if (feature = Dir["#{ p }/*.rb"].first) }
    feature_basename = File.basename(feature).sub(/\.\w+\z/, "")
    Reflexive.load_path_lookup(feature_basename).should == feature
  end
end

describe "Reflexive.descendants" do
  class X2 ; end
  class A2 < X2; end
  class B2 < X2; end

  module M2
  end

  class C2
  end

  C2.extend(M2)
  
  it "finds class descendant" do
    Reflexive.descendants(X2).should =~ [B2, A2]
  end

  it "finds singleton class descendant" do
    Reflexive.descendants(M2).should =~ [C2]
  end
end