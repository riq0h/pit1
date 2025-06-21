# frozen_string_literal: true

module Api
  module V1
    class MarkersController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/markers
      def index
        timelines = params[:timeline] || %w[home notifications]
        timelines = [timelines] unless timelines.is_a?(Array)

        markers = {}

        timelines.each do |timeline|
          case timeline
          when 'home'
            markers['home'] = build_marker_response('home')
          when 'notifications'
            markers['notifications'] = build_marker_response('notifications')
          end
        end

        render json: markers
      end

      # POST /api/v1/markers
      def create
        markers = {}

        if params[:home] && params[:home][:last_read_id]
          save_marker('home', params[:home][:last_read_id])
          markers['home'] = build_marker_response('home')
        end

        if params[:notifications] && params[:notifications][:last_read_id]
          save_marker('notifications', params[:notifications][:last_read_id])
          markers['notifications'] = build_marker_response('notifications')
        end

        render json: markers
      end

      private

      def build_marker_response(timeline)
        marker = get_marker(timeline)
        return {} unless marker

        {
          last_read_id: marker[:last_read_id].to_s,
          version: marker[:version] || 1,
          updated_at: marker[:updated_at]&.iso8601 || Time.current.iso8601
        }
      end

      def save_marker(timeline, last_read_id)
        key = marker_cache_key(timeline)
        marker_data = {
          last_read_id: last_read_id,
          version: (get_marker(timeline)&.dig(:version) || 0) + 1,
          updated_at: Time.current
        }

        Rails.cache.write(key, marker_data, expires_in: 1.year)
      end

      def get_marker(timeline)
        Rails.cache.read(marker_cache_key(timeline))
      end

      def marker_cache_key(timeline)
        "markers:#{current_user.id}:#{timeline}"
      end
    end
  end
end
