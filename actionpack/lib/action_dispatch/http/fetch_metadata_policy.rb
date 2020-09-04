# frozen_string_literal: true

require "action_view"

module ActionDispatch #:nodoc:
  class FetchMetadataPolicy
    class Middleware
      class Permissions
        def initialize(request, assets_prefix)
          @request = request
          @assets_prefix = assets_prefix
        end

        def allowed?
          !sec_fetch_site || site_allowed? || get_navigation? || asset?
        end

        private

        attr_reader :request, :assets_prefix

        def site_allowed?
          allowed_sites.include?(sec_fetch_site)
        end

        def get_navigation?
          get? && navigate? && document?
        end

        def asset?
          request.fullpath.start_with?(assets_prefix)
        end

        def allowed_sites
          sites = %w(same-origin none)
          sites << "same-site" if request.fetch_metadata_policy.same_site
          sites
        end

        def get?
          request.method == "GET"
        end

        def navigate?
          sec_fetch_mode == "navigate"
        end

        def document?
          sec_fetch_dest == "document"
        end

        def sec_fetch_site
          request.headers["HTTP_SEC_FETCH_SITE"]
        end

        def sec_fetch_mode
          request.headers["HTTP_SEC_FETCH_MODE"]
        end

        def sec_fetch_dest
          request.headers["HTTP_SEC_FETCH_DEST"]
        end
      end

      FORBIDDEN_RESPONSE_APP = ->(request) do
        format = request.xhr? ? "text/plain" : "text/html"
        template = DebugView.new(request: request)
        body = template.render(
          template: "rescues/blocked_request",
          layout: "rescues/layout"
        )

        [403, {
          "Content-Type" => "#{format}; charset=#{Response.default_charset}",
          "Content-Length" => body.bytesize.to_s,
        }, [body]]
      end

      def initialize(app, assets_prefix)
        @app = app
        @assets_prefix = assets_prefix
      end

      def call(env)
        request = ActionDispatch::Request.new(env)
        response = @app.call(env)

        return response unless request.fetch_metadata_policy
        return response if Permissions.new(request, assets_prefix).allowed?

        if request.resource_isolation_policy.log_warning_on_failure
          logger(request).warn "Fetch Metadata header didn't match request"
        end
        FORBIDDEN_RESPONSE_APP.call(request)
      end

      private

      def logger(request)
        request.logger || ActionView::Base.logger || ActiveSupport::Logger.new($stderr)
      end

      attr_reader :app, :assets_prefix
    end

    module Request
      POLICY = "action_dispatch.fetch_metadata_policy"

      def fetch_metadata_policy
        get_header(POLICY)
      end

      def fetch_metadata_policy=(policy)
        set_header(POLICY, policy)
      end
    end

    DEFAULT_SAME_SITE_POLICY = false

    attr_accessor :same_site, :log_warning_on_failure

    def initialize
      self.same_site = DEFAULT_SAME_SITE_POLICY
      self.log_warning_on_failure = true

      yield self if block_given?
    end
  end
end
