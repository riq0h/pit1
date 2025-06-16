# frozen_string_literal: true

module Api
  module V1
    class SearchController < Api::BaseController
      # GET /api/v1/search
      def index
        search_service = create_search_service
        results = search_service.search
        render_search_results(results)
      end

      private

      def create_search_service
        OptimizedSearchService.new(
          query: params[:q],
          since_time: parse_time(params[:since]),
          until_time: parse_time(params[:until]),
          limit: params[:limit]&.to_i || 20,
          offset: params[:offset].to_i
        )
      end

      def render_search_results(results)
        render json: {
          accounts: [],
          statuses: results.map { |status| serialized_status(status) },
          hashtags: []
        }
      end

      def parse_time(time_param)
        return nil if time_param.blank?

        Time.zone.parse(time_param)
      rescue ArgumentError
        nil
      end

      def serialized_status(status)
        {
          id: status.id.to_s,
          created_at: status.published_at.iso8601,
          content: status.content || '',
          account: serialized_account(status.actor),
          visibility: status.visibility || 'public',
          uri: status.ap_id,
          url: status.public_url,
          # Mastodon API準拠のための追加フィールド
          sensitive: false,
          spoiler_text: '',
          reblogs_count: 0,
          favourites_count: 0,
          replies_count: 0,
          reblogged: false,
          favourited: false,
          bookmarked: false,
          muted: false,
          pinned: false,
          reblog: nil,
          application: nil,
          language: 'ja',
          emojis: [],
          media_attachments: [],
          mentions: [],
          tags: []
        }
      end

      def serialized_account(actor)
        {
          **basic_account_fields(actor),
          **account_settings(actor),
          **account_stats(actor),
          **account_images(actor)
        }
      end

      def basic_account_fields(actor)
        {
          id: actor.id.to_s,
          username: actor.username,
          acct: actor.local? ? actor.username : actor.full_username,
          display_name: actor.display_name || actor.username,
          url: actor.public_url,
          created_at: actor.created_at.iso8601,
          note: actor.summary || ''
        }
      end

      def account_settings(actor)
        {
          locked: actor.manually_approves_followers || false,
          bot: actor.actor_type == 'Service',
          discoverable: actor.discoverable || false,
          group: false
        }
      end

      def account_stats(actor)
        {
          followers_count: actor.followers_count || 0,
          following_count: actor.following_count || 0,
          statuses_count: actor.posts_count || 0
        }
      end

      def account_images(actor)
        default_image = '/icon.png'
        {
          avatar: actor.avatar_url || default_image,
          avatar_static: actor.avatar_url || default_image,
          header: actor.header_image_url || default_image,
          header_static: actor.header_image_url || default_image,
          emojis: [],
          fields: []
        }
      end
    end
  end
end
