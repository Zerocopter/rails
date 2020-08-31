# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class ResourceIsolationPolicyTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "resource isolation policy is not enabled by default" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      header "sec-fetch-site", "cross-site"
      get "/"

      assert_equal 200, last_response.status
    end

    test "global resource isolation policy in an initializer" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/resource_isolation_policy.rb", <<-RUBY
        Rails.application.config.resource_isolation_policy do |p|
          p.same_site = true
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      header "sec-fetch-site", "cross-site"
      get "/"

      assert_equal 403, last_response.status
    end

    test "override resource isolation policy using same directive in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          resource_isolation_policy do |p|
            p.same_site = false
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/resource_isolation_policy.rb", <<-RUBY
        Rails.application.config.resource_isolation_policy do |p|
          p.same_site = true
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      header "sec-fetch-site", "same-site"
      get "/"

      assert_equal 403, last_response.status
    end
  end
end
