# frozen_string_literal: true

module Api
  module V1
    class ReportsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # POST /api/v1/reports
      def create
        # letterは2ユーザ限定のため通報機能は不要
        # 互換性のために適切なレスポンスを返す
        render_not_implemented('Reporting')
      end
    end
  end
end
