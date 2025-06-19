# frozen_string_literal: true

module Api
  module V1
    class BookmarksController < Api::BaseController
      include StatusSerializer
      include StatusSerializationHelper
      include AccountSerializer
      include MediaSerializer
      include MentionTagSerializer
      
      before_action :doorkeeper_authorize!

      # GET /api/v1/bookmarks
      def index
        doorkeeper_authorize! :read
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        bookmarks = current_user.bookmarks
                               .joins(:object)
                               .includes(object: [:actor, :media_attachments, :mentions, :tags])
                               .recent
                               .limit(params[:limit] || 20)

        statuses = bookmarks.map(&:object)
        render json: statuses.map { |status| serialized_status(status) }
      end
    end
  end
end