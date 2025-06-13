# frozen_string_literal: true

module Api
  module V1
    class SearchController < Api::BaseController
      # GET /api/v1/search
      def index
        search_service = create_search_service
        results = search_service.search
        render_search_results(results)
      end

      private

      def create_search_service
        OptimizedSearchService.new(
          query: params[:q],
          since_time: parse_time(params[:since]),
          until_time: parse_time(params[:until]),
          limit: params[:limit]&.to_i || 20,
          offset: params[:offset].to_i
        )
      end

      def render_search_results(results)
        render json: {
          accounts: [],
          statuses: results.map { |status| serialized_status(status) },
          hashtags: []
        }
      end

      def parse_time(time_param)
        return nil if time_param.blank?

        Time.zone.parse(time_param)
      rescue ArgumentError
        nil
      end

      def serialized_status(status)
        {
          id: status.id.to_s,
          created_at: status.published_at.iso8601,
          content: status.content || '',
          account: serialized_account(status.actor),
          visibility: status.visibility || 'public',
          uri: status.ap_id,
          url: status.public_url
        }
      end

      def serialized_account(actor)
        {
          id: actor.id.to_s,
          username: actor.username,
          acct: actor.username,
          display_name: actor.display_name || actor.username,
          url: actor.public_url
        }
      end
    end
  end
end
