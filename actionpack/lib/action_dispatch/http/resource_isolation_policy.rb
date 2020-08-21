# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"

module ActionDispatch #:nodoc:
  class ResourceIsolationPolicy
    class Middleware
      class Permissions
        def initialize(request)
          @request = request
        end

        def allowed?
          !sec_fetch_site || site_allowed? || get_navigation? || asset?
        end

        private

        attr_reader :request

        def site_allowed?
          sec_fetch_site.in?(allowed_sites)
        end

        def get_navigation?
          get? && navigate? && document_frame_or_iframe?
        end

        def asset?
          request.
            original_fullpath.
            starts_with?(Rails.application.config.assets.prefix)
        end

        def allowed_sites
          sites = %w(same-origin none)
          sites << "same-site" if request.resource_isolation_policy.same_site?
          sites
        end

        def get?
          request.method == "get"
        end

        def navigate?
          sec_fetch_mode == "navigate"
        end

        def document_frame_or_iframe?
          sec_fetch_dest.in?(%w(document frame iframe))
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

      FORBIDDEN_RESPONSE_APP = -> env do
        request = Request.new(env)
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

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        response_app = if !request.resource_isolation_policy ||
                          Permissions.new(request).allowed?

                         @app
                       else
                         FORBIDDEN_RESPONSE_APP
                       end

        response_app.call(env)
      end
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

    attr_writer :same_site

    def initialize
      yield self if block_given?
    end

    def same_site?
      # True by default.
      @same_site.nil? ? true : @same_site
    end
  end
end
