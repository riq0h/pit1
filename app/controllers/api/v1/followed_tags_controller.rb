# frozen_string_literal: true

module Api
  module V1
    class FollowedTagsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/followed_tags
      def index
        # TODO: フォローしているタグ機能の実装
        # Letterでは現在タグフォロー機能は未実装のため、空配列を返す
        render json: []
      end
    end
  end
end