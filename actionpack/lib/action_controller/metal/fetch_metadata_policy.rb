# frozen_string_literal: true

module ActionController #:nodoc:
  module FetchMetadataPolicy
    extend ActiveSupport::Concern

    module ClassMethods
      def fetch_metadata_policy(enabled = true, **options, &block)
        before_action(options) do
          unless enabled
            request.fetch_metadata_policy = nil
          else
            policy = current_fetch_metadata_policy
            yield(policy) if block_given?
            request.fetch_metadata_policy = policy
          end
        end
      end
    end

    private
      def current_fetch_metadata_policy
        request.fetch_metadata_policy&.clone || ActionDispatch::FetchMetadataPolicy.new
      end
  end
end
