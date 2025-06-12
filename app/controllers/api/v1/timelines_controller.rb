# frozen_string_literal: true

module Api
  module V1
    class TimelinesController < Api::BaseController
      include AccountSerializer
      before_action :doorkeeper_authorize!, only: [:home]

      # GET /api/v1/timelines/home
      def home
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        statuses = build_home_timeline_query
        render json: statuses.map { |status| serialized_status(status) }
      end

      # GET /api/v1/timelines/public
      def public
        statuses = build_public_timeline_query
        render json: statuses.map { |status| serialized_status(status) }
      end

      private

      def build_home_timeline_query
        followed_ids = current_user.followed_actors.pluck(:id) + [current_user.id]
        statuses = base_timeline_query.where(actors: { id: followed_ids })
        apply_pagination_filters(statuses)
      end

      def build_public_timeline_query
        statuses = base_timeline_query.where(visibility: 'public')
        statuses = statuses.where(actors: { local: true }) if local_only?
        apply_pagination_filters(statuses)
      end

      def base_timeline_query
        ActivityPubObject.joins(:actor)
                         .where(object_type: 'Note')
                         .where('LENGTH(objects.id) = 6')
                         .order(published_at: :desc)
                         .limit(params[:limit]&.to_i || 20)
      end

      def apply_pagination_filters(query)
        query = query.where(objects: { id: ...(params[:max_id]) }) if params[:max_id].present?
        query = query.where('objects.id > ?', params[:min_id]) if params[:min_id].present?
        query
      end

      def local_only?
        params[:local].present? && params[:local] != 'false'
      end

      # GET /api/v1/timelines/tag/:hashtag
      def tag
        params[:hashtag]

        # TODO: Implement hashtag functionality
        # For now, return empty array
        render json: []
      end

      def serialized_status(status)
        {
          id: status.id.to_s,
          created_at: status.published_at.iso8601,
          in_reply_to_id: in_reply_to_id(status),
          in_reply_to_account_id: in_reply_to_account_id(status),
          sensitive: status.sensitive || false,
          spoiler_text: status.summary || '',
          visibility: status.visibility || 'public',
          language: 'ja',
          uri: status.ap_id,
          url: status.public_url,
          replies_count: replies_count(status),
          reblogs_count: 0, # TODO: Implement
          favourites_count: 0, # TODO: Implement
          content: status.content || '',
          reblog: nil,
          account: serialized_account(status.actor),
          media_attachments: [], # TODO: Implement
          mentions: [], # TODO: Implement
          tags: [], # TODO: Implement
          emojis: [],
          card: nil,
          poll: nil
        }
      end

      def in_reply_to_id(status)
        return nil if status.in_reply_to_ap_id.blank?

        in_reply_to = ActivityPubObject.find_by(ap_id: status.in_reply_to_ap_id)
        in_reply_to&.id&.to_s
      end

      def in_reply_to_account_id(status)
        return nil if status.in_reply_to_ap_id.blank?

        in_reply_to = ActivityPubObject.find_by(ap_id: status.in_reply_to_ap_id)
        return nil unless in_reply_to&.actor

        in_reply_to.actor.id.to_s
      end

      def replies_count(status)
        ActivityPubObject.where(in_reply_to_ap_id: status.ap_id).count
      end
    end
  end
end
