# frozen_string_literal: true

module Api
  module V1
    class TimelinesController < Api::BaseController
      include AccountSerializer
      include MediaSerializer
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
        query = ActivityPubObject.joins(:actor)
                                 .where(object_type: 'Note')
                                 .where(local: true)
                                 .order('objects.id DESC')
                                 .limit(params[:limit]&.to_i || 20)

        # Apply user-specific filters if authenticated
        query = apply_user_filters(query) if current_user

        query
      end

      def apply_user_filters(query)
        query = exclude_blocked_users(query)
        query = exclude_muted_users(query)
        exclude_domain_blocked_users(query)
      end

      def exclude_blocked_users(query)
        blocked_actor_ids = current_user.blocked_actors.pluck(:id)
        return query unless blocked_actor_ids.any?

        query.where.not(actors: { id: blocked_actor_ids })
      end

      def exclude_muted_users(query)
        muted_actor_ids = current_user.muted_actors.pluck(:id)
        return query unless muted_actor_ids.any?

        query.where.not(actors: { id: muted_actor_ids })
      end

      def exclude_domain_blocked_users(query)
        blocked_domains = current_user.domain_blocks.pluck(:domain)
        return query unless blocked_domains.any?

        query.where.not(actors: { domain: blocked_domains })
      end

      def apply_pagination_filters(query)
        query = query.where(objects: { id: ...(params[:max_id]) }) if params[:max_id].present?
        query = query.where('objects.id > ?', params[:min_id]) if params[:min_id].present?
        query
      end

      def local_only?
        params[:local].present? && params[:local] != 'false'
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
          content: status.content || '',
          reblog: nil,
          account: serialized_account(status.actor),
          media_attachments: serialized_media_attachments(status),
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
