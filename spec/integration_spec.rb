require "reflexive/application"
require "rack/test"
require "nokogiri"
require "webrat/core/matchers"

FIXTURE_FILE_PATH = File.expand_path("../integration_spec_fixture.rb", __FILE__)
require FIXTURE_FILE_PATH

describe Reflexive::Application do
  include Rack::Test::Methods
  include Webrat::Matchers

  include Reflexive::RoutingHelpers

  def app
    Reflexive::Application
  end

  it "shows dashboard" do
    get(dashboard_path)
    last_response.should be_ok
    last_response.body.should include("Reflexive", "$LOAD_PATH", "Favorites")
    last_response.body.should have_selector('a', :content => "Date")
    last_response.body.should have_selector('a', :content => "Gem")
    last_response.body.should have_selector('a', :content => "FileUtils")
  end

  describe "class/module browser" do
    def constant_browser_for(constant)
      get(constant_path(constant))
      last_response.should be_ok
      last_response.body
    end
    
    it "shows class name" do
      get(constant_path("OpenStruct"))
      last_response.should be_ok
      last_response.body.should include("OpenStruct")
    end

    it "shows files in which class is defined" do
      constant_browser_for("OpenStruct").
              should include("ostruct.rb")
      constant_browser_for("IntegrationSpecFixture::TestClass").
              should include("integration_spec_fixture.rb")
    end

    it "shows superclass" do
      constant_browser_for("IntegrationSpecFixture::TestClass").
              should include("TestBaseClass")
      constant_browser_for("OpenStruct").
              should include("BasicObject")
    end

    it "shows instance methods" do
      constant_browser_for("IntegrationSpecFixture::TestClass").
              should include("public_meth", "protected_meth", "private_meth")
    end

    it "shows class methods" do
      constant_browser_for("IntegrationSpecFixture::TestClass").
              should include("class_meth")
    end

    it "shows inherited instance methods" do
      constant_browser_for("IntegrationSpecFixture::TestClass").
              should include("inherited_meth")
    end

    it "shows inherited class methods" do
      constant_browser_for("IntegrationSpecFixture::TestClass").
              should include("inherited_class_meth")
    end

    it "shows instance methods for module" do
      constant_browser_for("IntegrationSpecFixture::TestModule").
              should include("module_meth")
    end

    it "shows class methods for module" do
      constant_browser_for("IntegrationSpecFixture::TestModule").
              should include("module_class_meth")
    end

    it "shows classes module is included in" do
      constant_browser_for("IntegrationSpecFixture::TestModule").
              should include("TestClass")
    end

    it "shows classes class is derived from" do
      constant_browser_for("IntegrationSpecFixture::TestBaseClass").
              should include("TestClass")
    end

    it "shows classes nested inside the class" do
      constant_browser_for("IntegrationSpecFixture::TestClass").
              should have_selector("a", :content => "NestedClass")
    end
  end

  describe "source browser" do
    def source_browser
      get(file_path(FIXTURE_FILE_PATH))
      last_response.should be_ok
      last_response.body
    end

    it "shows arbitrary files from file system" do
      get(file_path(FIXTURE_FILE_PATH))
      last_response.should be_ok
      last_response.body.should include("integration_spec_fixture.rb")
    end

    it "browses directories" do
      dir = File.dirname(FIXTURE_FILE_PATH)
      get(file_path(dir))
      last_response.should be_ok

      Dir["#{ dir }/*"].each do |path|
        last_response.body.should include(File.basename(path))
      end
    end

    it "highlights the code" do
      source_browser.should have_selector("span.no")
      source_browser.should have_selector("span.s")
      source_browser.should have_selector("span.r")
      source_browser.should have_selector("span.co")
    end

    it "links class names" do
      source_browser.should have_selector('a[href$="constant_lookup?name=TestBaseClass&scope=IntegrationSpecFixture"]')
    end

    it "links module names" do
      source_browser.should have_selector('a[href$="constant_lookup?name=IntegrationSpecFixture&scope="]')
    end

    it "links arguments to require/load" do
      source_browser.should have_selector('a[href$="load_path_lookup?path=ostruct"]')
    end

    it "links method calls from top level" do
      source_browser.should have_selector('a[href$="constants/Kernel/class_methods/require"]')
    end

    it "links method calls from class instance level" do
      source_browser.should have_selector('a[href$="constants/IntegrationSpecFixture::TestClass/class_methods/inherited_class_meth"]')
    end

    it "links method calls from class definition level" do
      source_browser.should have_selector('a[href$="constants/IntegrationSpecFixture::TestClass/class_methods/another_inherited_class_meth"]')
    end

    it "links local variable assignments and access" do
      source_browser.should have_selector('span[id^="lv:"][id$=":local_var"]', :content => "local_var") do |local_var_assignment|
        source_browser.should have_selector('a[href="#' + local_var_assignment.first["id"] + '"]')
      end
      source_browser.should have_selector('span[id^="lv:"][id$=":another_local_var"]', :content => "another_local_var")
      # source_browser.should have_selector('a.lva', :content => "another_local_var")
    end

    it "links method calls" do
      source_browser.should have_selector('a[href$="constants/IntegrationSpecFixture::TestClass/instance_methods/not_defined_meth"]', :content => "not_defined_meth")
    end
  end

  describe "constant lookup" do
    it "redirects to found constant" do
      get(constant_lookup_path("TestModule", ["IntegrationSpecFixture::TestClass"]))
      
      last_response.should be_redirect
      last_response.body.should be_empty

      follow_redirect!
      
      last_response.body.should match(/module\s+IntegrationSpecFixture::TestModule/) 
      last_response.body.should include("integration_spec_fixture.rb")
    end
  end

  describe "method lookup" do
    it "redirects to found method" do
      get(new_method_path("IntegrationSpecFixture::TestClass", :instance, "inherited_meth"))

      last_response.should be_redirect
      last_response.body.should be_empty

      follow_redirect!
      
      last_request.path.should include("constants/IntegrationSpecFixture::TestClass/instance_methods/inherited_meth/definition")
    end

    it "shows error message when method is not found" do
      get(new_method_path("IntegrationSpecFixture::TestClass", :instance, "not_defined_meth"))

      last_response.should be_ok
      last_response.body.should include("Reflexive Error")
    end

    it "redirect to documentation for core methods" do
      get(new_method_path("IntegrationSpecFixture::TestClass", :class, "class_eval"))

      last_response.should be_redirect

      follow_redirect!
      
      last_request.path.should include("constants/Module/instance_methods/class_eval/apidock")
    end

    it "uses heuristics providing user a way to choose method for module instance methods" do
      get(new_method_path("IntegrationSpecFixture::HeuristicLookupBaseModule", :instance, "meth"))

      last_response.should be_ok
      last_response.body.should include("HeuristicLookupIncludingClass1")
      last_response.body.should include("HeuristicLookupIncludingClass2")
    end

    it "uses heuristics providing user a way to choose method for class instance methods" do
      get(new_method_path("IntegrationSpecFixture::HeuristicLookupBaseClass", :instance, "meth"))

      last_response.should be_ok
      last_response.body.should include("HeuristicLookupInheritingClass1")
      last_response.body.should include("HeuristicLookupInheritingClass2")
    end
  end
end