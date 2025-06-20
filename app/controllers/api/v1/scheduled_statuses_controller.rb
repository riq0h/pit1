# frozen_string_literal: true

module Api
  module V1
    class ScheduledStatusesController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!
      before_action :set_scheduled_status, only: [:show, :update, :destroy]

      # GET /api/v1/scheduled_statuses
      def index
        limit = [params.fetch(:limit, 20).to_i, 40].min
        
        scheduled_statuses = current_user.scheduled_statuses
                                        .pending
                                        .order(scheduled_at: :asc)
                                        .limit(limit)

        if params[:max_id].present?
          scheduled_statuses = scheduled_statuses.where('id < ?', params[:max_id])
        end

        if params[:min_id].present?
          scheduled_statuses = scheduled_statuses.where('id > ?', params[:min_id])
        end

        render json: scheduled_statuses.map(&:to_mastodon_api)
      end

      # GET /api/v1/scheduled_statuses/:id
      def show
        render json: @scheduled_status.to_mastodon_api
      end

      # PUT /api/v1/scheduled_statuses/:id
      def update
        new_scheduled_at = Time.parse(params[:scheduled_at])
        
        if @scheduled_status.update(scheduled_at: new_scheduled_at)
          render json: @scheduled_status.to_mastodon_api
        else
          render json: { 
            error: @scheduled_status.errors.full_messages.join(', ') 
          }, status: :unprocessable_entity
        end
      rescue ArgumentError
        render json: { error: 'Invalid scheduled_at format' }, status: :unprocessable_entity
      end

      # DELETE /api/v1/scheduled_statuses/:id
      def destroy
        @scheduled_status.destroy!
        head :ok
      end

      private

      def set_scheduled_status
        @scheduled_status = current_user.scheduled_statuses.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Scheduled status not found' }, status: :not_found
      end
    end
  end
end