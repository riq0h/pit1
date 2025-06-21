# frozen_string_literal: true

module Api
  module V1
    class PreferencesController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/preferences
      def show
        render json: current_user.preferences
      end
    end
  end
end
