# frozen_string_literal: true

module Api
  module V1
    class AppsController < Api::BaseController
      before_action :doorkeeper_authorize!, only: [:verify_credentials]

      # POST /api/v1/apps
      # Register a new application
      def create
        @application = ::Doorkeeper::Application.new(application_params)

        if @application.save
          render json: serialized_application(@application), status: :created
        else
          render json: { error: 'Validation failed', details: @application.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # GET /api/v1/apps/verify_credentials
      # Verify application credentials
      def verify_credentials
        render json: serialized_application(doorkeeper_token.application)
      end

      private

      def application_params
        params.require(:client_name)
        params.require(:redirect_uris)

        {
          name: params[:client_name],
          redirect_uri: params[:redirect_uris],
          scopes: params[:scopes] || 'read'
        }
      end

      def serialized_application(application)
        {
          id: application.id.to_s,
          name: application.name,
          website: params[:website] || nil,
          redirect_uri: application.redirect_uri,
          client_id: application.uid,
          client_secret: application.secret,
          vapid_key: Rails.application.config.x.vapid_public_key || generate_vapid_key
        }
      end

      def generate_vapid_key
        # Generate VAPID key for web push notifications
        # This is a placeholder - in production you should generate actual VAPID keys
        Base64.urlsafe_encode64(SecureRandom.random_bytes(65))
      end
    end
  end
end
