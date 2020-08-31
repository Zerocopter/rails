# frozen_string_literal: true

module ActionController #:nodoc:
  module ResourceIsolationPolicy
    extend ActiveSupport::Concern

    module ClassMethods
      def resource_isolation_policy(enabled = true, **options, &block)
        before_action(options) do
          unless enabled
            request.resource_isolation_policy = nil
          else
            policy = current_resource_isolation_policy
            yield(policy) if block_given?
            request.resource_isolation_policy = policy
          end
        end
      end
    end

    private
      def current_resource_isolation_policy
        request.resource_isolation_policy&.clone || ActionDispatch::ResourceIsolationPolicy.new
      end
  end
end
