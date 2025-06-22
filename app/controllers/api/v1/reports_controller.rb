# frozen_string_literal: true

module Api
  module V1
    class ReportsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # POST /api/v1/reports
      def create
        # Letterは2ユーザ限定のため通報機能は不要
        # 互換性のために適切なレスポンスを返す
        render json: {
          error: 'Reporting is not available in Letter (2-user system)'
        }, status: :unprocessable_entity
      end
    end
  end
end
