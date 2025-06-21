# frozen_string_literal: true

module Api
  module V2
    class SuggestionsController < Api::BaseController
      # GET /api/v2/suggestions
      def index
        # 2アカウント制限の1人用システムなので、おすすめユーザは提供しない
        render json: []
      end
    end
  end
end
