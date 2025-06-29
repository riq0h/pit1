# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include AdminAuthorization

    before_action :require_admin!

    private

    def current_admin
      current_actor
    end
  end
end
