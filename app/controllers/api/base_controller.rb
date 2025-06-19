# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ActionController::Helpers
    include Doorkeeper::Rails::Helpers

    before_action :set_cache_headers
    before_action :set_cors_headers

    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    protected

    def doorkeeper_unauthorized_render_options(*)
      { json: { error: 'This action requires authentication' } }
    end

    def doorkeeper_forbidden_render_options(*)
      { json: { error: 'This action is outside the authorized scopes' } }
    end

    def current_user
      return @current_user if defined?(@current_user)

      @current_user = Actor.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
    rescue ActiveRecord::RecordNotFound
      @current_user = nil
    end

    def current_account
      current_user
    end

    def require_authenticated_user!
      render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
    end

    def require_user!
      if current_user && !current_user.local?
        render json: { error: 'This method is only available to local users' }, status: :unprocessable_content
      elsif !current_user
        render json: { error: 'This action requires authentication' }, status: :unauthorized
      end
    end

    # Check if current request has required OAuth scopes
    def doorkeeper_authorize!(*scopes)
      return false unless doorkeeper_token

      # Check if token has required scopes
      if scopes.any?
        required_scopes = Doorkeeper::OAuth::Scopes.from_array(scopes)
        token_scopes = doorkeeper_token.scopes.is_a?(Doorkeeper::OAuth::Scopes) ? 
                      doorkeeper_token.scopes : 
                      Doorkeeper::OAuth::Scopes.from_string(doorkeeper_token.scopes)

        unless required_scopes.all? { |scope| token_scopes.include?(scope) }
          render json: {
            error: 'Insufficient scope',
            required_scopes: scopes
          }, status: :forbidden
          return false
        end
      end

      true
    end

    # Override Doorkeeper's token method to handle different token formats
    def doorkeeper_token
      return @doorkeeper_token if defined?(@doorkeeper_token)

      @doorkeeper_token = find_access_token || nil
    end

    private

    def find_access_token
      # Try Authorization header first
      if request.authorization.present?
        token_from_authorization_header
      # Then try access_token parameter
      elsif params[:access_token].present?
        token_from_params
      end
    end

    def token_from_authorization_header
      auth_header = request.authorization
      return unless auth_header&.match(/^Bearer\s+(.+)$/i)

      token_value = ::Regexp.last_match(1)
      ::Doorkeeper::AccessToken.find_by(token: token_value)
    end

    def token_from_params
      ::Doorkeeper::AccessToken.find_by(token: params[:access_token])
    end

    def set_cache_headers
      response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    end

    def set_cors_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET, PATCH, OPTIONS'
      headers['Access-Control-Request-Method'] = '*'
      headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    end

    def not_found
      render json: { error: 'Record not found' }, status: :not_found
    end

    def unprocessable_entity
      render json: { error: 'Validation failed' }, status: :unprocessable_content
    end

    def too_many_requests
      render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
    end

    def render_empty
      render json: {}, status: :ok
    end

    def render_empty_success
      render json: {}, status: :ok
    end
  end
end
