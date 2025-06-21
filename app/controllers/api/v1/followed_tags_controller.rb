# frozen_string_literal: true

module Api
  module V1
    class FollowedTagsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/followed_tags
      def index
        limit = [params.fetch(:limit, 100).to_i, 200].min
        followed_tags = current_user.followed_tags.includes(:tag).recent.limit(limit)
        
        tags = followed_tags.map do |followed_tag|
          {
            name: followed_tag.tag.name,
            url: "#{request.base_url}/tags/#{followed_tag.tag.name}",
            history: build_hashtag_history(followed_tag.tag),
            following: true
          }
        end
        
        render json: tags
      end
      
      private
      
      def build_hashtag_history(tag)
        [
          {
            day: Time.current.beginning_of_day.to_i.to_s,
            uses: (tag.usage_count || 0).to_s,
            accounts: '1'
          }
        ]
      end
    end
  end
end
