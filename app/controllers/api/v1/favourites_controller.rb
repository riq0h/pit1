# frozen_string_literal: true

module Api
  module V1
    class FavouritesController < Api::BaseController
      include StatusSerializationHelper

      before_action :doorkeeper_authorize!

      # GET /api/v1/favourites
      def index
        doorkeeper_authorize! :read
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        favourites = current_user.favourites
                                 .joins(:object)
                                 .includes(object: %i[actor media_attachments mentions tags poll])
                                 .recent
                                 .limit(params[:limit] || 20)

        statuses = favourites.map(&:object)
        render json: statuses.map { |status| serialized_status(status) }
      end
    end
  end
end
