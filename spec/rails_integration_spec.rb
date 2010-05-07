require "fileutils"
require "open-uri"

require "reflexive"

require File.expand_path("../rails_integration_spec_helper", __FILE__)

shared_examples_for "fresh Rails app with Reflexive installed" do
  it "responds on localhost" do
    get("/").should include("Welcome aboard")
  end

  it "responds for Reflexive paths" do
    constant_reflexion = get("/reflexive/constants/ActiveRecord::Base")
    constant_reflexion.should include("ActiveRecord")
    constant_reflexion.should include("Object")
    constant_reflexion.should include("Class")
    constant_reflexion.should include("Module")
  end
end

describe "Integration with" do
  describe "Rails 2.x" do
    before(:all) do
      bootstrap_gem_environment("rails", "2.3.5")
      build_and_install_test_gem
    end

    it "installs proper version of Rails" do
      sh_in_tmp_gemset("rails -v", :out => :return).should include("Rails 2")
    end
    
    it "installs test Reflexive gem" do
      sh_in_tmp_gemset("gem list", :out => :return).should include("reflexive")
    end

    describe "creates Rails application" do
      before(:all) do
        create_rails_app("2")
      end

      it "which has config/environment.rb file" do
        Dir.chdir($app_dir) do
          File.exist?("config/environment.rb")
        end
      end

      describe "and installs Reflexive gem into it" do
        before(:all) do
          patch_app_file("config/environment.rb",
                         "Rails::Initializer.run do |config|",
                         <<-RUBY)
                          Rails::Initializer.run do |config|
                            config.gem "reflexive"
                            config.middleware.insert_after("Rack::Lock", "Reflexive::Application")
          RUBY
        end

        it "properly" do
          Dir.chdir($app_dir) do
            IO.read("config/environment.rb").should include("Reflexive")
          end
        end

        describe "and runs application" do
          before(:all) do
            Dir.chdir($app_dir) do
              spawn_server_and_wait_for_response("ruby script/server")
            end
          end

          it_should_behave_like "fresh Rails app with Reflexive installed"

          after(:all) do
            terminate_server_blocking
          end
        end
      end
    end
  end

  describe "Rails 3.x" do
    before(:all) do
      bootstrap_gem_environment("rails", "3.0.0.beta3")
      build_and_install_test_gem
    end

    it "installs proper version of Rails" do
      sh_in_tmp_gemset("rails -v", :out => :return).should include("Rails 3")
    end

    it "installs test Reflexive gem" do
      sh_in_tmp_gemset("gem list", :out => :return).should include("reflexive")
    end

    describe "creates Rails application" do
      before(:all) do
        create_rails_app("3")
      end

      it "which has config/application.rb file" do
        Dir.chdir($app_dir) do
          File.exist?("config/application.rb")
        end
      end

      describe "and installs Reflexive gem into it" do
        before(:all) do
          patch_app_file("config/application.rb",
                         "class Application < Rails::Application",
                         <<-RUBY)
                          class Application < Rails::Application
                            config.middleware.insert_after("Rack::Lock", "Reflexive::Application")
          RUBY
        end

        it "properly" do
          Dir.chdir($app_dir) do
            IO.read("config/application.rb").should include("Reflexive")
          end
        end

        describe "and runs application" do
          before(:all) do
            Dir.chdir($app_dir) do
              spawn_server_and_wait_for_response("rails server")
            end
          end

          it_should_behave_like "fresh Rails app with Reflexive installed"

          after(:all) do
            terminate_server_blocking
          end
        end
      end
    end
  end
end
