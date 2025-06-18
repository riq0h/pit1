# frozen_string_literal: true

module Api
  module V2
    class SearchController < Api::BaseController
      include SearchSerializationHelper

      # GET /api/v2/search
      def index
        @results = perform_search
        render_search_results
      end

      private

      def perform_search
        search_service = Search::SearchService.new(params, current_user)
        search_service.perform_search
      end

      def render_search_results
        render json: {
          accounts: @results[:accounts].map { |account| serialized_account(account) },
          statuses: @results[:statuses].map { |status| serialized_status(status) },
          hashtags: @results[:hashtags].map { |hashtag| serialized_hashtag(hashtag) }
        }
      end
    end
  end
end
