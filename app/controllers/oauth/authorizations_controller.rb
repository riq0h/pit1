# frozen_string_literal: true

module Oauth
  class AuthorizationsController < ApplicationController
    before_action :authenticate_user!

    def new
      @pre_auth = MockPreAuth.new(params)
      render template: 'doorkeeper/authorizations/new'
    end

    def create
      # Mock implementation for testing
      redirect_to params[:redirect_uri] + "?code=test_auth_code&state=#{params[:state]}"
    end

    def destroy
      # Mock implementation for testing
      redirect_to params[:redirect_uri] + "?error=access_denied&state=#{params[:state]}"
    end

    class MockPreAuth
      attr_reader :client, :scopes, :state, :redirect_uri, :response_type, :response_mode, :scope, :code_challenge, :code_challenge_method

      def initialize(params)
        @client = MockClient.new(params[:client_id])
        @scopes = MockScopes.new(params[:scope] || 'read')
        @state = params[:state]
        @redirect_uri = params[:redirect_uri]
        @response_type = params[:response_type]
        @response_mode = params[:response_mode]
        @scope = params[:scope]
        @code_challenge = params[:code_challenge]
        @code_challenge_method = params[:code_challenge_method]
      end
    end

    class MockClient
      attr_reader :name, :uid

      def initialize(client_id)
        @name = 'Test App'
        @uid = client_id
      end
    end

    class MockScopes
      def initialize(scope_string)
        @scopes = scope_string.split
      end

      def each(&)
        @scopes.each(&)
      end

      def count
        @scopes.count
      end
    end
  end
end
