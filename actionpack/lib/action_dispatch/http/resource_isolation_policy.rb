# frozen_string_literal: true

require "action_view"

module ActionDispatch #:nodoc:
  class ResourceIsolationPolicy
    class Middleware
      class Permissions
        def initialize(request, assets_prefix)
          @request = request
          @assets_prefix = assets_prefix
        end

        def forbidden?
          !allowed?
        end

        private

        attr_reader :request, :assets_prefix

        def allowed?
          !sec_fetch_site || site_allowed? || get_navigation? || asset?
        end

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
          sites << "same-site" if request.resource_isolation_policy.same_site
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
        _, headers, _ = response = @app.call(env)

        if request.resource_isolation_policy &&
           Permissions.new(request, assets_prefix).forbidden?

          if request.resource_isolation_policy.log_warning_on_fetch_metadata_failure
            logger(request).warn "Fetch Metadata header didn't match request"
          end

          response = FORBIDDEN_RESPONSE_APP.call(request)
        end

        response
      end

      private

      def logger(request)
        request.logger || ActionView::Base.logger || ActiveSupport::Logger.new($stderr)
      end

      attr_reader :app, :assets_prefix
    end

    module Request
      POLICY = "action_dispatch.resource_isolation_policy"

      def resource_isolation_policy
        get_header(POLICY)
      end

      def resource_isolation_policy=(policy)
        set_header(POLICY, policy)
      end
    end

    DEFAULT_SAME_SITE_POLICY = false

    attr_accessor :same_site, :log_warning_on_fetch_metadata_failure

    def initialize
      @same_site = DEFAULT_SAME_SITE_POLICY
      self.log_warning_on_fetch_metadata_failure = true

      yield self if block_given?
    end
  end
end
