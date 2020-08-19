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

        def initialize(request)
          @request = request
        end

        def forbidden?
          true
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

        response_app = if Permissions.new(request).forbidden?
          FORBIDDEN_RESPONSE_APP
        else
          @app
        end

        response_app.call(env)
      end
    end
  end
end
