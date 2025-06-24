# frozen_string_literal: true

module Api
  module V1
    class TimelinesController < Api::BaseController
      include StatusSerializationHelper
      include AccountSerializer
      include TextLinkingHelper
      before_action :doorkeeper_authorize!, only: [:home]

      # GET /api/v1/timelines/home
      def home
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        timeline_items = build_home_timeline_query
        render json: timeline_items.map { |item| serialize_timeline_item(item) }
      end

      # GET /api/v1/timelines/public
      def public
        statuses = build_public_timeline_query
        render json: statuses.map { |status| serialized_status(status) }
      end

      # GET /api/v1/timelines/tag/:hashtag
      def tag
        hashtag_name = params[:hashtag]
        statuses = build_hashtag_timeline_query(hashtag_name)
        render json: statuses.map { |status| serialized_status(status) }
      end

      private

      def build_home_timeline_query
        followed_ids = current_user.followed_actors.pluck(:id) + [current_user.id]
        
        # 通常の投稿を取得
        statuses = base_timeline_query.where(actors: { id: followed_ids })
        statuses = apply_pagination_filters(statuses)
        
        # リブログを取得
        reblogs = Reblog.joins(:actor, :object)
                        .where(actor_id: followed_ids)
                        .where(objects: { visibility: %w[public unlisted] })
                        .includes(:actor, object: [:actor, :media_attachments])
                        .order(created_at: :desc)
                        .limit(params[:limit]&.to_i || 20)
        
        # 両方を時系列で結合
        combine_statuses_and_reblogs(statuses, reblogs)
      end

      def build_public_timeline_query
        statuses = base_timeline_query.where(visibility: 'public')
        statuses = statuses.where(actors: { local: true }) if local_only?
        apply_pagination_filters(statuses)
      end

      def build_hashtag_timeline_query(hashtag_name)
        # ハッシュタグに関連する投稿を取得
        tag = Tag.find_by(name: hashtag_name)
        return ActivityPubObject.none unless tag

        statuses = base_timeline_query
                   .joins(:tags)
                   .where(tags: { id: tag.id })
                   .where(visibility: 'public')
        apply_pagination_filters(statuses)
      end

      def base_timeline_query
        query = ActivityPubObject.joins(:actor)
                                 .includes(:poll)
                                 .where(object_type: ['Note', 'Question'])
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

      def combine_statuses_and_reblogs(statuses, reblogs)
        # StatusとReblogを時系列で結合
        combined = []
        
        # Statusesを配列に変換してタイムスタンプ付きで追加
        statuses.each do |status|
          combined << {
            type: :status,
            object: status,
            timestamp: status.published_at
          }
        end
        
        # Reblogsを配列に変換してタイムスタンプ付きで追加
        reblogs.each do |reblog|
          combined << {
            type: :reblog,
            object: reblog,
            timestamp: reblog.created_at
          }
        end
        
        # タイムスタンプでソートして最新から表示
        combined.sort_by { |item| item[:timestamp] }.reverse
                .first(params[:limit]&.to_i || 20)
                .map { |item| item[:object] }
      end

      def serialize_timeline_item(item)
        case item
        when ActivityPubObject
          # 通常のステータス
          serialized_status(item)
        when Reblog
          # リブログ - リブログされた元投稿をラップして返す
          reblogged_status = serialized_status(item.object)
          reblogged_status[:reblog] = nil  # ネストしたリブログを防ぐ
          
          # リブログ情報を追加
          {
            id: item.object.id.to_s,
            created_at: item.created_at.iso8601,
            account: simple_account_data(item.actor),
            reblog: reblogged_status
          }.merge(default_interaction_data)
        else
          # フォールバック
          serialized_status(item)
        end
      end

      def default_interaction_data
        {
          favourited: false,
          reblogged: false,
          muted: false,
          bookmarked: false,
          pinned: false,
          content: '',
          visibility: 'public',
          sensitive: false,
          spoiler_text: '',
          url: '',
          uri: '',
          in_reply_to_id: nil,
          in_reply_to_account_id: nil,
          media_attachments: [],
          mentions: [],
          tags: [],
          emojis: [],
          reblogs_count: 0,
          favourites_count: 0,
          replies_count: 0,
          language: nil,
          text: nil,
          edited_at: nil,
          poll: nil
        }
      end

      def simple_account_data(actor)
        {
          id: actor.id.to_s,
          username: actor.username,
          acct: actor.local? ? actor.username : actor.full_username,
          display_name: actor.display_name || actor.username,
          locked: actor.manually_approves_followers || false,
          bot: actor.actor_type == 'Service',
          discoverable: actor.discoverable || false,
          group: false,
          created_at: actor.created_at.iso8601,
          note: actor.note || '',
          url: actor.public_url || actor.ap_id || '',
          uri: actor.ap_id || '',
          avatar: actor.avatar_url || '/icon.png',
          avatar_static: actor.avatar_url || '/icon.png',
          header: actor.header_image_url || '/icon.png',
          header_static: actor.header_image_url || '/icon.png',
          followers_count: actor.followers_count || 0,
          following_count: actor.following_count || 0,
          statuses_count: actor.posts_count || 0,
          last_status_at: nil,
          emojis: [],
          fields: []
        }
      end

    end
  end
end
