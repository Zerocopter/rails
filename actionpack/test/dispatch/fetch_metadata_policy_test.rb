# frozen_string_literal: true

require "abstract_unit"

class FetchMetadataPolicyTest
  class PolicyController < ActionController::Base
    def index
      render plain: "Success"
    end

    def bogus_asset
      render plain: "Bogus asset"
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "fetch_metadata_policy_integration_test" do
      get "/", to: PolicyController.action(:index)
      get "/assets/bogus", to: PolicyController.action(:bogus_asset)
    end
  end

  class SameSiteFetchMetadataPolicyTest < ActionDispatch::IntegrationTest
    class PolicyConfigMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        env["action_dispatch.fetch_metadata_policy"] = ActionDispatch::ResourceIsolationPolicy.new do |policy|
          policy.log_warning_on_failure = false
        end
        @app.call(env)
      end
    end

    APP = build_app(ROUTES) do |middleware|
      middleware.use PolicyConfigMiddleware
      middleware.use ActionDispatch::FetchMetadataPolicy::Middleware, "/assets"
    end

    def app
      APP
    end

    test "doesn't block requests without sec-fetch-site header" do
      get "/"

      assert_response 200
      assert_match "Success", response.body
    end

    test "doesn't block requests with sec-fetch-site == 'none'" do
      get "/", env: {
        "sec-fetch-site": "none"
      }

      assert_response 200
      assert_match "Success", response.body
    end

    test "doesn't block requests with sec-fetch-site == 'same-origin'" do
      get "/", env: {
        "sec-fetch-site": "same-origin"
      }

      assert_response 200
      assert_match "Success", response.body
    end

    test "blocks requests with sec-fetch-site == 'same-site'" do
      get "/", env: {
        "sec-fetch-site": "same-site"
      }

      assert_response 403
      assert_match "Blocked request: GET /", response.body
    end

    test "blocks requests with sec-fetch-site == 'cross-site'" do
      get "/", env: {
        "sec-fetch-site": "cross-site"
      }

      assert_response 403
      assert_match "Blocked request: GET /", response.body
    end

    test "doesn't block GET requests with sec-fetch-site == 'cross-site',
          sec-fetch-dest == 'document' and sec-fetch-mode == 'navigate'" do

      get "/", env: {
        "sec-fetch-site": "cross-site",
        "sec-fetch-dest": "document",
        "sec-fetch-mode": "navigate"
      }

      assert_response 200
      assert_match "Success", response.body
    end

    test "blocks POST requests with sec-fetch-site == 'cross-site',
          sec-fetch-dest == 'document' and sec-fetch-mode == 'navigate'" do

      post "/", env: {
        "sec-fetch-site": "cross-site",
        "sec-fetch-dest": "document",
        "sec-fetch-mode": "navigate"
      }
      assert_response 403
      assert_match "Blocked request: POST /", response.body
    end

    test "blocks GET requests with sec-fetch-site == 'cross-site',
          sec-fetch-dest == 'object' and sec-fetch-mode == 'navigate'" do

      get "/", env: {
        "sec-fetch-site": "cross-site",
        "sec-fetch-dest": "object",
        "sec-fetch-mode": "navigate"
      }

      assert_response 403
      assert_match "Blocked request: GET /", response.body
    end

    test "blocks GET requests with sec-fetch-site == 'cross-site',
          sec-fetch-dest == 'embed' and sec-fetch-mode == 'navigate'" do

      get "/", env: {
        "sec-fetch-site": "cross-site",
        "sec-fetch-dest": "embed",
        "sec-fetch-mode": "navigate"
      }

      assert_response 403
      assert_match "Blocked request: GET /", response.body
    end

    test "blocks GET requests with sec-fetch-site == 'cross-site',
          sec-fetch-dest == 'iframe' and sec-fetch-mode == 'navigate'" do

      get "/", env: {
        "sec-fetch-site": "cross-site",
        "sec-fetch-dest": "iframe",
        "sec-fetch-mode": "navigate"
      }

      assert_response 403
      assert_match "Blocked request: GET /", response.body
    end

    test "blocks GET requests with sec-fetch-site == 'cross-site',
          sec-fetch-dest == 'nested-document' and sec-fetch-mode == 'nested-navigate'" do

      get "/", env: {
        "sec-fetch-site": "cross-site",
        "sec-fetch-dest": "nested-document",
        "sec-fetch-mode": "nested-navigate"
      }

      assert_response 403
      assert_match "Blocked request: GET /", response.body
    end

    test "blocks GET requests with sec-fetch-site == 'cross-site' and
          sec-fetch-mode == 'cors' or 'no-cors' if request.fullpath doesn't
          start with assets prefix" do

      %w(
         audio
         audioworklet
         font
         image
         manifest
         paintworklet
         report
         script
         serviceworker
         sharedworker
         style
         track
         video
         worker
         xslt
      ).each do |destination|
        %w(cors no-cors).each do |mode|
          env = {
            "sec-fetch-site": "cross-site",
            "sec-fetch-dest": destination,
            "sec-fetch-mode": mode
          }

          get "/", env: env

          assert_response 403
          assert_match "Blocked request: GET /", response.body
        end
      end
    end

    test "doesn't block GET requests with sec-fetch-site == 'cross-site' and
          sec-fetch-mode == 'cors' or 'no-cors' if request.fullpath starts with
          assets prefix" do

      %w(
         audio
         audioworklet
         font
         image
         manifest
         paintworklet
         report
         script
         serviceworker
         sharedworker
         style
         track
         video
         worker
         xslt
      ).each do |destination|
        %w(cors no-cors).each do |mode|
          env = {
            "sec-fetch-site": "cross-site",
            "sec-fetch-dest": destination,
            "sec-fetch-mode": mode
          }

          get "/assets/bogus", env: env

          assert_response 200
          assert_match "Bogus asset", response.body
        end
      end
    end
  end

  class SameSiteAllowedFetchMetadataPolicyTest < ActionDispatch::IntegrationTest
    class PolicyConfigMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        env["action_dispatch.fetch_metadata_policy"] = ActionDispatch::FetchMetadataPolicy.new do |policy|
          policy.same_site = true
          policy.log_warning_on_failure = false
        end
        @app.call(env)
      end
    end

    APP = build_app(ROUTES) do |middleware|
      middleware.use PolicyConfigMiddleware
      middleware.use ActionDispatch::FetchMetadataPolicy::Middleware, "/assets"
    end

    def app
      APP
    end

    test "doesn't block requests with sec-fetch-site == 'same-site'" do
      get "/", env: {
        "sec-fetch-site": "same-site"
      }

      assert_response 200
      assert_match "Success", response.body
    end
  end
end
