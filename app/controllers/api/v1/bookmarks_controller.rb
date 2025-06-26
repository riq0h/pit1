# frozen_string_literal: true

module Api
  module V1
    class BookmarksController < Api::BaseController
      include StatusSerializationHelper

      before_action :doorkeeper_authorize!

      # GET /api/v1/bookmarks
      def index
        doorkeeper_authorize! :read
        return render_authentication_required unless current_user

        bookmarks = current_user.bookmarks
                                .joins(:object)
                                .includes(object: %i[actor media_attachments mentions tags poll])
                                .recent
                                .limit(params[:limit] || 20)

        statuses = bookmarks.map(&:object)
        render json: statuses.map { |status| serialized_status(status) }
      end
    end
  end
end
