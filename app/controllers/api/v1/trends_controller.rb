# frozen_string_literal: true

module Api
  module V1
    class TrendsController < Api::BaseController
      before_action :doorkeeper_authorize!

      # GET /api/v1/trends
      def index
        # デフォルトではタグのトレンドを返す
        limit = [params[:limit].to_i, 20].min
        limit = 10 if limit <= 0

        trending_tags = generate_trending_tags(limit)
        render json: trending_tags.map { |tag| serialized_tag(tag) }
      end

      # GET /api/v1/trends/tags
      def tags
        limit = [params[:limit].to_i, 20].min
        limit = 10 if limit <= 0

        trending_tags = generate_trending_tags(limit)
        render json: trending_tags.map { |tag| serialized_tag(tag) }
      end

      # GET /api/v1/trends/statuses
      def statuses
        limit = [params[:limit].to_i, 20].min
        limit = 5 if limit <= 0

        trending_statuses = generate_trending_statuses(limit)
        render json: trending_statuses.map { |status| serialized_status(status) }
      end

      # GET /api/v1/trends/links
      def links
        # Letterでは外部リンクのトレンド機能は簡素化
        # 空配列を返す
        render json: []
      end

      private

      def generate_trending_tags(limit)
        # Letterでは簡素化されたトレンド機能
        # リモート投稿から使用されたタグを使用回数順で返す（ローカル投稿は除外）
        Tag.joins('JOIN object_tags ON tags.id = object_tags.tag_id')
           .joins('JOIN objects ON object_tags.object_id = objects.id')
           .where('objects.local = ? AND tags.usage_count > 0', false)
           .group('tags.id')
           .order('tags.usage_count DESC, tags.updated_at DESC')
           .limit(limit)
      end

      def generate_trending_statuses(limit)
        # リモート投稿から人気の高いものを返す（ローカル投稿は除外）
        # いいねやリブログが多い投稿を基準とする
        ActivityPubObject.where(object_type: 'Note', local: false)
                         .joins('LEFT JOIN favourites ON favourites.object_id = objects.id')
                         .joins('LEFT JOIN reblogs ON reblogs.object_id = objects.id')
                         .where('objects.published_at > ?', 7.days.ago)
                         .group('objects.id')
                         .order(Arel.sql('COUNT(favourites.id) + COUNT(reblogs.id) DESC, objects.published_at DESC'))
                         .limit(limit)
      end

      def serialized_tag(tag)
        {
          name: tag.name,
          url: "#{Rails.application.config.activitypub.base_url}/tags/#{tag.name}",
          history: [
            {
              day: Time.current.to_date.to_s,
              uses: tag.usage_count.to_s,
              accounts: '1' # 簡素化
            }
          ]
        }
      end

      def serialized_status(status)
        {
          id: status.id,
          created_at: status.published_at&.iso8601,
          in_reply_to_id: status.in_reply_to_ap_id,
          in_reply_to_account_id: nil,
          sensitive: false,
          spoiler_text: '',
          visibility: status.visibility || 'public',
          language: 'ja',
          uri: status.ap_id,
          url: status.ap_id,
          replies_count: 0,
          reblogs_count: status.reblogs.count,
          favourites_count: status.favourites.count,
          content: status.content || '',
          reblog: nil,
          account: serialized_account(status.actor),
          media_attachments: [],
          mentions: [],
          tags: [],
          emojis: [],
          card: nil,
          poll: nil
        }
      end

      def serialized_account(actor)
        {
          id: actor.id.to_s,
          username: actor.username,
          acct: actor.acct,
          display_name: actor.display_name_or_username,
          locked: actor.manually_approves_followers,
          bot: false,
          discoverable: actor.discoverable,
          group: false,
          created_at: actor.created_at&.iso8601,
          note: actor.note || '',
          url: actor.public_url,
          avatar: actor.avatar_url,
          avatar_static: actor.avatar_url,
          header: actor.header_image_url,
          header_static: actor.header_image_url,
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