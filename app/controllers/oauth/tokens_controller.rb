# frozen_string_literal: true

module Oauth
  class TokensController < Doorkeeper::TokensController
    # Doorkeeper handles all token operations
    # This controller inherits from Doorkeeper's TokensController
    # and provides the token endpoint functionality
  end
end
