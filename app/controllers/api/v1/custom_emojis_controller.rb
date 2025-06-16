# frozen_string_literal: true

module Api
  module V1
    class CustomEmojisController < Api::BaseController
      # Mastodon API準拠 - カスタム絵文字一覧取得
      # GET /api/v1/custom_emojis
      def index
        emojis = CustomEmoji.enabled.alphabetical.includes(:image_attachment)

        render json: emojis.map(&:to_activitypub)
      end
    end
  end
end
