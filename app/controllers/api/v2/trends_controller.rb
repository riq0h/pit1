# frozen_string_literal: true

module Api
  module V2
    class TrendsController < Api::BaseController
      # GET /api/v2/trends/tags
      def tags
        # ハッシュタグのトレンドは実装が複雑なため、空の配列を返す
        render json: []
      end

      # GET /api/v2/trends/statuses
      def statuses
        # 投稿のトレンドは実装が複雑なため、空の配列を返す
        render json: []
      end

      # GET /api/v2/trends/links
      def links
        # リンクのトレンドは実装が複雑なため、空の配列を返す
        render json: []
      end
    end
  end
end
