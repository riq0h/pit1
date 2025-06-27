# frozen_string_literal: true

module Api
  module V1
    class AnnouncementsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/announcements
      def index
        # letterは2ユーザ制限の軽量実装のため、お知らせ機能はスタブ実装
        # サードパーティクライアントの互換性のため空配列を返す
        render json: []
      end

      # POST /api/v1/announcements/:id/dismiss
      def dismiss
        # スタブ実装：常に成功として扱う
        head :ok
      end
    end
  end
end
