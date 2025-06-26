# frozen_string_literal: true

module Api
  module V1
    class EndorsementsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/endorsements
      def index
        # Letterは2ユーザ限定のため推薦機能は不要
        # 互換性のために空配列を返す
        render json: []
      end

      # POST /api/v1/accounts/:id/pin
      def create
        # Letter は2ユーザ限定のため推薦機能は不要
        # 互換性のために422エラーを返す
        render_not_implemented('Feature')
      end

      # DELETE /api/v1/accounts/:id/unpin
      def destroy
        # Letter は2ユーザ限定のため推薦機能は不要
        # 互換性のために422エラーを返す
        render_not_implemented('Feature')
      end
    end
  end
end
