# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"

module ActionDispatch #:nodoc:
  class ResourceIsolationPolicy
    class Middleware
      class Permissions
        HTTP_SEC_FETCH_DEST = "HTTP_SEC_FETCH_DEST".freeze
        HTTP_SEC_FETCH_MODE = "HTTP_SEC_FETCH_MODE".freeze
        HTTP_SEC_FETCH_SITE = "HTTP_SEC_FETCH_SITE".freeze
        HTTP_SEC_FETCH_USER = "HTTP_SEC_FETCH_USER".freeze
        SAME_ORIGIN = "same-origin".freeze
        SAME_SITE = "same-site".freeze
        NONE = "none".freeze
        NAVIGATE = "navigate".freeze
        GET = "get".freeze
        OBJECT = "object".freeze
        EMBED = "embed".freeze

        def initialize(request)
          @request = request
        end

        def allowed?
          !sec_fetch_site || site_allowed? || get_navigation? || asset?
        end

        private

        attr_reader :request

        def site_allowed?
          sec_fetch_site.in?([SAME_ORIGIN, SAME_SITE, NONE])
        end

        def get_navigation?
          get? && navigate? && !object_or_embed
        end

        def asset?
          request.original_fullpath.matches?(/\A\/assets\//)
        end

        def get?
          request.method == GET
        end

        def navigate?
          sec_fetch_mode == NAVIGATE
        end

        def object_or_embed?
          sec_fetch_dest.in?([OBJECT, EMBED])
        end

        def sec_fetch_site
          request.headers[HTTP_SEC_FETCH_SITE]
        end

        def sec_fetch_mode
          request.headers[HTTP_SEC_FETCH_MODE]
        end

        def sec_fetch_dest
          request.headers[HTTP_SEC_FETCH_DEST]
        end
      end

      FORBIDDEN_RESPONSE_APP = -> env do
        request = Request.new(env)
        format = request.xhr? ? "text/plain" : "text/html"
        template = DebugView.new(request: request)
        body = template.render(template: "rescues/blocked_request", layout: "rescues/layout")

        [403, {
          "Content-Type" => "#{format}; charset=#{Response.default_charset}",
          "Content-Length" => body.bytesize.to_s,
        }, [body]]
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new env

        response_app = if Permissions.new(request).allowed?
          @app
        else
          FORBIDDEN_RESPONSE_APP
        end

        response_app.call(env)
      end
    end
  end
end
