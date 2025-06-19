# frozen_string_literal: true

module Api
  module V1
    class AnnouncementsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/announcements
      def index
        # TODO: お知らせ機能の実装
        # Letterでは現在お知らせ機能は未実装のため、空配列を返す
        render json: []
      end

      # POST /api/v1/announcements/:id/dismiss
      def dismiss
        # TODO: お知らせ非表示機能の実装
        render json: { error: 'Announcements are not implemented yet' }, status: :not_implemented
      end
    end
  end
end